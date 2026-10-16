import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/config/feature_flags.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../places/presentation/place_crosshair.dart';
import '../../places/presentation/place_edit_map.dart';

/// De auto zelf op de kaart zetten, zoals bij een plaats: je sleept de kaart
/// tot het kruis op de straat of parking staat. De GPS zet je auto anders op
/// je huis als je net binnen bent. Geeft het gekozen punt terug, of null.
class ParkedCarPickerScreen extends StatefulWidget {
  const ParkedCarPickerScreen({
    super.key,
    required this.initialCenter,
    this.useGoogleMaps = FeatureFlags.useGoogleMaps,
  });

  final LatLng initialCenter;
  final bool useGoogleMaps;

  @override
  State<ParkedCarPickerScreen> createState() => _ParkedCarPickerScreenState();
}

class _ParkedCarPickerScreenState extends State<ParkedCarPickerScreen> {
  final _controller = MapController();
  late LatLng _center = widget.initialCenter;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final tokens = context.tokens;
    final colors = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: BrandedAppBar(title: l10n.parkedCarTitle),
      body: Stack(
        alignment: Alignment.center,
        children: [
          PlaceEditMap(
            controller: _controller,
            center: _center,
            radiusMeters: 0,
            initialZoom: PlaceEditMap.maxZoomFor(google: widget.useGoogleMaps) - 1,
            useGoogleMaps: widget.useGoogleMaps,
            onPositionChanged: (camera, _) => setState(() => _center = camera.center),
          ),
          // Het midden van het kruis is het punt dat bewaard wordt.
          const PlaceCrosshair(),
          Positioned(
            top: tokens.spaceMd,
            left: tokens.spaceMd,
            right: tokens.spaceMd,
            child: Material(
              color: colors.surface,
              elevation: 2,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
              child: Padding(
                padding: EdgeInsets.all(tokens.spaceSm + tokens.spaceXs),
                child: Row(
                  children: [
                    Icon(Icons.directions_car, color: colors.primary),
                    SizedBox(width: tokens.spaceSm),
                    Expanded(child: Text(l10n.parkedCarPickHint)),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Row(
            children: [
              TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
              SizedBox(width: tokens.spaceSm),
              Expanded(
                child: FilledButton.icon(
                  onPressed: () => Navigator.pop(context, _center),
                  icon: const Icon(Icons.check),
                  label: Text(l10n.parkedCarSaveAction),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
