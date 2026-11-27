import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  test('jersey initials', () {
    expect(jerseyInitials('Arjun Kumar'), 'AK');
    expect(jerseyInitials('ravi'), 'R');
    expect(jerseyInitials('  Sam  P  Lee '), 'SL');
    expect(jerseyInitials(''), '?');
  });

  testWidgets('jersey row caps plates and counts the rest', (tester) async {
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.player,
      home: const Scaffold(body: JerseyRow(names: ['Arjun K', 'Ravi', 'Sam', 'Priya'], open: 3, max: 5, note: '1 spot open')),
    ));
    expect(find.text('AK'), findsOneWidget);
    expect(find.byIcon(Icons.add), findsOneWidget, reason: '4 names + 1 open plate fill the 5 slots');
    expect(find.text('+2'), findsOneWidget, reason: 'two open spots did not fit');
    expect(find.text('1 spot open'), findsOneWidget);
  });
}
