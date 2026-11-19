import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme.dart';

/// 10-digit Indian mobile with a +91 prefix. Digits only.
class PhoneField extends StatelessWidget {
  final TextEditingController controller;
  final String label;
  final String? helperText;
  final String? errorText;
  final bool autofocus;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  const PhoneField({
    super.key,
    required this.controller,
    this.label = 'Mobile number',
    this.helperText,
    this.errorText,
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
      style: const TextStyle(
        fontWeight: FontWeight.w600,
        letterSpacing: 0.4,
        fontSize: 16,
      ),
      inputFormatters: [
        FilteringTextInputFormatter.digitsOnly,
        LengthLimitingTextInputFormatter(10),
      ],
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        labelText: label,
        helperText: errorText == null ? (helperText ?? '10 digits, without country code') : null,
        errorText: errorText,
        prefixText: '+91  ',
        prefixStyle: TextStyle(
          fontWeight: FontWeight.w800,
          color: context.brand.ink,
          fontSize: 16,
        ),
        counterText: '',
      ),
    );
  }
}
