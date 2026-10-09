import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';
import 'package:geocoding/geocoding.dart';

import '../../family/application/family_providers.dart';
import '../../family/domain/family_member.dart';
import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/app_map_tiles.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../../map/presentation/widgets/family_map.dart';
import '../application/places_providers.dart';
import 'place_icons.dart';
import '../domain/place.dart';
import '../domain/selected_place_location.dart';

/// Scherm 14: plaats toevoegen door de kaart te verschuiven (vaste pin in het
/// midden), een adres te zoeken en de meldingen per gezinslid in te stellen.
class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key, required this.familyId, this.initialLocation, this.place});
  final String familyId;

  /// Te bewerken plaats; null = nieuwe plaats toevoegen.
  final Place? place;

  /// Start op deze plek (bv. waar een gezinslid nu staat) i.p.v. op je eigen
  /// locatie.
  final LatLng? initialLocation;
  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final _controller = MapController();
  final _name = TextEditingController();
  final _search = TextEditingController();
  final _watchedMembers = <String>{};
  bool _arrival = true;
  bool _departure = true;
  bool _searching = false;
  final _selection = SelectedPlaceLocation(FamilyMap.fallbackCenter);
  LatLng get _center => _selection.center;
  double _radius = 150;
  String _icon = 'home';
  bool _busy = false;
  bool get _editing => widget.place != null;

  @override
  void initState() {
    super.initState();
    if (widget.place case final place?) {
      final at = LatLng(place.latitude, place.longitude);
      _name.text = place.name;
      _radius = place.radiusMeters.toDouble().clamp(50, 500);
      _icon = place.icon;
      _watchedMembers.addAll(place.watchedMembers ?? const []);
      _arrival = place.notifyArrival;
      _departure = place.notifyDeparture;
      _selection.resolve(_selection.beginSearch(), at, place.address ?? '');
      if (place.address case final address?) _search.text = address;
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.move(at, 16));
      return;
    }
    // Meteen starten op de locatie die de app al kent (via de tracker), zodat
    // de kaart direct bij de gebruiker staat â€” ook binnenshuis zonder verse fix.
    final initial = widget.initialLocation;
    if (initial != null) {
      _selection.move(initial, userGesture: false);
      WidgetsBinding.instance.addPostFrameCallback((_) => _controller.move(initial, 17));
      return;
    }
    final myId = ref.read(currentUserIdProvider);
    final locations = ref.read(familyLocationsProvider(widget.familyId)).value ?? const [];
    for (final location in locations) {
      if (location.userId == myId) {
        _selection.move(LatLng(location.latitude, location.longitude), userGesture: false);
      }
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_center != FamilyMap.fallbackCenter) {
        _controller.move(_center, 16);
      }
      _goToCurrentLocation();
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _name.dispose();
    _search.dispose();
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    final revision = _selection.beginSearch();
    final position = await ref.read(deviceLocationSourceProvider).currentPosition();
    if (position != null &&
        mounted &&
        _selection.resolve(revision, LatLng(position.latitude, position.longitude), '')) {
      _selection.move(LatLng(position.latitude, position.longitude), userGesture: true);
      _search.clear();
      _controller.move(_center, 16);
    }
  }

  Future<void> _findAddress() async {
    if (_search.text.trim().isEmpty || _searching) return;
    FocusScope.of(context).unfocus();
    final query = _search.text.trim();
    final revision = _selection.beginSearch();
    setState(() => _searching = true);
    try {
      final matches = await Geocoding().locationFromAddress(query);
      if (mounted && matches.isEmpty) {
        throw const FormatException('Adres niet gevonden');
      }
      if (mounted &&
          matches.isNotEmpty &&
          _selection.resolve(revision, LatLng(matches.first.latitude, matches.first.longitude), query)) {
        _controller.move(LatLng(matches.first.latitude, matches.first.longitude), 16);
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Adres niet gevonden. Verschuif de kaart of probeer een ander adres.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (_busy || _searching) return;
    if (name.isEmpty) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Vul eerst een naam voor de plaats in.')));
      return;
    }
    // Adres getypt maar nog niet gezocht (bv. huisnummer 34 -> 36): eerst
    // opzoeken, anders zou de oude locatie bewaard worden.
    if (_search.text.trim().isNotEmpty && _selection.address == null) {
      await _findAddress();
      if (!mounted || _selection.address == null) return;
    }
    setState(() => _busy = true);
    final center = _center;
    final radius = _radius.round();
    final icon = _icon;
    final watchedMembers = _watchedMembers.toList();
    final arrival = _arrival;
    final departure = _departure;
    var address = _selection.address?.trim();
    final repository = ref.read(placesRepositoryProvider);
    try {
      if (address == null || address.isEmpty) {
        try {
          final marks = await Geocoding()
              .placemarkFromCoordinates(center.latitude, center.longitude)
              .timeout(const Duration(seconds: 3));
          if (marks.isNotEmpty) {
            final mark = marks.first;
            address = [
              mark.street,
              mark.postalCode,
              mark.locality,
            ].whereType<String>().map((part) => part.trim()).where((part) => part.isNotEmpty).join(', ');
          }
        } catch (_) {
          // Een ontbrekend adres mag het opslaan van de locatie niet blokkeren.
        }
      }
      if (!mounted) return;
      final saved = address == null || address.isEmpty ? null : address;
      if (widget.place case final place?) {
        await repository.update(
          id: place.id,
          name: name,
          latitude: center.latitude,
          longitude: center.longitude,
          radiusMeters: radius,
          icon: icon,
          address: saved,
          watchedMembers: watchedMembers,
          notifyArrival: arrival,
          notifyDeparture: departure,
        );
        ref.invalidate(familyPlacesProvider(widget.familyId));
      } else {
        await repository.create(
          familyId: widget.familyId,
          name: name,
          latitude: center.latitude,
          longitude: center.longitude,
          radiusMeters: radius,
          icon: icon,
          address: address == null || address.isEmpty ? null : address,
          watchedMembers: watchedMembers,
          notifyArrival: arrival,
          notifyDeparture: departure,
        );
      }
      if (mounted) {
        final messenger = ScaffoldMessenger.of(context);
        Navigator.of(context).pop();
        messenger
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              behavior: SnackBarBehavior.floating,
              duration: const Duration(seconds: 5),
              content: Text(
                address != null && address.isNotEmpty
                    ? '$name ${_editing ? 'bijgewerkt' : 'opgeslagen'}\n$address'
                    : '$name ${_editing ? 'bijgewerkt' : 'opgeslagen'} — adres niet beschikbaar',
              ),
            ),
          );
      }
    } on Exception {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              _editing
                  ? 'Wijzigingen opslaan mislukt. Probeer opnieuw.'
                  : 'Plaats opslaan mislukt. Mogelijk zijn er al 20.',
            ),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(title: _editing ? 'Plaats bewerken' : 'Plaats toevoegen'),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              TextButton(
                onPressed: _busy ? null : () => Navigator.pop(context),
                child: const Text('Annuleren'),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  onPressed: _busy || _searching ? null : _save,
                  icon: const Icon(Icons.check, size: 18),
                  label: Text(
                    _busy
                        ? 'Opslaan…'
                        : _editing
                        ? 'Wijzigingen opslaan'
                        : 'Plaats opslaan',
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            flex: 6,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16,
                    minZoom: 3,
                    maxZoom: 18,
                    cameraConstraint: CameraConstraint.contain(
                      bounds: LatLngBounds(const LatLng(-85, -180), const LatLng(85, 180)),
                    ),
                    onPositionChanged: (camera, gesture) => setState(() {
                      _selection.move(camera.center, userGesture: gesture);
                      if (gesture) _search.clear();
                    }),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    const AppMapTiles(),
                    CircleLayer(
                      circles: [
                        CircleMarker(
                          point: _center,
                          radius: _radius,
                          useRadiusInMeter: true,
                          color: AppColors.primary.withValues(alpha: 0.12),
                          borderColor: AppColors.primary,
                          borderStrokeWidth: 2,
                        ),
                      ],
                    ),
                  ],
                ),
                Positioned(
                  top: 12,
                  left: 16,
                  right: 16,
                  child: TextField(
                    controller: _search,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _findAddress(),
                    onChanged: (_) => _selection.editAddress(),
                    decoration: InputDecoration(
                      hintText: 'Zoek een adres of plaats',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        onPressed: _searching ? null : _findAddress,
                        icon: const Icon(Icons.arrow_forward),
                      ),
                    ),
                  ),
                ),
                Positioned(
                  bottom: 12,
                  left: 16,
                  child: Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(20)),
                    child: const Text(
                      'Sleep de kaart om de positie te wijzigen',
                      style: TextStyle(fontSize: 10),
                    ),
                  ),
                ),
                // Vaste pin in het midden.
                Padding(
                  padding: const EdgeInsets.only(bottom: 36),
                  child: Icon(placeIcon(_icon), color: AppColors.primary, size: 40),
                ),
                const Icon(Icons.circle, size: 8, color: AppColors.primary),
                Positioned(
                  right: 16,
                  bottom: 16,
                  child: Material(
                    color: Colors.white,
                    shape: const CircleBorder(),
                    elevation: 3,
                    shadowColor: const Color(0x33121C1C),
                    child: InkWell(
                      onTap: _goToCurrentLocation,
                      customBorder: const CircleBorder(),
                      child: const Tooltip(
                        message: 'Mijn locatie',
                        child: SizedBox(
                          width: 48,
                          height: 48,
                          child: Icon(Icons.my_location, color: AppColors.primary),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            flex: 4,
            child: SingleChildScrollView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.radar, size: 20, color: AppColors.primary),
                        const SizedBox(width: 8),
                        Text('Straalzone', style: Theme.of(context).textTheme.titleMedium),
                        const Spacer(),
                        Text('${_radius.round()} meter'),
                      ],
                    ),
                    Slider(
                      value: _radius,
                      min: 50,
                      max: 500,
                      divisions: 45,
                      onChanged: (value) => setState(() => _radius = value),
                    ),
                    const Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [Text('50 m (compact)'), Text('500 m (ruim)')],
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Meldingen worden verzonden zodra iemand deze cirkel binnenrijdt of verlaat.',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 24),
                    Text('Naam van de plaats', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    TextField(
                      controller: _name,
                      decoration: const InputDecoration(hintText: 'Thuis', fillColor: AppColors.surfaceLow),
                    ),
                    const SizedBox(height: 24),
                    Text('Kies een herkenbaar icoon', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        for (final key in placeIconKeys)
                          ChoiceChip(
                            showCheckmark: false,
                            selected: _icon == key,
                            selectedColor: AppColors.primary,
                            onSelected: (_) => setState(() => _icon = key),
                            label: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(placeIcon(key), color: _icon == key ? Colors.white : AppColors.primary),
                                Text(
                                  placeIconLabel(key),
                                  style: TextStyle(
                                    fontSize: 10,
                                    color: _icon == key ? Colors.white : AppColors.primary,
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Voor wie gelden meldingen?', style: Theme.of(context).textTheme.titleMedium),
                    const Text(
                      'Kies welke gezinsleden meldingen activeren',
                      style: TextStyle(fontSize: 12, color: AppColors.muted),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 8,
                      children: [
                        FilterChip(
                          label: const Text('Iedereen'),
                          selected: _watchedMembers.isEmpty,
                          onSelected: (_) => setState(_watchedMembers.clear),
                        ),
                        for (final member
                            in ref.watch(familyMembersProvider(widget.familyId)).value ??
                                const <FamilyMember>[])
                          FilterChip(
                            label: Text(member.displayName),
                            selected: _watchedMembers.contains(member.userId),
                            onSelected: (selected) => setState(
                              () => selected
                                  ? _watchedMembers.add(member.userId)
                                  : _watchedMembers.remove(member.userId),
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text('Meldingsvoorkeuren', style: Theme.of(context).textTheme.titleMedium),
                    const SizedBox(height: 8),
                    SwitchListTile(
                      tileColor: AppColors.surfaceLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      secondary: const Icon(Icons.login, color: AppColors.primary),
                      title: const Text('Melding bij aankomst'),
                      subtitle: const Text('Wanneer iemand de cirkel binnenkomt'),
                      value: _arrival,
                      onChanged: (v) => setState(() => _arrival = v),
                    ),
                    const SizedBox(height: 12),
                    SwitchListTile(
                      tileColor: AppColors.surfaceLow,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                      secondary: const Icon(Icons.logout, color: AppColors.primary),
                      title: const Text('Melding bij vertrek'),
                      subtitle: const Text('Wanneer iemand de cirkel verlaat'),
                      value: _departure,
                      onChanged: (v) => setState(() => _departure = v),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
