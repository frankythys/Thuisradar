import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../domain/parked_car.dart';
import 'parked_car_flow.dart';

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
    final mine = parkedCars.where((car) => car.userId == userId).firstOrNull;
    await openParkedCar(context, ref, familyId: familyId, car: mine, onShowCar: onShowCar);
  }
}
