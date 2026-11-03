import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/owner_copy.dart';

void main() {
  test('Tamil labels stay on the shell and any other language stays English', () {
    expect(ownerLanguageCode('ta'), 'ta');
    expect(ownerLanguageCode('fr'), 'en');
    expect(ownerLanguageCode(null), 'en');
    expect(ownerPhrase('ta', 'venues'), 'அரங்கங்கள்');
    expect(ownerPhrase('ta', 'notifications'), 'அறிவிப்புகள்');
    expect(ownerPhrase('en', 'bookings'), 'Bookings');
    expect(ownerPhrase('fr', 'bookings'), 'Bookings');
    expect(ownerPhrase('ta', 'missing'), 'missing');
    expect(ownerTabLabel('en', 'venues', selected: false), 'Venues');
    expect(ownerTabLabel('en', 'venues', selected: true), 'Venues, selected');
    expect(ownerTabLabel('ta', 'venues', selected: true), 'அரங்கங்கள், தேர்ந்தெடுக்கப்பட்டது');
    expect(ownerNoticeLabel('en', 'Arrival due', 'Ada is due at 09:30.', unread: true), 'Arrival due. Ada is due at 09:30., unread');
    expect(ownerNoticeLabel('ta', 'Arrival due', 'Ada is due at 09:30.', unread: false), 'Arrival due. Ada is due at 09:30.');
    expect(ownerBarHeight(1), 68);
    expect(ownerBarHeight(0.8), 68);
    expect(ownerBarHeight(2), 92);
  });
}
