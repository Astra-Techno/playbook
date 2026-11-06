import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt/screens/search/court_list_params.dart';

void main() {
  test('view all asks for the public venue list', () {
    expect(courtListParams(), isEmpty);
    expect(courtListParams(query: '  ', type: 'All'), isEmpty);
  });

  test('a place and a sport narrow the list', () {
    expect(courtListParams(query: ' Chennai ', type: 'badminton'), {
      'location': 'Chennai',
      'type': 'badminton',
    });
  });
}
