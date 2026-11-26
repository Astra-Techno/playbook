import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kocourt_shared/kocourt_shared.dart';
import 'package:kocourt_shared/widgets/sport_icon_svgs.g.dart';

void main() {
  test('generated Dart icons match assets/sports (run tool/gen_sport_icons.py)', () {
    final files = Directory('assets/sports').listSync().whereType<File>().where((f) => f.path.endsWith('.svg')).toList();
    expect(files.length, sportIconSvgs.length);
    for (final f in files) {
      final name = f.uri.pathSegments.last.replaceAll('.svg', '');
      expect(sportIconSvgs[name], f.readAsStringSync().trim(), reason: name);
    }
  });

  test('every venue sport has an icon and its colours are filled in', () {
    for (final c in sportCategories.where((c) => c.id != 'All')) {
      final svg = sportIconSvg(c.id);
      expect(svg, isNotNull, reason: c.id);
      expect(svg, isNot(contains('var(')), reason: c.id);
    }
    expect(sportIconKey('turf'), 'football');
    expect(sportIconKey('Shuttle'), 'badminton');
    expect(sportIconKey('basket'), 'basketball');
    expect(sportIconKey('pickleball'), 'pickleball');
    expect(sportIconKey('All'), isNull);
    expect(sportIconKey(null), isNull);
    expect(sportIconSvg('turf', tone: Colors.white), contains('stroke="#ffffff"'));
    expect(sportIconSvg('turf'), contains('#047857'));
  });

  testWidgets('unknown sport shows the fallback icon', (tester) async {
    await tester.pumpWidget(const MaterialApp(home: SportIcon('curling', fallback: Icons.sports)));
    expect(find.byIcon(Icons.sports), findsOneWidget);
  });
}
