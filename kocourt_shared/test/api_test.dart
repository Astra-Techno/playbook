import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  test('API errors expose safe, actionable messages', () {
    final error = DioException(
      requestOptions: RequestOptions(path: '/bookings'),
      response: Response(
        requestOptions: RequestOptions(path: '/bookings'),
        statusCode: 422,
        data: {'message': 'That slot is no longer available.'},
      ),
      type: DioExceptionType.badResponse,
    );

    expect(Api.failureMessage(error), 'That slot is no longer available.');
  });
}
