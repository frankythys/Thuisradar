import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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

Widget _wrap(MemberTile tile) => ProviderScope(
  child: MaterialApp(theme: AppTheme.light(), home: Scaffold(body: tile)),
);

void main() {
  testWidgets('tik op de rij opent het lid', (tester) async {
    var taps = 0;

    await tester.pumpWidget(
      _wrap(
        MemberTile(
          entry: _entry(),
          isMe: false,
          now: DateTime(2026, 1, 2, 10, 5),
          onTap: () => taps++,
        ),
      ),
    );

    await tester.tap(find.text('Papa'));
    expect(taps, 1);
  });

  testWidgets('toont de naam, sinds-tijd en batterijstand', (tester) async {
    await tester.pumpWidget(
      _wrap(
        MemberTile(entry: _entry(), isMe: false, now: DateTime(2026, 1, 2, 10, 0, 20)),
      ),
    );

    expect(find.text('Papa'), findsOneWidget);
    expect(find.text('Sinds 10:00'), findsOneWidget);
    expect(find.text('80%'), findsOneWidget);
  });
}
