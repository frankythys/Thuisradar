import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../emergency/application/emergency_providers.dart';
import '../../../emergency/domain/emergency_contact.dart';
import '../../../../l10n/l10n.dart';

/// Eén regel onder de ontvangers: voor welk noodcontact de sms klaarstaat.
/// Zonder noodcontacten: waar je ze instelt.
class SosEmergencyLine extends ConsumerWidget {
  const SosEmergencyLine({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final plan = planFor(ref.watch(myEmergencyContactsProvider).value ?? const []);
    final line = plan.isEmpty ? context.l10n.sosNoContacts : context.l10n.sosManualContact(plan.callTo!.name);
    return Text(
      line,
      style: text.bodySmall?.copyWith(color: AppColors.muted),
      textAlign: TextAlign.center,
      maxLines: 2,
      overflow: TextOverflow.ellipsis,
    );
  }
}
