import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/utils/clock.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../location/application/location_providers.dart';
import '../../member/presentation/member_detail_screen.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../sos/application/sos_providers.dart';
import '../../sos/domain/sos_alert.dart';
import '../../sos/presentation/widgets/sos_hold_button.dart';
import '../application/map_providers.dart';
import '../domain/auto_fit.dart';
import '../domain/member_on_map.dart';
import 'widgets/family_header.dart';
import 'widgets/family_map.dart';
import 'widgets/member_info_card.dart';
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

  static const _focusZoom = 16.0;

  final _mapController = MapController();
  final _autoFit = AutoFitController();
  final _sheetController = DraggableScrollableController();
  bool _mapReady = false;
  MemberOnMap? _selected;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  @override
  void dispose() {
    _mapController.dispose();
    _sheetController.dispose();
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

  /// Maakt de kaart passend. Automatisch hoogstens één keer en nooit meer nadat
  /// de gebruiker zelf heeft gezoomd/verschoven; [deliberate] (centreerknop)
  /// mag altijd.
  void _fit(List<MemberOnMap> members, {bool deliberate = false}) {
    final points = [
      for (final m in members)
        if (m.location case final l?) LatLng(l.latitude, l.longitude),
    ];
    if (!_autoFit.shouldFit(mapReady: _mapReady, hasPoints: points.isNotEmpty, deliberate: deliberate)) {
      return;
    }

    _autoFit.markFitted();
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

  /// Bewuste keuze van een lid (lijst of marker): zoom ernaartoe, schuif de
  /// lijst in en toon het info-kaartje. Telt als bewuste beweging en vergrendelt
  /// auto-fit, zodat de kaart daarna niet meer vanzelf terugspringt.
  void _select(MemberOnMap entry) {
    final location = entry.location;
    if (location == null) return;

    _autoFit.lock();
    _mapController.move(LatLng(location.latitude, location.longitude), _focusZoom);
    if (_sheetController.isAttached) {
      _sheetController.animateTo(0.14, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    }
    setState(() => _selected = entry);
  }

  /// Tik op een groepspin: zoom in zodat de leden uit elkaar gaan.
  void _onGroupTap(LatLng center) {
    _autoFit.lock();
    final zoom = (_mapController.camera.zoom + 2).clamp(1.0, 18.0);
    _mapController.move(center, zoom);
  }

  void _deselect() {
    if (_selected != null) setState(() => _selected = null);
  }

  void _openProfile() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => ProfileScreen(family: widget.family)));
  }

  void _openDetail(MemberOnMap entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MemberDetailScreen(member: entry.member, familyId: widget.family.id, location: entry.location),
      ),
    );
  }

  void _snack(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _raiseSos() async {
    final familyId = widget.family.id;
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) {
      _snack('Je locatie is nog niet beschikbaar. Probeer het zo opnieuw.');
      return;
    }

    // Verse GPS-positie (max 5 s), anders de laatst gedeelde locatie.
    final fresh = await ref.read(deviceLocationSourceProvider).currentPosition();
    var lat = fresh?.latitude;
    var lng = fresh?.longitude;
    if (lat == null || lng == null) {
      final members = ref.read(membersOnMapProvider(familyId)).value ?? const <MemberOnMap>[];
      for (final m in members) {
        if (m.member.userId == myId && m.location != null) {
          lat = m.location!.latitude;
          lng = m.location!.longitude;
        }
      }
    }
    if (lat == null || lng == null) {
      _snack('Je locatie is nog niet beschikbaar. Probeer het zo opnieuw.');
      return;
    }

    try {
      await ref
          .read(sosRepositoryProvider)
          .raise(familyId: familyId, userId: myId, latitude: lat, longitude: lng);
      _snack('SOS verzonden naar je gezin.');
    } on Exception {
      _snack('SOS versturen mislukt. Probeer opnieuw.');
    }
  }

  @override
  Widget build(BuildContext context) {
    final familyId = widget.family.id;
    final membersAsync = ref.watch(membersOnMapProvider(familyId));
    final members = membersAsync.value ?? const <MemberOnMap>[];
    final trackingStatus = ref.watch(locationTrackerProvider);
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    final myId = ref.watch(currentUserIdProvider);
    final activeSos = ref.watch(activeSosProvider(familyId)).value ?? const <SosAlert>[];
    SosAlert? myAlert;
    for (final alert in activeSos) {
      if (alert.userId == myId) myAlert = alert;
    }

    // Tijdens een eigen actieve SOS vaker uploaden, daarna terug normaal.
    ref.listen(activeSosProvider(familyId), (_, next) {
      final mine = (next.value ?? const <SosAlert>[]).any((a) => a.userId == myId);
      ref.read(locationTrackerProvider.notifier).setFastUpdates(mine);
    });

    if (members.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _fit(members));
    }

    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const <Place>[];
    final placeByUser = ref.watch(currentPlaceByUserProvider(familyId));

    // Houd het gekozen lid vers (locatie/batterij uit de realtime-stroom).
    MemberOnMap? selected;
    if (_selected case final chosen?) {
      for (final m in members) {
        if (m.member.userId == chosen.member.userId) selected = m;
      }
      selected ??= chosen;
    }

    final size = MediaQuery.sizeOf(context);
    final sheetTop = size.height * 0.34;

    return Scaffold(
      body: Stack(
        children: [
          FamilyMap(
            controller: _mapController,
            members: members,
            places: places,
            now: now,
            selectedUserId: selected?.member.userId,
            myUserId: myId,
            onMemberTap: _select,
            onGroupTap: _onGroupTap,
            onUserGesture: _autoFit.lock,
            onMapTap: _deselect,
            onMapReady: () {
              _mapReady = true;
              _fit(members);
            },
          ),
          Positioned(
            right: 16,
            bottom: sheetTop + 16,
            child: _RecenterButton(onPressed: () => _fit(members, deliberate: true)),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      FamilyHeader(family: widget.family, onSignOut: _signOut, onProfile: _openProfile),
                      const Spacer(),
                      SosHoldButton(onActivate: _raiseSos),
                    ],
                  ),
                  const SizedBox(height: 12),
                  TrackingBanner(
                    status: trackingStatus,
                    onRetry: _startTracking,
                    onOpenSettings: () => ref.read(locationTrackerProvider.notifier).openSettings(),
                  ),
                  if (myAlert case final alert?) ...[
                    const SizedBox(height: 12),
                    _OwnSosBanner(
                      onResolve: () async {
                        await ref.read(sosRepositoryProvider).resolve(alert.id);
                        if (context.mounted) _snack('SOS opgelost.');
                      },
                    ),
                  ],
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
              onSelect: _select,
              onDetails: _openDetail,
              selectedUserId: selected?.member.userId,
              placeByUser: placeByUser,
              controller: _sheetController,
            ),
          if (selected case final entry?)
            Positioned(
              left: 16,
              right: 16,
              bottom: size.height * 0.14 + 16,
              child: MemberInfoCard(
                entry: entry,
                now: now,
                placeStatus: placeByUser[entry.member.userId],
                onHistory: () => _openDetail(entry),
                onClose: () => setState(() => _selected = null),
              ),
            ),
        ],
      ),
    );
  }
}

/// Zwevende knop om de kaart bewust terug op iedereen te centreren.
class _RecenterButton extends StatelessWidget {
  const _RecenterButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      shape: const CircleBorder(),
      elevation: 3,
      shadowColor: const Color(0x33121C1C),
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: const Tooltip(
          message: 'Toon iedereen',
          child: SizedBox(width: 48, height: 48, child: Icon(Icons.my_location, color: AppColors.primary)),
        ),
      ),
    );
  }
}

/// Banner voor de verzender zelf: zijn SOS is actief, met een knop om op te lossen.
class _OwnSosBanner extends StatelessWidget {
  const _OwnSosBanner({required this.onResolve});

  final Future<void> Function() onResolve;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;

    return Material(
      color: AppColors.alert,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.shield, color: Colors.white),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'SOS actief · je gezin is gewaarschuwd',
                style: text.bodyMedium?.copyWith(color: Colors.white),
              ),
            ),
            TextButton(
              onPressed: onResolve,
              child: const Text('Oplossen', style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
