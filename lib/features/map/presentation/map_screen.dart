import 'dart:async';
import 'dart:math' as math;

import '../../location/application/tracking_status.dart';
import 'widgets/offline_members.dart';

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../shared/widgets/error_view.dart';
import '../../auth/application/auth_providers.dart';
import '../../emergency/application/emergency_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../../core/config/feature_flags.dart';
import '../../geofencing/application/geofencing_providers.dart';
import '../../geofencing/presentation/geofence_banner.dart';
import '../application/map_view_recorder.dart';
import '../data/map_view_store.dart';
import '../application/map_style_provider.dart';
import 'widgets/map_style_button.dart';
import '../../location/application/location_providers.dart';
import '../../permissions/application/permissions_providers.dart';
import '../../permissions/presentation/location_disclosure_dialog.dart';
import '../../family/presentation/invite_screen.dart';
import '../../family/presentation/family_setup_screen.dart';
import '../../member/presentation/member_detail_screen.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place.dart';
import '../../places/presentation/add_place_screen.dart';
import '../../places/presentation/places_screen.dart';
import '../../parked_car/application/parked_car_providers.dart';
import '../../parked_car/domain/parked_car.dart';
import '../../parked_car/presentation/parked_car_flow.dart';
import '../../parked_car/presentation/parked_car_map_action.dart';
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
import 'widgets/map_compass_button.dart';
import 'widgets/member_list_sheet.dart';
import 'widgets/member_sheet_dimensions.dart';
import 'widgets/offscreen_members_layer.dart' show MapCover;
import 'widgets/tracking_banner.dart';
import 'widgets/no_locations_card.dart';
import 'widgets/sheet_scrim.dart';
import '../../../l10n/l10n.dart';

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

  /// Zonebewaking start pas als de kaart geladen is: het aanmelden van de
  /// zones en de achtergrondmeldingen die Android daarna kan sturen, vragen
  /// anders rekenwerk net terwijl de kaart opbouwt.
  static const _geofenceStartDelay = Duration(seconds: 4);

  final _mapController = MapController();
  final _autoFit = AutoFitController();
  final _sheetController = DraggableScrollableController();
  ScrollController? _sheetScrollController;
  bool _mapReady = false;
  MemberOnMap? _selected;
  Timer? _geofenceStart;

  /// Ingeklapte hoogte van het paneel als fractie; bijgewerkt bij elke layout.
  double? _sheetMinimum;

  /// Onthoudt waar de kaart staat, zodat ze bij de volgende start daar opent.
  late final _viewRecorder = MapViewRecorder(_mapController, ref.read(mapViewStoreProvider));

  @override
  void initState() {
    super.initState();
    _viewRecorder.start();
    WidgetsBinding.instance.addPostFrameCallback((_) => _startTracking());
  }

  @override
  void dispose() {
    _viewRecorder.dispose();
    _geofenceStart?.cancel();
    _mapController.dispose();
    _sheetController.dispose();
    super.dispose();
  }

  void _startTracking() {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    ref.read(locationTrackerProvider.notifier).start(userId: userId, familyId: widget.family.id);
    _geofenceStart = Timer(_geofenceStartDelay, () {
      if (!mounted) return;
      unawaited(ref.read(geofenceSyncProvider.notifier).start(userId: userId, familyId: widget.family.id));
    });
  }

  /// "Toestaan" op de kaart: eerst de uitleg, pas daarna de Android-vraag.
  Future<void> _allowLocation() async {
    if (!await showLocationDisclosure(context) || !mounted) return;
    await ref.read(permissionServiceProvider).requestLocation();
    if (mounted) _startTracking();
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
    _mapController.move(LatLng(location.latitude, location.longitude), _focusZoom);
    setState(() => _selected = entry);
    // Het paneel gaat altijd beneden staan: de persoon zie je op de kaart,
    // de details schuif je zelf omhoog.
    _collapseSheet();
  }

  /// Tik op de groepsachtergrond behoudt zowel de selectie als de zoom.
  void _onGroupTap(LatLng center) {
    _autoFit.lock();
  }

  void _showParkedCar(ParkedCar car) {
    _autoFit.lock();
    _mapController.move(LatLng(car.latitude, car.longitude), _memberZoom);
  }

  /// Waar het paneel nu staat en waar de knoppen rechts erboven staan
  /// (centreren, auto, kaarttype, kompas: 48 hoog, 12 ertussen). De knoppen
  /// zakken mee als het paneel lager staat dan [sheetTop], maar gaan niet mee
  /// omhoog.
  MapCover _mapCover(double sheetTop) {
    final sheet = _sheetController.isAttached ? _sheetController.pixels : sheetTop;
    final base = math.min(sheet, sheetTop) + 16;
    final buttons = FeatureFlags.useGoogleMaps ? 4 : 3;
    return (sheet: sheet, buttonsWidth: 16 + 48, buttonsBottom: base, buttonsTop: base + buttons * 48 + (buttons - 1) * 12);
  }

  void _deselect() {
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
    final l10n = context.l10n;
    final myId = ref.read(currentUserIdProvider);
    if (myId == null) {
      _snack(l10n.mapLocationNotReady);
      return;
    }

    // Verse GPS-positie (max 8 s), anders de laatst gedeelde locatie.
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
      _snack(l10n.mapLocationNotReady);
      return;
    }

    // Het gezin (internet) en de noodcontacten (sms, ook zonder internet)
    // tegelijk: een trage verbinding mag de sms niet ophouden.
    final raising = ref
        .read(sosRepositoryProvider)
        .raise(familyId: familyId, userId: myId, latitude: lat, longitude: lng)
        .then<bool>(
          (_) => true,
          onError: (Object error) {
            debugPrint('SOS naar het gezin mislukt: $error');
            return false;
          },
        );
    final contacts = await _alertEmergencyContacts(l10n, myId, lat, lng);
    if (!mounted) return;
    final family = await raising ? l10n.mapSosSent : l10n.mapSosFailed;
    _snack([family, ?contacts].join(' '));
  }

  /// Sms naar de noodcontacten en contact 1 bellen; geeft de uitleg voor de
  /// melding terug. Een fout hier mag het alarm voor het gezin nooit stoppen.
  Future<String?> _alertEmergencyContacts(AppLocalizations l10n, String myId, double lat, double lng) async {
    try {
      final members = ref.read(anchoredMembersOnMapProvider(widget.family.id)).value ?? const <MemberOnMap>[];
      final me = members.where((m) => m.member.userId == myId).firstOrNull;
      final contacts = await ref.read(myEmergencyContactsProvider.future);
      final outcome = await ref
          .read(emergencyAlerterProvider)
          .alert(
            l10n: l10n,
            contacts: contacts,
            senderName: me?.member.displayName ?? '',
            latitude: lat,
            longitude: lng,
          );
      return outcome.summary(l10n);
    } on Object catch (error) {
      debugPrint('Noodcontacten verwittigen mislukt: $error');
      return l10n.emergencyAlertFailed;
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
    final parkedCars = ref.watch(familyParkedCarsProvider(familyId)).value ?? const <ParkedCar>[];
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

    final size = MediaQuery.sizeOf(context);
    final sheetTop = MemberSheetDimensions.collapsedHeight(
      context,
      size.width,
      familyName: widget.family.name,
      showInvite: MemberSheetDimensions.showsInvite(canInvite: true, memberCount: members.length),
    );

    return Scaffold(
      appBar: BrandedAppBar(
        // De app-naam bovenaan; de tab onderaan blijft "Kaart".
        title: 'CircleBeacon',
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
            parkedCars: parkedCars,
            onParkedCarTap: (car) => openParkedCar(
              context,
              ref,
              familyId: familyId,
              car: car,
              ownerName: members.where((m) => m.member.userId == car.userId).firstOrNull?.member.displayName,
              onShowCar: _showParkedCar,
            ),
            placeByUser: placeByUser,
            stationarySinceByUser: stationarySinceByUser,
            now: now,
            selectedUserId: selected?.member.userId,
            myUserId: myId,
            onMemberTap: _select,
            onHistory: _openDetail,
            onGroupTap: _onGroupTap,
            onUserGesture: _onUserGesture,
            // Selectie blijft tot "Terug naar personen", ook na kaarttikken.
            onMapTap: null,
            onMapReady: () {
              _mapReady = true;
              _fit(members);
            },
            satellite: ref.watch(mapSatelliteProvider),
            bottomInset: sheetTop,
            cover: () => _mapCover(sheetTop),
            coverChanges: _sheetController,
            savedView: ref.read(savedMapViewProvider),
          ),
          // De knoppen staan boven het paneel en zakken mee als je het lager
          // schuift dan de gewone stand (enkel de greep zichtbaar).
          ListenableBuilder(
            listenable: _sheetController,
            builder: (context, _) {
              final base = _mapCover(sheetTop).buttonsBottom;
              return Stack(
                children: [
                  Positioned(
                    right: 16,
                    bottom: base,
                    child: _RecenterButton(
                      onPressed: () {
                        _fit(members, deliberate: true);
                      },
                    ),
                  ),
                  // Van onder naar boven: centreren, auto, kaarttype, kompas
                  // (dat laatste enkel zichtbaar als de kaart gedraaid is).
                  Positioned(
                    right: 16,
                    bottom: base + 48 + 12,
                    child: ParkedCarMapAction(
                      familyId: familyId,
                      parkedCars: parkedCars,
                      onShowCar: _showParkedCar,
                    ),
                  ),
                  if (FeatureFlags.useGoogleMaps)
                    Positioned(
                      right: 16,
                      bottom: base + (48 + 12) * 2,
                      child: MapStyleButton(
                        controller: _mapController,
                        choice: ref.watch(mapSatelliteProvider),
                        onChoose: ref.read(mapSatelliteProvider.notifier).choose,
                      ),
                    ),
                  Positioned(
                    right: 16,
                    bottom: base + (48 + 12) * (FeatureFlags.useGoogleMaps ? 3 : 2),
                    child: MapCompassButton(controller: _mapController),
                  ),
                ],
              );
            },
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
                        onAllow: _allowLocation,
                        onOpenSettings: () => ref.read(deviceLocationSourceProvider).openSettings(),
                      ),
                    ),
                  if (!offline)
                    TrackingBanner(
                      status: trackingStatus,
                      onRetry: _startTracking,
                      onAllow: _allowLocation,
                      onOpenSettings: () => ref.read(locationTrackerProvider.notifier).openSettings(),
                    ),
                  if (GeofenceBanner.messageFor(context.l10n, ref.watch(geofenceSyncProvider)) != null) ...[
                    const SizedBox(height: 12),
                    GeofenceBanner(
                      status: ref.watch(geofenceSyncProvider),
                      onRetry: () => unawaited(ref.read(geofenceSyncProvider.notifier).retry()),
                    ),
                  ],
                  if (myAlert case final alert?) ...[
                    const SizedBox(height: 12),
                    _OwnSosBanner(
                      onResolve: () async {
                        await ref.read(sosRepositoryProvider).resolve(alert.id);
                        if (context.mounted) _snack(context.l10n.mapSosResolved);
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
              message: context.l10n.mapFamilyLoadFailed,
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
