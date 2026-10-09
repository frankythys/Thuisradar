import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/shared/widgets/app_bottom_nav.dart';
import 'package:thuisradar/shared/widgets/app_card.dart';
import 'package:thuisradar/shared/widgets/battery_badge.dart';
import 'package:thuisradar/shared/widgets/branded_app_bar.dart';
import 'package:thuisradar/shared/widgets/empty_state.dart';
import 'package:thuisradar/shared/widgets/filter_chips.dart';
import 'package:thuisradar/shared/widgets/member_avatar.dart';
import 'package:thuisradar/shared/widgets/secondary_chip.dart';
import 'package:thuisradar/shared/widgets/sos_button.dart';

/// Pompt een widget binnen het echte thema, zodat de AppTokens-extensie bestaat.
Future<void> pumpThemed(WidgetTester tester, Widget child, {PreferredSizeWidget? appBar}) {
  return tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(appBar: appBar, body: child),
      ),
    ),
  );
}

const _member = FamilyMember(userId: 'u1', displayName: 'Mama', isOwner: true, colorIndex: 0);

void main() {
  testWidgets('AppCard toont zijn kind', (tester) async {
    await pumpThemed(tester, const AppCard(child: Text('inhoud')));
    expect(find.text('inhoud'), findsOneWidget);
  });

  testWidgets('SosButton en SecondaryChip reageren op tikken', (tester) async {
    var sos = 0;
    var chip = 0;
    await pumpThemed(
      tester,
      Column(
        children: [
          SosButton(onPressed: () => sos++),
          SecondaryChip(label: 'Uitnodigen', icon: Icons.share, onPressed: () => chip++),
        ],
      ),
    );
    await tester.tap(find.text('SOS'));
    await tester.tap(find.text('Uitnodigen'));
    expect(sos, 1);
    expect(chip, 1);
  });

  testWidgets('FilterChips meldt de aangetikte index', (tester) async {
    var selected = 0;
    await pumpThemed(
      tester,
      FilterChips(labels: const ['Vandaag', 'Gisteren'], selectedIndex: 0, onSelected: (i) => selected = i),
    );
    await tester.tap(find.text('Gisteren'));
    expect(selected, 1);
  });

  testWidgets('BatteryBadge toont percentage; lage stand krijgt een pil', (tester) async {
    await pumpThemed(tester, const BatteryBadge(level: 15));
    expect(find.text('15%'), findsOneWidget);
    expect(find.byType(Container), findsWidgets);
  });

  testWidgets('BatteryBadge is leeg zonder niveau', (tester) async {
    await pumpThemed(tester, const BatteryBadge(level: null));
    expect(find.byType(Text), findsNothing);
  });

  testWidgets('MemberAvatar toont het initiaal en de statusstip', (tester) async {
    await pumpThemed(tester, const MemberAvatar(member: _member, statusColor: Colors.green));
    expect(find.text('M'), findsOneWidget);
  });

  testWidgets('EmptyState toont titel, bericht en actie', (tester) async {
    var tapped = 0;
    await pumpThemed(
      tester,
      EmptyState(
        icon: Icons.chat_bubble_outline,
        title: 'Nog geen berichten',
        message: 'Binnenkort kun je hier chatten.',
        actionLabel: 'Oké',
        onAction: () => tapped++,
      ),
    );
    expect(find.text('Nog geen berichten'), findsOneWidget);
    await tester.tap(find.text('Oké'));
    expect(tapped, 1);
  });

  testWidgets('AppBottomNav meldt de gekozen tab', (tester) async {
    var tab = AppTab.kaart;
    await pumpThemed(tester, AppBottomNav(current: AppTab.kaart, onSelected: (t) => tab = t));
    await tester.tap(find.text('Chat'));
    expect(tab, AppTab.chat);
  });

  testWidgets('BrandedAppBar toont merknaam en titel', (tester) async {
    await pumpThemed(tester, const SizedBox(), appBar: const BrandedAppBar(title: 'Kaart'));
    expect(find.text('CIRCLEBEACON'), findsOneWidget);
    expect(find.text('Kaart'), findsOneWidget);
  });

  testWidgets('BrandedAppBar toont geen terugknop op een root-scherm', (tester) async {
    await pumpThemed(tester, const SizedBox(), appBar: const BrandedAppBar(title: 'Kaart'));
    expect(find.byTooltip('Terug'), findsNothing);
  });

  testWidgets('BrandedAppBar toont een werkende terugknop op een gepusht scherm', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).push(
                    MaterialPageRoute<void>(
                      builder: (_) => const Scaffold(appBar: BrandedAppBar(title: 'Detail')),
                    ),
                  ),
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsOneWidget);
    expect(find.byTooltip('Terug'), findsOneWidget);

    await tester.tap(find.byTooltip('Terug'));
    await tester.pumpAndSettle();
    expect(find.text('Detail'), findsNothing);
    expect(find.text('open'), findsOneWidget);
  });
}
