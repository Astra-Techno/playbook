import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

/// 10-digit Indian mobile with a +91 prefix. Digits only.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'Mobile number',
    this.helperText,
    this.autofocus = false,
    this.onChanged,
    this.onSubmitted,
  });

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      autofocus: autofocus,
      keyboardType: TextInputType.phone,
      textInputAction: TextInputAction.done,
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: helperText ?? '10 digits, without country code',
        prefixText: '+91 ',
        prefixStyle: const TextStyle(fontWeight: FontWeight.w700, color: AppColors.textPrimary),
        counterText: '',
      ),
    );
  }
}
