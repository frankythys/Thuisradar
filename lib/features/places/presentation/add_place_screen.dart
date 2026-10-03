import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../../map/presentation/widgets/family_map.dart';
import '../application/places_providers.dart';
import 'place_icons.dart';

/// Scherm 14: plaats toevoegen door de kaart te verschuiven (vaste pin in het
/// midden) en de straal te kiezen. Geen adres-zoekfunctie (kosten).
class AddPlaceScreen extends ConsumerStatefulWidget {
  const AddPlaceScreen({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<AddPlaceScreen> createState() => _AddPlaceScreenState();
}

class _AddPlaceScreenState extends ConsumerState<AddPlaceScreen> {
  final _controller = MapController();
  final _name = TextEditingController();

  LatLng _center = FamilyMap.fallbackCenter;
  double _radius = 150;
  String _icon = 'home';
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    // Meteen starten op de locatie die de app al kent (via de tracker), zodat
    // de kaart direct bij de gebruiker staat — ook binnenshuis zonder verse fix.
    final myId = ref.read(currentUserIdProvider);
    final locations = ref.read(familyLocationsProvider(widget.familyId)).value ?? const [];
    for (final location in locations) {
      if (location.userId == myId) {
        _center = LatLng(location.latitude, location.longitude);
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
    super.dispose();
  }

  Future<void> _goToCurrentLocation() async {
    final position = await ref.read(deviceLocationSourceProvider).currentPosition();
    if (position != null && mounted) {
      _controller.move(LatLng(position.latitude, position.longitude), 16);
    }
  }

  Future<void> _save() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(placesRepositoryProvider)
          .create(
            familyId: widget.familyId,
            name: name,
            latitude: _center.latitude,
            longitude: _center.longitude,
            radiusMeters: _radius.round(),
            icon: _icon,
          );
      if (mounted) Navigator.of(context).pop();
    } on Exception {
      if (mounted) {
        setState(() => _busy = false);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Plaats opslaan mislukt. Mogelijk zijn er al 20.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: const BrandedAppBar(title: 'Plaats toevoegen'),
      body: Column(
        children: [
          Expanded(
            flex: 3,
            child: Stack(
              alignment: Alignment.center,
              children: [
                FlutterMap(
                  mapController: _controller,
                  options: MapOptions(
                    initialCenter: _center,
                    initialZoom: 16,
                    onPositionChanged: (camera, _) => setState(() => _center = camera.center),
                    interactionOptions: const InteractionOptions(
                      flags: InteractiveFlag.all & ~InteractiveFlag.rotate,
                    ),
                  ),
                  children: [
                    TileLayer(
                      urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: FamilyMap.userAgent,
                    ),
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
            flex: 2,
            child: Material(
              color: Colors.white,
              child: SingleChildScrollView(
                child: _Panel(
                  name: _name,
                  radius: _radius,
                  icon: _icon,
                  busy: _busy,
                  onRadius: (v) => setState(() => _radius = v),
                  onIcon: (v) => setState(() => _icon = v),
                  onSave: _save,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({
    required this.name,
    required this.radius,
    required this.icon,
    required this.busy,
    required this.onRadius,
    required this.onIcon,
    required this.onSave,
  });

  final TextEditingController name;
  final double radius;
  final String icon;
  final bool busy;
  final ValueChanged<double> onRadius;
  final ValueChanged<String> onIcon;
  final VoidCallback onSave;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return SafeArea(
      top: false,
      child: Padding(
        padding: EdgeInsets.all(tokens.spaceLg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: name,
              decoration: const InputDecoration(
                hintText: 'Naam (bv. Thuis, School)',
                prefixIcon: Icon(Icons.edit_location_alt_outlined, color: AppColors.primary),
              ),
            ),
            SizedBox(height: tokens.spaceMd),
            Wrap(
              spacing: tokens.spaceSm,
              children: [
                for (final key in placeIconKeys)
                  ChoiceChip(
                    label: Icon(placeIcon(key), size: 20, color: key == icon ? Colors.white : AppColors.ink),
                    selected: key == icon,
                    showCheckmark: false,
                    selectedColor: AppColors.primary,
                    onSelected: (_) => onIcon(key),
                  ),
              ],
            ),
            SizedBox(height: tokens.spaceSm),
            Row(
              children: [
                Text('Straal', style: text.titleMedium),
                const Spacer(),
                Text('${radius.round()} m', style: text.titleMedium?.copyWith(color: AppColors.primary)),
              ],
            ),
            Slider(value: radius, min: 50, max: 500, divisions: 45, onChanged: onRadius),
            SizedBox(height: tokens.spaceSm),
            FilledButton(
              onPressed: busy ? null : onSave,
              child: busy
                  ? const SizedBox.square(
                      dimension: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                    )
                  : const Text('Plaats opslaan'),
            ),
          ],
        ),
      ),
    );
  }
}
