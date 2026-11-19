class PhoneFieldError implements Exception {
  final String message;
  const PhoneFieldError(this.message);
}

/// 10-digit Indian mobile. Strips +91, spaces, and a leading 0.
String normalizeIndianMobile(String phone, {bool required = true}) {
  final trimmed = phone.trim();
  if (trimmed.isEmpty) {
    if (required) {
      throw const PhoneFieldError('Enter a 10-digit mobile number');
    }
    return '';
  }
  var digits = trimmed.replaceAll(RegExp(r'\D'), '');
  if (digits.length >= 12 && digits.startsWith('91')) {
    digits = digits.substring(digits.length - 10);
  }
  if (digits.length == 11 && digits.startsWith('0')) {
    digits = digits.substring(1);
  }
  if (digits.length > 10) {
    digits = digits.substring(digits.length - 10);
  }
  if (!RegExp(r'^\d{10}$').hasMatch(digits)) {
    throw const PhoneFieldError('Enter a 10-digit mobile number');
  }
  return digits;
}

bool isTenDigitMobile(String phone) {
  try {
    return normalizeIndianMobile(phone).length == 10;
  } on PhoneFieldError {
    return false;
  }
}
