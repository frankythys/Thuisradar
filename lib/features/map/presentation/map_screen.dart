import 'dart:async';

import '../../location/application/tracking_status.dart';
import 'widgets/offline_members.dart';

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
import '../../../core/config/feature_flags.dart';
import '../../geofencing/application/geofencing_providers.dart';
import '../application/map_style_provider.dart';
import 'widgets/map_style_button.dart';
import '../../location/application/location_providers.dart';
import '../../location/domain/trip_status.dart';
import '../../family/presentation/invite_screen.dart';
import '../../family/presentation/family_setup_screen.dart';
import '../../member/presentation/member_detail_screen.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/add_place_screen.dart';
import '../../places/presentation/places_screen.dart';
import '../../sos/application/sos_providers.dart';
import '../../sos/domain/sos_alert.dart';
import '../../sos/presentation/sos_screen.dart';
import '../../sos/presentation/widgets/sos_app_bar_button.dart';
import '../../../shared/widgets/profile_action.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../application/map_providers.dart';
import '../domain/auto_fit.dart';
import '../domain/member_on_map.dart';
import 'widgets/family_map.dart';
import 'widgets/member_list_sheet.dart';
import 'widgets/member_sheet_dimensions.dart';
import 'widgets/tracking_banner.dart';
import 'widgets/no_locations_card.dart';
import 'widgets/sheet_scrim.dart';

part 'map_screen_recenter_button.dart';
part 'map_screen_own_sos_banner.dart';

class MapScreen extends ConsumerStatefulWidget {
  const MapScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<MapScreen> createState() => _MapScreenState();
}

class _MapScreenState extends ConsumerState<MapScreen> {
  static const _memberZoom = 15.0;
  static const _startupZoom = 12.0;

  static const _focusZoom = 16.0;
  static const _drivingFollowZoom = 15.0;

  final _mapController = MapController();
  final _autoFit = AutoFitController();
  final _sheetController = DraggableScrollableController();
  ScrollController? _sheetScrollController;
  bool _mapReady = false;
  bool _followSelected = false;
  String? _lastFollowedUserId;
  DateTime? _lastFollowedUpdate;
  MemberOnMap? _selected;

  /// Ingeklapte hoogte van het paneel als fractie; bijgewerkt bij elke layout.
  double? _sheetMinimum;

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
    unawaited(ref.read(geofenceSyncProvider.notifier).start(userId: userId, familyId: widget.family.id));
  }

  /// Maakt de kaart passend. Automatisch hoogstens één keer en nooit meer nadat
  /// de gebruiker zelf heeft gezoomd/verschoven; [deliberate] (centreerknop)
  /// mag altijd.
  void _fit(List<MemberOnMap> members, {bool deliberate = false}) {
    if (!mounted) return;
    final own = startupMapMember(members, ref.read(currentUserIdProvider));
    final targets = deliberate ? members : [?own];
    final points = [
      for (final m in targets)
        if (m.location case final l?) LatLng(l.latitude, l.longitude),
    ];
    if (!_autoFit.shouldFit(mapReady: _mapReady, hasPoints: points.isNotEmpty, deliberate: deliberate)) {
      return;
    }

    _autoFit.markFitted();
    if (points.length == 1 && deliberate) {
      _mapController.move(points.single, _memberZoom);
    } else {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(60, 120, 60, 320),
          maxZoom: deliberate ? _memberZoom : _startupZoom,
        ),
      );
    }
  }

  /// Bewuste keuze van een lid (lijst of marker): zoom ernaartoe, schuif de
  /// persoonsdetails in het onderpaneel, dat beneden blijft zodat de kaart
  /// zichtbaar blijft. Telt als bewuste beweging en vergrendelt
  /// auto-fit, zodat de kaart daarna niet meer vanzelf terugspringt.
  void _select(MemberOnMap entry) {
    final location = entry.location;
    if (location == null) return;

    _autoFit.lock();
    _followSelected = true;
    _lastFollowedUserId = entry.member.userId;
    _lastFollowedUpdate = location.updatedAt;
    _mapController.move(LatLng(location.latitude, location.longitude), _focusZoom);
    setState(() => _selected = entry);
    // Het paneel gaat altijd beneden staan: de persoon zie je op de kaart,
    // de details schuif je zelf omhoog.
    _collapseSheet();
  }

  /// Tik op een groepspin: zoom in zodat de leden uit elkaar gaan.
  void _onGroupTap(LatLng center) {
    _autoFit.lock();
    final zoom = (_mapController.camera.zoom + 2).clamp(1.0, 18.0);
    _mapController.move(center, zoom);
  }

  void _deselect() {
    _followSelected = false;
    _lastFollowedUserId = null;
    _lastFollowedUpdate = null;
    if (_selected == null) return;
    setState(() => _selected = null);
    _collapseSheet();
  }

  /// Terug naar de personen: het paneel zakt weer naar onder en de lijst
  /// begint bovenaan, zodat de kaart opnieuw zo groot mogelijk is.
  ///
  /// Pas ná de volgende frame: dan is de inhoud al gewisseld (lijst ↔
  /// persoon). Een animatie die tijdens die wissel start, wordt stil
  /// afgebroken en het paneel bleef dan hoog staan.
  void _collapseSheet() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final minimum = _sheetMinimum;
      if (!mounted || minimum == null || !_sheetController.isAttached) return;
      // Reset ook de interne lijstpositie, zodat de inhoud bovenaan begint.
      if (_sheetScrollController?.hasClients == true) _sheetScrollController!.jumpTo(0);
      _sheetController.animateTo(minimum, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  void _onUserGesture() {
    _autoFit.lock();
    _followSelected = false;
  }

  void _followMovingSelected(MemberOnMap? selected) {
    if (!_mapReady || !_followSelected || selected?.location == null) return;
    final location = selected!.location!;
    final status = TripStatus.at(location, ref.read(clockProvider).value ?? DateTime.now());
    if (status.state != TripState.moving) return;
    if (_lastFollowedUserId == selected.member.userId && _lastFollowedUpdate == location.updatedAt) {
      return;
    }

    _lastFollowedUserId = selected.member.userId;
    _lastFollowedUpdate = location.updatedAt;
    _mapController.move(LatLng(location.latitude, location.longitude), _drivingFollowZoom);
  }

  void _openDetail(MemberOnMap entry) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) =>
            MemberDetailScreen(member: entry.member, familyId: widget.family.id, location: entry.location),
      ),
    );
  }

  void _openInvite() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => InviteScreen(family: widget.family)));
  }

  void _openPlaces() {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => PlacesScreen(family: widget.family)));
  }

  void _addPlace() {
    Navigator.of(context)
        .push(MaterialPageRoute<void>(builder: (_) => AddPlaceScreen(familyId: widget.family.id)));
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
      final members = ref.read(anchoredMembersOnMapProvider(familyId)).value ?? const <MemberOnMap>[];
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
    final membersAsync = ref.watch(anchoredMembersOnMapProvider(familyId));
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

    final noLocations = membersAsync.hasValue && members.every((m) => m.location == null);
    final offline = trackingStatus == TrackingStatus.offline;
    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const <Place>[];
    final placeByUser = ref.watch(currentPlaceByUserProvider(familyId));
    final stationarySinceByUser = ref.watch(stationarySinceProvider(familyId));

    // Houd het gekozen lid vers (locatie/batterij uit de realtime-stroom).
    MemberOnMap? selected;
    if (_selected case final chosen?) {
      for (final m in members) {
        if (m.member.userId == chosen.member.userId) selected = m;
      }
      selected ??= chosen;
    }
    if (selected != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _followMovingSelected(selected));
    }

    final size = MediaQuery.sizeOf(context);
    final sheetTop = MemberSheetDimensions.collapsedHeight(
      context,
      size.width,
      familyName: widget.family.name,
      showInvite: MemberSheetDimensions.showsInvite(canInvite: true, memberCount: members.length),
    );

    return Scaffold(
      appBar: BrandedAppBar(
        title: 'Kaart',
        // SOS naast je avatar: altijd bereikbaar, zonder de kaart te bedekken.
        actions: [
          SosAppBarButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute<void>(
                builder: (_) => SosScreen(familyId: familyId, onActivate: _raiseSos),
              ),
            ),
          ),
          const ProfileAction(),
        ],
      ),
      body: Stack(
        children: [
          FamilyMap(
            controller: _mapController,
            members: members,
            places: places,
            placeByUser: placeByUser,
            stationarySinceByUser: stationarySinceByUser,
            now: now,
            selectedUserId: selected?.member.userId,
            myUserId: myId,
            onMemberTap: _select,
            onHistory: _openDetail,
            onGroupTap: _onGroupTap,
            onUserGesture: _onUserGesture,
            onMapTap: _deselect,
            onMapReady: () {
              _mapReady = true;
              _fit(members);
            },
            satellite: ref.watch(mapSatelliteProvider),
            bottomInset: sheetTop,
          ),
          Positioned(
            right: 16,
            bottom: sheetTop + 16,
            child: _RecenterButton(onPressed: () => _fit(members, deliberate: true)),
          ),
          if (FeatureFlags.useGoogleMaps)
            Positioned(
              right: 16,
              bottom: sheetTop + 16 + 48 + 12,
              child: MapStyleButton(
                satellite: ref.watch(mapSatelliteProvider),
                onPressed: () => unawaited(ref.read(mapSatelliteProvider.notifier).toggle()),
              ),
            ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (offline)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: TrackingBanner(
                        status: trackingStatus,
                        onRetry: _startTracking,
                        onOpenSettings: () => ref.read(deviceLocationSourceProvider).openSettings(),
                      ),
                    ),
                  if (!offline)
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
          if (noLocations)
            Positioned(
              top: offline ? 195 : 100,
              left: 24,
              right: 24,
              child: NoLocationsCard(
                family: widget.family,
                onSettings: () => ref.read(deviceLocationSourceProvider).openSettings(),
              ),
            ),
          if (!noLocations && !membersAsync.hasError)
            Positioned.fill(
              child: IgnorePointer(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final minimum = (sheetTop / constraints.maxHeight).clamp(0.0, 0.94);
                    _sheetMinimum = minimum;
                    return SheetScrim(controller: _sheetController, minimum: minimum);
                  },
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
          else if (noLocations)
            Positioned(
              left: 20,
              right: 20,
              bottom: 16,
              child: OfflineMembers(members: members, onDetails: _openDetail),
            )
          else
            MemberListSheet(
              family: widget.family,
              members: members,
              currentUserId: myId,
              now: now,
              onSelect: _select,
              selectedUserId: selected?.member.userId,
              onDeselect: _deselect,
              placeByUser: placeByUser,
              controller: _sheetController,
              onScrollControllerReady: (controller) => _sheetScrollController = controller,
              onInvite: _openInvite,
              onCreateCircle: () =>
                  Navigator.of(context)
                      .push(MaterialPageRoute<void>(builder: (_) => const FamilySetupScreen())),
              onPlaces: _openPlaces,
              onAddPlace: _addPlace,
            ),
        ],
      ),
    );
  }
}

/// Zwevende knop om de kaart bewust terug op iedereen te centreren.
