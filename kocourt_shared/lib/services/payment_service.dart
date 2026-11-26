import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_cashfree_pg_sdk/api/cferrorresponse/cferrorresponse.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpaymentgateway/cfpaymentgatewayservice.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfpayment/cfwebcheckoutpayment.dart';
import 'package:flutter_cashfree_pg_sdk/api/cfsession/cfsession.dart';
import 'package:flutter_cashfree_pg_sdk/utils/cfenums.dart';
import '../core/api.dart';
import '../core/theme.dart';

class PaymentResult {
  final bool success;
  final String? orderId;
  final String? error;
  final Map<String, dynamic>? verifyData;

  PaymentResult({required this.success, this.orderId, this.error, this.verifyData});
}

class PaymentService {
  static bool? _isDemo;

  /// Check if backend is in demo mode (no Cashfree credentials)
  static Future<bool> isDemoMode() async {
    if (_isDemo != null) return _isDemo!;
    try {
      final res = await Api().get('/payments/config');
      _isDemo = res.data['demo'] == true;
    } catch (_) {
      _isDemo = true;
    }
    return _isDemo!;
  }

  /// Clear cached demo mode (e.g. on logout)
  static void clearCache() => _isDemo = null;

  /// Create order and process payment.
  static Future<PaymentResult> processPayment({
    required BuildContext context,
    required double amount,
    required String type,
    required Map<String, dynamic> payload,
  }) async {
    try {
      final quote = (await Api().post('/payments/quote', data: {
        'type': type, 'payload': payload,
      })).data;
      if (!context.mounted) return PaymentResult(success: false, error: 'Checkout closed');
      final price = quote['snapshot']['price'];
      final policy = quote['snapshot']['policy'];
      String money(dynamic value) => ((value as num) / 100).toStringAsFixed(2);
      final terms = type == 'subscription'
          ? 'Subscription cancellations require support review.'
          : policy['cancellation.enabled'] == true
              ? 'Venue refund: 100% at least ${policy['cancellation.full_hours']} hours before play; '
                '${policy['cancellation.partial_percent']}% at least ${policy['cancellation.partial_hours']} hours before; '
                'otherwise ${policy['cancellation.late_percent']}%. '
                'Platform fee refund: ${policy['cancellation.fee_refund'].toString().replaceAll('_', ' ')}. '
                'Venue cancellations refund the full payment.'
              : 'Customer cancellation is disabled. Venue cancellations refund the full payment.';
      final accepted = await showDialog<bool>(
        context: context,
        builder: (dialogContext) {
          final brand = dialogContext.brand;
          Widget row(String label, String value, {bool emphasize = false}) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      label,
                      style: TextStyle(
                        color: AppColors.textSecondary,
                        fontWeight: emphasize ? FontWeight.w700 : FontWeight.w500,
                        fontSize: emphasize ? 15 : 13,
                      ),
                    ),
                  ),
                  Text(
                    value,
                    style: TextStyle(
                      color: brand.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: emphasize ? 16 : 13,
                    ),
                  ),
                ],
              ),
            );
          }

          return Dialog(
            insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
            child: Padding(
              padding: const EdgeInsets.fromLTRB(22, 22, 22, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Review payment', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800, color: brand.ink)),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          row('Venue', 'INR ${money(price['venue']['base'])}'),
                          if (quote['snapshot']['addons'] is Map)
                            row('  incl. kit rental', 'INR ${money(quote['snapshot']['addons']['paise'])}'),
                          row('Venue GST', 'INR ${money(price['venue']['tax'])}'),
                          row('KoCourt fee', 'INR ${money(price['fee']['base'])}'),
                          row('Fee GST', 'INR ${money(price['fee']['tax'])}'),
                          const Divider(height: 20),
                          row('Total', 'INR ${money(price['total'])}', emphasize: true),
                          const SizedBox(height: 12),
                          Text(
                            terms,
                            style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textSecondary, fontWeight: FontWeight.w500),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Eligible refunds return to the original payment method; exceptions require review. Expected credit: ${policy['refund.expected_days']} business days after initiation.',
                            style: const TextStyle(fontSize: 12, height: 1.45, color: AppColors.textMuted, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          onPressed: () => Navigator.pop(dialogContext, false),
                          child: const Text('Back'),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: FilledButton(
                          onPressed: () => Navigator.pop(dialogContext, true),
                          child: const Text('Continue'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          );
        },
      );
      if (accepted != true) return PaymentResult(success: false, error: 'Payment cancelled');
      final orderRes = await Api().post('/payments/create-order', data: {
        'amount': quote['amount'],
        'type': type,
        'payload': payload,
        'quote_hash': quote['quote_hash'],
      });

      final orderData = orderRes.data;
      final orderId = orderData['order_id']?.toString() ?? '';
      final isDemo = orderData['demo'] == true;

      if (isDemo) {
        return await _verifyPayment(orderId);
      }

      final sessionId = orderData['payment_session_id']?.toString() ?? '';
      final env = (orderData['env'] ?? 'sandbox').toString().toLowerCase();
      final cfEnv = env == 'production'
          ? CFEnvironment.PRODUCTION
          : CFEnvironment.SANDBOX;

      final cfSession = CFSessionBuilder()
          .setEnvironment(cfEnv)
          .setOrderId(orderId)
          .setPaymentSessionId(sessionId)
          .build();

      final cfPayment = CFWebCheckoutPaymentBuilder()
          .setSession(cfSession)
          .build();

      final gatewayResult = await _openCashfreeCheckout(cfPayment);

      if (!gatewayResult) {
        return PaymentResult(success: false, orderId: orderId, error: 'Payment cancelled or failed');
      }

      return await _verifyPayment(orderId);
    } on DioException catch (e) {
      final msg = _extractDioError(e);
      return PaymentResult(success: false, error: msg);
    } catch (e) {
      debugPrint('PaymentService error: $e');
      return PaymentResult(success: false, error: e.toString());
    }
  }

  static Future<bool> _openCashfreeCheckout(CFWebCheckoutPayment payment) async {
    final completer = Completer<bool>();

    final gateway = CFPaymentGatewayService();
    gateway.setCallback(
      (String orderId) {
        if (!completer.isCompleted) completer.complete(true);
      },
      (CFErrorResponse error, String orderId) {
        debugPrint('Cashfree error: ${error.getMessage()}');
        if (!completer.isCompleted) completer.complete(false);
      },
    );
    gateway.doPayment(payment);

    return completer.future;
  }

  static Future<PaymentResult> _verifyPayment(String orderId) async {
    try {
      final res = await Api().post('/payments/verify', data: {
        'order_id': orderId,
      });

      return PaymentResult(
        success: true,
        orderId: orderId,
        verifyData: Map<String, dynamic>.from(res.data),
      );
    } on DioException catch (e) {
      final msg = _extractDioError(e);
      return PaymentResult(success: false, orderId: orderId, error: msg);
    } catch (e) {
      return PaymentResult(success: false, orderId: orderId, error: e.toString());
    }
  }

  static String _extractDioError(DioException e) {
    if (e.response?.data is Map) {
      return (e.response!.data as Map)['message']?.toString() ?? 'Payment failed';
    }
    return e.message ?? 'Payment failed';
  }
}
