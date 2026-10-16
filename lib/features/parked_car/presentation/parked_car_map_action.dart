import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../../../l10n/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../application/parked_car_providers.dart';
import '../domain/parked_car.dart';

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
    shape: const CircleBorder(),
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

      final position = await ref.read(deviceLocationSourceProvider).currentPosition();
      final now = DateTime.now();
      final age = position == null ? null : now.difference(position.timestamp).abs();
      if (position == null ||
          age == null ||
          age > const Duration(minutes: 2) ||
          (position.accuracyMeters != null && position.accuracyMeters! > 100)) {
        if (context.mounted) _showSnack(context, l10n.parkedCarNoLocation);
        return;
      }
      await repository.save(
        userId: userId,
        familyId: familyId,
        latitude: position.latitude,
        longitude: position.longitude,
        parkedAt: position.timestamp,
      );
      if (context.mounted) _showSnack(context, l10n.parkedCarSaved);
    } on Object catch (error) {
      debugPrint('Parkeerplek bewaren mislukt: $error');
      if (context.mounted) {
        _showSnack(context, action == 'remove' ? l10n.commonRemoveFailed : l10n.commonTryAgainSaveFailed);
      }
    }
  }

  void _showSnack(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }
}
