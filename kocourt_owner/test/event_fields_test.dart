import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_owner/screens/owner/event_fields.dart';

void main() {
  test('the event list reads organizer rows', () {
    final rows = eventRows({
      'tournaments': [
        {'id': 3, 'title': 'City Open', 'sport': 'tennis', 'status': 'draft'},
      ],
    });
    expect(rows, hasLength(1));
    expect(rows.first['title'], 'City Open');
    expect(eventRows({'message': 'Forbidden'}), isEmpty);
  });

  test('a draft needs a title and a sport, and times stay in order', () {
    expect(eventDraftBody(title: ' ', sport: 'tennis'), isNull);
    final body = eventDraftBody(
      title: 'City Open',
      sport: 'tennis',
      courtId: '4',
      start: '2026-12-01 09:00:00',
      end: '2026-12-01 18:00:00',
    );
    expect(body, {
      'title': 'City Open',
      'sport': 'tennis',
      'visibility': 'private',
      'court_id': 4,
      'start_time': '2026-12-01 09:00:00',
      'end_time': '2026-12-01 18:00:00',
    });
    expect(
      eventDraftBody(title: 'City Open', sport: 'tennis', start: '2026-12-01 18:00:00', end: '2026-12-01 09:00:00'),
      isNull,
    );
  });

  test('publish and unpublish follow the saved status', () {
    expect(eventStatusLabel('draft'), 'Draft');
    expect(eventAction('draft'), 'publish');
    expect(eventAction('published'), 'unpublish');
    expect(eventAction('cancelled'), isNull);
  });

  test('a category needs a name and a non-negative fee', () {
    expect(categoryBody(name: ' '), isNull);
    expect(
      categoryBody(name: 'Open singles', format: 'singles', fee: '500', capacity: '16', waitlist: true),
      {'name': 'Open singles', 'format': 'singles', 'waitlist': true, 'approval': false, 'fee': 500, 'capacity': 16},
    );
    expect(categoryBody(name: 'Open singles', fee: '-1'), isNull);
  });

  test('an entry line names the player, state, and fee', () {
    final rows = registrationRows({
      'registrations': [
        {'id': 9, 'captain_user_id': 7, 'state': 'pending', 'fee_amount': 100, 'idempotency_key': 'entry-key-1'},
      ],
    });
    expect(rows, hasLength(1));
    expect(registrationLine(rows.first), 'Player 7 · Pending · fee 100');
    expect(registrationLabel('confirmed'), 'Confirmed');
    expect(registrationLabel('pending_approval'), 'Pending approval');
    expect(registrationLabel('waitlisted'), 'Waitlisted');
    expect(registrationRows({'message': 'Forbidden'}), isEmpty);
    expect(
      registrationLine({'captain_user_id': 7, 'state': 'confirmed', 'fee_amount': 100, 'check_in_code': 'ABCD2345', 'checked_in_at': '2026-12-01 09:00:00'}),
      'Player 7 · Confirmed · fee 100 · ABCD2345 · Checked in',
    );
    expect(checkInCodeBody(' abcd2345 '), {'code': 'ABCD2345'});
    expect(checkInCodeBody('ABCD234O'), isNull);
    expect(announcementBody(title: ' Gates ', body: ' Use gate B. '), {'title': 'Gates', 'body': 'Use gate B.'});
    expect(announcementBody(title: '', body: 'Hello'), isNull);
    expect(announcementRows({'announcements': [{'id': 1, 'title': 'Gates', 'body': 'Use gate B.'}]}).first['title'], 'Gates');
    expect(registrationCanCheckIn({'state': 'confirmed', 'checked_in_at': null}), isTrue);
    expect(registrationCanCheckIn({'state': 'pending', 'checked_in_at': null}), isFalse);
    expect(registrationCanCheckIn({'state': 'confirmed', 'checked_in_at': '2026-12-01 09:00:00'}), isFalse);
  });

  test('a participant file starts with the export header', () {
    expect(participantCsv('Category,Player,State,Fee,Code,"Checked in"\nOpen,Ada,confirmed,100.00,ABCD2345,"2026-12-01 09:00:00"\n'), isTrue);
    expect(participantCsv('{"message":"Forbidden"}'), isFalse);
    expect(participantCsv('Category,Phone\n'), isFalse);
  });

  test('a match needs two different entries and a higher score', () {
    final rows = matchRows({
      'matches': [
        {'id': 1, 'status': 'scheduled', 'home_registration_id': 4, 'away_registration_id': 9},
      ],
    });
    expect(matchLine(rows.first), 'Entry 4 vs entry 9 · Scheduled');
    expect(matchBody(homeId: 4, awayId: 4), isNull);
    expect(matchBody(homeId: 4, awayId: 9), {'home_registration_id': 4, 'away_registration_id': 9});
    expect(resultBody(homeId: 4, awayId: 9, homeScore: '2', awayScore: '1'), {
      'home_score': 2,
      'away_score': 1,
      'winner_registration_id': 4,
    });
    expect(resultBody(homeId: 4, awayId: 9, homeScore: '1', awayScore: '1'), isNull);
    expect(
      matchLine({'status': 'completed', 'home_registration_id': 4, 'away_registration_id': 9, 'home_score': 2, 'away_score': 1, 'winner_registration_id': 4}),
      'Entry 4 vs entry 9 · 2-1 · winner 4',
    );
    expect(matchLine({'status': 'bye', 'home_registration_id': 12}), 'Entry 12 has a bye');
    expect(
      matchLine({'round_label': 'Round 2', 'status': 'scheduled', 'home_registration_id': 4, 'away_registration_id': 9}),
      'Round 2 · Entry 4 vs entry 9 · Scheduled',
    );
    expect(bracketChampion({'champion_registration_id': 4}), 4);
    expect(championLine(4), 'Entry 4 wins the category');
    expect(bracketChampion({'matches': []}), isNull);
  });
}
