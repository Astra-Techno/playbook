import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

/// Digit OTP boxes. Controllers and focus nodes must match [length].
class AppOtpRow extends StatelessWidget {
  final List<TextEditingController> controllers;
  final List<FocusNode> focusNodes;
  final int length;
  final ValueChanged<String>? onCompleted;

  const AppOtpRow({
    super.key,
    required this.controllers,
    required this.focusNodes,
    this.length = 4,
    this.onCompleted,
  }) : assert(controllers.length == focusNodes.length);

  String get code => controllers.map((c) => c.text).join();

  @override
  Widget build(BuildContext context) {
    final brand = context.brand;
    final count = length.clamp(1, controllers.length);

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: List.generate(count, (i) {
        return SizedBox(
          width: 56,
          height: 64,
          child: TextField(
            controller: controllers[i],
            focusNode: focusNodes[i],
            textAlign: TextAlign.center,
            keyboardType: TextInputType.number,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w800,
              color: brand.ink,
            ),
            inputFormatters: [
              FilteringTextInputFormatter.digitsOnly,
              LengthLimitingTextInputFormatter(1),
            ],
            decoration: InputDecoration(
              filled: true,
              fillColor: AppColors.surfaceWhite,
              contentPadding: EdgeInsets.zero,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: const BorderSide(color: AppColors.border),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(AppRadius.md),
                borderSide: BorderSide(color: brand.primary, width: 2),
              ),
              counterText: '',
            ),
            onChanged: (v) {
              if (v.isNotEmpty && i < count - 1) {
                focusNodes[i + 1].requestFocus();
              } else if (v.isEmpty && i > 0) {
                focusNodes[i - 1].requestFocus();
              }
              final joined = controllers.take(count).map((c) => c.text).join();
              if (joined.length == count) onCompleted?.call(joined);
            },
          ),
        );
      }),
    );
  }
}
