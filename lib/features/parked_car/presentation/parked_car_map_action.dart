import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../l10n/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../../map/presentation/widgets/family_map.dart';
import '../application/parked_car_providers.dart';
import '../domain/parked_car.dart';
import 'parked_car_picker_screen.dart';

class ParkedCarMapAction extends ConsumerWidget {
  const ParkedCarMapAction({
    super.key,
    required this.familyId,
    required this.parkedCars,
    required this.onShowCar,
  });

  final String familyId;
  final List<ParkedCar> parkedCars;
  final ValueChanged<ParkedCar> onShowCar;

  @override
  Widget build(BuildContext context, WidgetRef ref) => Material(
    color: Theme.of(context).colorScheme.surface,
    // Blauwe rand in de kleur van de app, zoals de andere kaartknoppen.
    shape: CircleBorder(
      side: BorderSide(color: Theme.of(context).colorScheme.primary, width: context.tokens.spaceXs / 2),
    ),
    elevation: 3,
    shadowColor: Theme.of(context).colorScheme.shadow,
    child: InkWell(
      onTap: () => _manage(context, ref),
      customBorder: const CircleBorder(),
      child: Tooltip(
        message: context.l10n.parkedCarTitle,
        child: SizedBox(
          width: context.tokens.spaceXxl + context.tokens.spaceSm,
          height: context.tokens.spaceXxl + context.tokens.spaceSm,
          child: Icon(
            Icons.directions_car,
            color: Theme.of(context).colorScheme.primary,
            size: context.tokens.spaceMd + context.tokens.spaceSm,
          ),
        ),
      ),
    ),
  );

  Future<void> _manage(BuildContext context, WidgetRef ref) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final existing = parkedCars.where((car) => car.userId == userId).firstOrNull;
    final l10n = context.l10n;
    final action = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(l10n.parkedCarTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.parkedCarInfo),
            if (existing != null) ...[
              SizedBox(height: context.tokens.spaceSm),
              Text(l10n.parkedCarLastSaved(formatRelative(l10n, existing.parkedAt, now: DateTime.now()))),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: Text(l10n.commonCancel)),
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'show'),
              child: Text(l10n.parkedCarShowAction),
            ),
          if (existing != null)
            TextButton(
              onPressed: () => Navigator.pop(context, 'remove'),
              child: Text(l10n.parkedCarDeleteAction),
            ),
          FilledButton(
            onPressed: () => Navigator.pop(context, 'save'),
            child: Text(existing == null ? l10n.parkedCarSaveAction : l10n.parkedCarUpdateAction),
          ),
        ],
      ),
    );
    if (!context.mounted || action == null) return;
    if (action == 'show') {
      onShowCar(existing!);
      return;
    }

    try {
      final repository = ref.read(parkedCarRepositoryProvider);
      if (action == 'remove') {
        await repository.remove(userId: userId, familyId: familyId);
        if (context.mounted) _showSnack(context, l10n.parkedCarRemoved);
        return;
      }

      // Zelf plaatsen: de GPS zet de auto op je huis als je al binnen bent.
      final spot = await _pickSpot(context, ref, userId, existing);
      if (spot == null || !context.mounted) return;
      await repository.save(
        userId: userId,
        familyId: familyId,
        latitude: spot.latitude,
        longitude: spot.longitude,
        parkedAt: DateTime.now(),
      );
      if (context.mounted) _showSnack(context, l10n.parkedCarSaved);
    } on Object catch (error) {
      debugPrint('Parkeerplek bewaren mislukt: $error');
      if (context.mounted) {
        _showSnack(context, action == 'remove' ? l10n.commonRemoveFailed : l10n.commonTryAgainSaveFailed);
      }
    }
  }

  /// Opent het kaartje om de auto te plaatsen, startend bij de bestaande plek,
  /// een verse GPS-meting of je laatst gedeelde locatie.
  Future<LatLng?> _pickSpot(BuildContext context, WidgetRef ref, String userId, ParkedCar? existing) async {
    final fresh = existing == null
        ? await ref.read(deviceLocationSourceProvider).currentPosition(timeout: const Duration(seconds: 4))
        : null;
    final shared = (ref.read(familyLocationsProvider(familyId)).value ?? const [])
        .where((location) => location.userId == userId)
        .firstOrNull;
    final start = parkedCarStartPoint(
      existing: existing,
      fresh: fresh == null ? null : (latitude: fresh.latitude, longitude: fresh.longitude),
      lastShared: shared == null ? null : (latitude: shared.latitude, longitude: shared.longitude),
    );
    if (!context.mounted) return null;
    return Navigator.of(context).push<LatLng>(
      MaterialPageRoute(
        builder: (_) => ParkedCarPickerScreen(
          initialCenter: start == null ? FamilyMap.fallbackCenter : LatLng(start.latitude, start.longitude),
        ),
      ),
    );
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
