import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:latlong2/latlong.dart';

import '../../../l10n/l10n.dart';
import '../../../shared/widgets/location_preview.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../../map/presentation/widgets/family_map.dart';
import '../application/parked_car_providers.dart';
import '../domain/parked_car.dart';
import 'parked_car_picker_screen.dart';
import 'parked_car_sheet.dart';

/// Opent het blad bij een parkeerplek en voert de gekozen actie uit. Zonder
/// [car]: je eigen (nog lege) plek. [onShowCar] zet de kaart op de auto.
Future<void> openParkedCar(
  BuildContext context,
  WidgetRef ref, {
  required String familyId,
  required ParkedCar? car,
  required ValueChanged<ParkedCar> onShowCar,
  String? ownerName,
}) async {
  final userId = ref.read(currentUserIdProvider);
  if (userId == null) return;
  final mine = car == null || car.userId == userId;
  final action = await showParkedCarSheet(context, car: car, mine: mine, ownerName: ownerName);
  if (!context.mounted || action == null) return;
  final l10n = context.l10n;
  switch (action) {
    case ParkedCarAction.navigate:
      // Te voet: op een grote parking brengt de route je tot bij de auto.
      await openDirections(context, car!.latitude, car.longitude, walking: true);
    case ParkedCarAction.show:
      onShowCar(car!);
    case ParkedCarAction.remove:
      try {
        await ref.read(parkedCarRepositoryProvider).remove(userId: userId, familyId: familyId);
        if (context.mounted) _snack(context, l10n.parkedCarRemoved);
      } on Object catch (error) {
        debugPrint('Parkeerplek verwijderen mislukt: $error');
        if (context.mounted) _snack(context, l10n.commonRemoveFailed);
      }
    case ParkedCarAction.save:
      // Zelf plaatsen: de GPS zet de auto op je huis als je al binnen bent.
      final spot = await _pickSpot(context, ref, familyId, userId, car);
      if (spot == null || !context.mounted) return;
      try {
        await ref
            .read(parkedCarRepositoryProvider)
            .save(
              userId: userId,
              familyId: familyId,
              latitude: spot.latitude,
              longitude: spot.longitude,
              parkedAt: DateTime.now(),
            );
        if (context.mounted) _snack(context, l10n.parkedCarSaved);
      } on Object catch (error) {
        debugPrint('Parkeerplek bewaren mislukt: $error');
        if (context.mounted) _snack(context, l10n.commonTryAgainSaveFailed);
      }
  }
}

/// Opent het kaartje om de auto te plaatsen, startend bij de bestaande plek,
/// een verse GPS-meting of je laatst gedeelde locatie.
Future<LatLng?> _pickSpot(
  BuildContext context,
  WidgetRef ref,
  String familyId,
  String userId,
  ParkedCar? existing,
) async {
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

void _snack(BuildContext context, String message) =>
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
