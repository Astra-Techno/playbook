import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/core/phone_fields.dart';

void main() {
  test('Indian mobiles normalize to 10 digits', () {
    expect(normalizeIndianMobile('98765 43210'), '9876543210');
    expect(normalizeIndianMobile('+91 98765 43210'), '9876543210');
    expect(normalizeIndianMobile('919876543210'), '9876543210');
    expect(normalizeIndianMobile('09876543210'), '9876543210');
  });

  test('optional guest phone may be blank', () {
    expect(normalizeIndianMobile('', required: false), '');
    expect(normalizeIndianMobile('  ', required: false), '');
  });

  test('short numbers are rejected', () {
    expect(() => normalizeIndianMobile('98765'), throwsA(isA<PhoneFieldError>()));
    expect(isTenDigitMobile('9876543210'), isTrue);
    expect(isTenDigitMobile('98765'), isFalse);
  });
}
