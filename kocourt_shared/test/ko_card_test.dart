import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';

void main() {
  testWidgets('KoCard shows its parts and runs the one action', (tester) async {
    var tapped = 0;
    await tester.pumpWidget(MaterialApp(
      theme: AppTheme.player,
      home: Scaffold(
        body: KoCard(
          sport: 'turf',
          kicker: 'Your next game',
          title: 'Kick Arena',
          meta: 'Tue 25 Nov',
          badge: '7 PM',
          stats: const [KoStat('02:14', 'to kick-off'), KoStat('60', 'minutes'), KoStat('₹240', 'paid'), KoStat('x', 'ignored')],
          actionLabel: 'Open pass',
          onAction: () => tapped++,
        ),
      ),
    ));
    expect(find.text('YOUR NEXT GAME'), findsOneWidget);
    expect(find.text('Kick Arena'), findsOneWidget);
    expect(find.text('7 PM'), findsOneWidget);
    expect(find.text('₹240'), findsOneWidget);
    expect(find.text('ignored'), findsNothing, reason: 'at most three stat tiles');
    expect(find.byType(SportIcon), findsOneWidget);
    await tester.tap(find.text('Open pass'));
    expect(tapped, 1);
  });

  testWidgets('personal card has no sport icon', (tester) async {
    await tester.pumpWidget(MaterialApp(theme: AppTheme.player, home: const Scaffold(body: KoCard(kicker: 'Player card', title: 'Arjun'))));
    expect(find.byType(SportIcon), findsNothing);
    expect(find.text('Arjun'), findsOneWidget);
  });
}
