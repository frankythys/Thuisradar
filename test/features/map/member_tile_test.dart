import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_tile.dart';

MemberOnMap _entry() => MemberOnMap(
  member: const FamilyMember(userId: 'u1', displayName: 'Papa', isOwner: true, colorIndex: 0),
  location: MemberLocation(
    userId: 'u1',
    familyId: 'fam',
    latitude: 51,
    longitude: 3.7,
    battery: 80,
    updatedAt: DateTime(2026, 1, 2, 10),
  ),
);

void main() {
  testWidgets('tik op de rij en op de chevron zijn aparte acties', (tester) async {
    var taps = 0;
    var details = 0;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Scaffold(
          body: MemberTile(
            entry: _entry(),
            isMe: false,
            now: DateTime(2026, 1, 2, 10, 5),
            onTap: () => taps++,
            onDetails: () => details++,
          ),
        ),
      ),
    );

    await tester.tap(find.byTooltip('Details'));
    expect(details, 1);
    expect(taps, 0);

    await tester.tap(find.text('Papa'));
    expect(taps, 1);
    expect(details, 1);
  });
}
