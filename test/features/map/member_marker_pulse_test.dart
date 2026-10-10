import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_colors.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_marker.dart';

void main() {
  const franky = MemberOnMap(
    member: FamilyMember(userId: 'Franky', displayName: 'Franky', isOwner: true, colorIndex: 0),
  );

  Finder glow() => find.byWidgetPredicate(
    (w) =>
        w is DecoratedBox &&
        w.decoration is BoxDecoration &&
        (w.decoration as BoxDecoration).shape == BoxShape.circle &&
        (w.decoration as BoxDecoration).color?.toARGB32() ==
            AppColors.mapSelection.withValues(alpha: 0.35 * 0.5).toARGB32(),
  );

  Future<void> pump(WidgetTester tester, {required bool selected, double? pulse}) => tester.pumpWidget(
    MaterialApp(
      theme: AppTheme.light(),
      home: Center(
        child: MemberMarker(entry: franky, now: DateTime(2026), selected: selected, pulse: pulse),
      ),
    ),
  );

  testWidgets('geselecteerd: halverwege de puls een zachte, half vervaagde lichtkring', (tester) async {
    await pump(tester, selected: true, pulse: 0.5);
    expect(glow(), findsOneWidget);
    // De kring verschuift het rondje niet: zelfde plek als zonder puls.
    final withPulse = tester.getCenter(find.byType(MemberMarker));
    await pump(tester, selected: true);
    expect(tester.getCenter(find.byType(MemberMarker)), withPulse);
  });

  testWidgets('niet geselecteerd: geen lichtkring', (tester) async {
    await pump(tester, selected: false, pulse: 0.5);
    expect(glow(), findsNothing);
  });
}
