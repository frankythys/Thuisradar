import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/family/application/family_providers.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/sos/domain/sos_alert.dart';
import 'package:thuisradar/features/sos/presentation/sos_screen.dart';
import 'package:thuisradar/features/sos/presentation/widgets/sos_countdown.dart';
import 'package:thuisradar/features/sos/presentation/widgets/sos_hold_button.dart';
import 'package:thuisradar/shared/widgets/branded_app_bar.dart';

const _members = [
  FamilyMember(userId: 'me', displayName: 'Papa', isOwner: true, colorIndex: 0),
  FamilyMember(userId: 'l', displayName: 'Liam', isOwner: false, colorIndex: 2),
  FamilyMember(userId: 'm', displayName: 'Mama', isOwner: false, colorIndex: 4),
];

Future<void> _pump(WidgetTester tester, {Future<void> Function()? onActivate}) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        currentUserIdProvider.overrideWithValue('me'),
        familyMembersProvider('fam').overrideWith((ref) => Stream.value(_members)),
      ],
      child: MaterialApp(
        theme: AppTheme.light(),
        home: SosScreen(familyId: 'fam', onActivate: onActivate ?? () async {}),
      ),
    ),
  );
  await tester.pump();
}

void main() {
  testWidgets('rustig scherm: kruisje, geen app-balk, ontvangers zonder jezelf, geen Bel 112', (
    tester,
  ) async {
    await _pump(tester);
    expect(find.byType(BrandedAppBar), findsNothing);
    expect(find.byTooltip('Sluiten'), findsOneWidget);
    expect(find.textContaining('Liam, Mama'), findsOneWidget);
    expect(find.textContaining('Papa'), findsNothing);
    expect(find.textContaining('112'), findsNothing);
  });

  testWidgets('past zonder scrollen op 360 × 640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    expect(tester.getBottomLeft(find.textContaining('Liam, Mama')).dy, lessThan(640));
    expect(tester.takeException(), isNull);
  });

  Future<void> holdUntilCountdown(WidgetTester tester) async {
    final hold = await tester.startGesture(tester.getCenter(find.byType(SosHoldButton)));
    await tester.pump();
    await tester.pump(kSosHoldDuration + const Duration(milliseconds: 50));
    await hold.up();
    await tester.pump();
  }

  testWidgets('kort tikken doet niets', (tester) async {
    var sent = 0;
    await _pump(tester, onActivate: () async => sent++);
    final quick = await tester.startGesture(tester.getCenter(find.byType(SosHoldButton)));
    await tester.pump(const Duration(milliseconds: 500));
    await quick.up();
    await tester.pumpAndSettle();
    expect(sent, 0);
    expect(find.byType(SosCountdown), findsNothing);
  });

  testWidgets('3 s inhouden start het aftellen; het alarm vertrekt pas na 10 s', (tester) async {
    var sent = 0;
    await _pump(tester, onActivate: () async => sent++);
    await holdUntilCountdown(tester);
    expect(find.byType(SosCountdown), findsOneWidget);
    expect(find.text('10'), findsOneWidget);
    expect(find.text('Annuleren'), findsOneWidget);

    await tester.pump(kSosCancelDuration - const Duration(seconds: 1));
    expect(sent, 0);
    expect(find.text('1'), findsOneWidget);

    await tester.pump(const Duration(seconds: 1, milliseconds: 50));
    expect(sent, 1);
    await tester.pumpAndSettle();
    expect(find.byType(SosCountdown), findsNothing);
    expect(find.byType(SosHoldButton), findsOneWidget);
  });

  testWidgets('Annuleren tijdens het aftellen: geen alarm', (tester) async {
    var sent = 0;
    await _pump(tester, onActivate: () async => sent++);
    await holdUntilCountdown(tester);
    await tester.pump(const Duration(seconds: 4));
    await tester.tap(find.text('Annuleren'));
    await tester.pump();
    expect(find.byType(SosCountdown), findsNothing);
    await tester.pump(kSosCancelDuration * 2);
    expect(sent, 0);
  });

  testWidgets('het aftellen past op 360 × 640', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(tester);
    await holdUntilCountdown(tester);
    expect(tester.getBottomLeft(find.text('Annuleren')).dy, lessThan(640));
    expect(tester.takeException(), isNull);
  });
}
