import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/core/utils/clock.dart';
import 'package:thuisradar/features/family/domain/family.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/application/address_providers.dart';
import 'package:thuisradar/features/location/application/location_history_providers.dart';
import 'package:thuisradar/features/location/application/location_providers.dart';
import 'package:thuisradar/features/location/data/geocoding_source.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/location/domain/place_address.dart';
import 'package:thuisradar/features/location/domain/timeline.dart';
import 'package:thuisradar/features/location/domain/track_point.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_list_sheet.dart';
import 'package:thuisradar/features/notifications/application/events_providers.dart';
import 'package:thuisradar/features/places/application/places_providers.dart';

class _NoGeocoding extends GeocodingSource {
  @override
  Future<PlaceAddress?> addressFor(double latitude, double longitude) async => null;
}

/// Doet wat de kaart doet bij een tik op een persoon (zie MapScreen._select).
class _Host extends StatefulWidget {
  const _Host({required this.controller, required this.members, required this.minimum});

  final DraggableScrollableController controller;
  final List<MemberOnMap> members;
  final double Function() minimum;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  String? selected;

  @override
  Widget build(BuildContext context) => MemberListSheet(
    family: const Family(id: 'fam', name: 'Gezin', inviteCode: 'ABC12345'),
    controller: widget.controller,
    members: widget.members,
    currentUserId: 'u1',
    now: DateTime(2026, 10, 9, 12),
    selectedUserId: selected,
    onSelect: (entry) {
      // Zelfde volgorde als MapScreen._select: eerst de persoon tonen, het
      // paneel pas na de wissel naar beneden.
      setState(() => selected = entry.member.userId);
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => widget.controller.animateTo(
          widget.minimum(),
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        ),
      );
    },
    onDeselect: () => setState(() => selected = null),
    onInvite: () {},
    onPlaces: () {},
    onAddPlace: () {},
  );
}

void main() {
  testWidgets('tik op een persoon in een opgeschoven paneel: het paneel staat daarna beneden', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1080, 2400);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    final now = DateTime(2026, 10, 9, 12);
    final controller = DraggableScrollableController();
    addTearDown(controller.dispose);
    double? minimum;
    final members = [
      MemberOnMap(
        member: const FamilyMember(userId: 'u1', displayName: 'Franky', isOwner: true, colorIndex: 0),
        location: MemberLocation(userId: 'u1', familyId: 'fam', latitude: 51, longitude: 4, updatedAt: now),
      ),
      MemberOnMap(
        member: const FamilyMember(userId: 'u2', displayName: 'Liam', isOwner: false, colorIndex: 1),
        location: MemberLocation(userId: 'u2', familyId: 'fam', latitude: 51.1, longitude: 4, updatedAt: now),
      ),
    ];

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          geocodingSourceProvider.overrideWithValue(_NoGeocoding()),
          familyPlacesProvider.overrideWith((ref, id) => Stream.value(const [])),
          clockProvider.overrideWith((ref) => Stream.value(now)),
          familyLocationsProvider.overrideWith((ref, id) => Stream.value(const <MemberLocation>[])),
          dayHistoryProvider.overrideWith(
            (ref, arg) async => (entries: const <TimelineEntry>[], points: const <TrackPoint>[]),
          ),
          recentTimelineProvider.overrideWith((ref, arg) async => const []),
          familyPresenceProvider.overrideWith((ref, id) => Stream.value(const [])),
          familyEventsProvider.overrideWith((ref, id) => Stream.value(const [])),
        ],
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: _Host(controller: controller, members: members, minimum: () => minimum!),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    minimum = controller.size;

    // Paneel omhoog geschoven, zoals na het bekijken van de lijst.
    controller.jumpTo(0.8);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Liam'));
    await tester.pumpAndSettle();

    expect(find.text('Terug naar personen'), findsOneWidget);
    expect(controller.size, moreOrLessEquals(minimum, epsilon: 0.01));
  });
}
