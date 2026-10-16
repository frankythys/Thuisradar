import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../emergency/application/emergency_providers.dart';
import '../../../emergency/domain/emergency_contact.dart';
import '../../../../l10n/l10n.dart';

/// Eén regel onder de ontvangers: welke noodcontacten een sms krijgen en wie
/// er gebeld wordt. Zonder noodcontacten: waar je ze instelt.
class SosEmergencyLine extends ConsumerWidget {
  const SosEmergencyLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final plan = planFor(ref.watch(myEmergencyContactsProvider).value ?? const []);
    final automatic = ref.watch(emergencyAutomaticProvider).value ?? false;
    final noSim = ref.watch(emergencySimProvider).value == false;
    final String line;
    if (plan.isEmpty) {
      line = context.l10n.sosNoContacts;
    } else if (noSim) {
      line = context.l10n.sosNoSim;
    } else if (!automatic) {
      line = context.l10n.sosManualContact(plan.callTo!.name);
    } else {
      final names = context.l10n.joinNames(plan.smsTo.map((contact) => contact.name));
      line = context.l10n.sosAlsoSms(names, plan.callTo!.name);
    }
    return Text(
      line,
      style: text.bodySmall?.copyWith(color: noSim && !plan.isEmpty ? AppColors.alert : AppColors.muted),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
