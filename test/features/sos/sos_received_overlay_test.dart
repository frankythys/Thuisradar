import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/sos/presentation/sos_received_overlay.dart';

import 'sos_received_fakes.dart';

void main() {
  setUp(mockMapCache);

  testWidgets('toont het adres in plaats van coördinaten', (tester) async {
    await tester.pumpWidget(sosReceivedApp());
    await tester.pump();
    await tester.pump();
    expect(find.text('Liam heeft hulp nodig'), findsOneWidget);
    expect(find.text('Kerkstraat 42, Gent'), findsOneWidget);
    expect(find.textContaining('51.05430'), findsNothing);
  });

  testWidgets('Navigeer en Bel naast elkaar, 112 en Toon op kaart onderaan', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      sosReceivedApp(
        receipts: [
          {'user_id': 'mama', 'on_the_way': true},
        ],
      ),
    );
    await tester.pump();
    await tester.pump();

    final navigate = tester.getCenter(find.text('Navigeer'));
    final call = tester.getCenter(find.text('Bel Liam'));
    expect((navigate.dy - call.dy).abs(), lessThan(1));
    expect(find.text('Ik ben onderweg'), findsOneWidget);
    expect(find.text('Mama is onderweg'), findsOneWidget);
    for (final label in ['Bel 112', 'Toon op kaart']) {
      final bottom = tester.getBottomLeft(find.text(label)).dy;
      expect(bottom, greaterThan(tester.getBottomLeft(find.text('Ik ben onderweg')).dy));
      expect(bottom, lessThan(640));
    }
    expect(tester.takeException(), isNull);
  });

  testWidgets('kruisje sluit het alarm', (tester) async {
    var closed = false;
    await tester.pumpWidget(
      ProviderScope(
        overrides: sosReceivedOverrides(),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: SosReceivedOverlay(
              alert: sosTestAlert,
              name: 'Liam',
              onShowOnMap: () {},
              onDismiss: () => closed = true,
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.byTooltip('Sluiten'));
    expect(closed, isTrue);
  });
}
