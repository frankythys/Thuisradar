import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/utils/clock.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/sos_button.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../location/application/location_providers.dart';
import '../../member/presentation/member_detail_screen.dart';
import '../application/map_providers.dart';
import '../domain/member_on_map.dart';
import 'widgets/family_header.dart';
import 'widgets/family_map.dart';
import 'widgets/member_list_sheet.dart';
import 'widgets/tracking_banner.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _memberZoom = 15.0;

  final _mapController = MapController();
  bool _mapReady = false;
  bool _hasFittedCamera = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  @override
  void dispose() {
    _mapController.dispose();
    super.dispose();
  }

  void _startTracking() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    ref.read(locationTrackerProvider.notifier).start(userId: userId, familyId: widget.family.id);
  }

  Future<void> _signOut() async {
    ref.read(locationTrackerProvider.notifier).stop();
    await ref.read(authRepositoryProvider).signOut();
  }

  /// Toont alle leden met een locatie, één keer zodra de data er is.
  void _fitAllOnce(List<MemberOnMap> members) {
    if (_hasFittedCamera || !_mapReady) return;
    final points = [
      for (final m in members)
        if (m.location case final l?) LatLng(l.latitude, l.longitude),
    ];
    if (points.isEmpty) return;

    _hasFittedCamera = true;
    if (points.length == 1) {
      _mapController.move(points.single, _memberZoom);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 320),
          maxZoom: _memberZoom,
        ),
      );
    }
  }

  void _openDetail(MemberOnMap entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => MemberDetailScreen(member: entry.member, location: entry.location),
      ),
    );
  }

  void _comingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$feature komt binnenkort')));
  }

  @override
  Widget build(BuildContext context) {
    final familyId = widget.family.id;
    final membersAsync = ref.watch(membersOnMapProvider(familyId));
    final members = membersAsync.value ?? const <MemberOnMap>[];
    final trackingStatus = ref.watch(locationTrackerProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    if (members.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fitAllOnce(members));
    }

    return Scaffold(
      body: Stack(
        children: [
          FamilyMap(
            controller: _mapController,
            members: members,
            onMapReady: () {
              _mapReady = true;
              _fitAllOnce(members);
            },
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FamilyHeader(family: widget.family, onSignOut: _signOut),
                      const Spacer(),
                      SosButton(compact: true, onPressed: () => _comingSoon('SOS')),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TrackingBanner(
                    status: trackingStatus,
                    onRetry: _startTracking,
                    onOpenSettings: () => ref.read(locationTrackerProvider.notifier).openSettings(),
                  ),
                ],
              ),
            ),
          ),
          if (membersAsync.hasError)
            ErrorView(
              message: 'Familie kon niet geladen worden.',
              onRetry: () {
                ref.invalidate(familyMembersProvider(familyId));
                ref.invalidate(familyLocationsProvider(familyId));
              },
            )
          else
            MemberListSheet(
              members: members,
              currentUserId: ref.watch(currentUserIdProvider),
              now: now,
              onSelect: _openDetail,
            ),
        ],
      ),
    );
  }
}
