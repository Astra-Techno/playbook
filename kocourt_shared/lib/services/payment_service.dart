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
import '../core/fonts.dart';
import '../core/format.dart';

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
      int paise(dynamic v) => (v is num ? v : num.tryParse('$v') ?? 0).round();
      String money(dynamic v) => rupees(paise(v) / 100);
      final total = paise(price['total']);
      // Refund policy as short lines instead of one paragraph.
      final policyLines = <String>[
        if (type == 'subscription') 'Membership cancellations are reviewed by support.'
        else if (policy['cancellation.enabled'] == true) ...[
          'Full refund up to ${policy['cancellation.full_hours']} h before play',
          '${policy['cancellation.partial_percent']}% refund up to ${policy['cancellation.partial_hours']} h before',
          '${policy['cancellation.late_percent']}% refund after that',
        ] else
          'This venue does not allow cancellations by players',
        'If the venue cancels, you get the full amount back',
        'Refunds reach your payment method in about ${policy['refund.expected_days']} working days',
      ];
      final accepted = await showModalBottomSheet<bool>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        backgroundColor: Colors.white,
        builder: (sheet) {
          final brand = sheet.brand;
          Widget row(String label, dynamic value) {
            if (paise(value) == 0) return const SizedBox.shrink();
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                children: [
                  Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary, fontSize: 14))),
                  Text(money(value), style: AppFonts.score(fontSize: 16, color: brand.ink)),
                ],
              ),
            );
          }

          return SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Review and pay', style: AppFonts.display(fontSize: 20, color: brand.ink)),
                  const SizedBox(height: 16),
                  Flexible(
                    child: SingleChildScrollView(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          row(type == 'subscription' ? 'Membership' : 'Court booking', price['venue']['base']),
                          if (quote['snapshot']['addons'] is Map) row('   incl. kit rental', quote['snapshot']['addons']['paise']),
                          row('GST', price['venue']['tax']),
                          row('KoCourt fee', price['fee']['base']),
                          row('GST on fee', price['fee']['tax']),
                          const Divider(height: 20),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Expanded(child: Text('Total', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700, color: brand.ink))),
                              Text(money(total), style: AppFonts.score(fontSize: 30, color: brand.ink)),
                            ],
                          ),
                          const SizedBox(height: 16),
                          for (final line in policyLines)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(Icons.check_circle_outline_rounded, size: 16, color: brand.primary),
                                  const SizedBox(width: 8),
                                  Expanded(child: Text(line, style: const TextStyle(fontSize: 13, height: 1.35, color: AppColors.textSecondary))),
                                ],
                              ),
                            ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 52,
                    child: FilledButton(
                      onPressed: () => Navigator.pop(sheet, true),
                      style: FilledButton.styleFrom(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14))),
                      child: Text('Pay ${money(total)}', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                    ),
                  ),
                  TextButton(onPressed: () => Navigator.pop(sheet, false), child: const Text('Not now')),
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
