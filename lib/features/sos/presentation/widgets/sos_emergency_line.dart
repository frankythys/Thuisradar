import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../emergency/application/emergency_providers.dart';
import '../../../emergency/domain/emergency_contact.dart';

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
      line = 'Nog geen noodcontacten · instellen via Profiel';
    } else if (noSim) {
      line = 'Deze gsm heeft geen simkaart: geen sms of oproep naar je noodcontacten';
    } else if (!automatic) {
      line = 'Noodcontact ${plan.callTo!.name}: de sms staat klaar, zelf versturen';
    } else {
      final names = plan.smsTo.map((contact) => contact.name).join(' en ');
      line = 'Ook een sms naar $names · daarna bellen naar ${plan.callTo!.name}';
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
