import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../application/emergency_providers.dart';
import '../../../l10n/l10n.dart';

/// Of deze gsm automatisch mag sms'en en bellen, met een knop om de
/// toestemming te geven. Op iPhone kan dat niet: daar uitleg.
class EmergencyAccessTile extends ConsumerWidget {
  const EmergencyAccessTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final automatic = ref.watch(emergencyAutomaticProvider).value ?? false;
    final android = defaultTargetPlatform == TargetPlatform.android;
    final noSim = ref.watch(emergencySimProvider).value == false;
    final l10n = context.l10n;
    final String subtitle;
    if (noSim) {
      subtitle = l10n.emergencyAutoNoSim;
    } else if (automatic) {
      subtitle = l10n.emergencyAutoOn;
    } else if (android) {
      subtitle = l10n.emergencyAutoNoPermission;
    } else {
      subtitle = l10n.emergencyAutoIphone;
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          automatic && !noSim ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: automatic && !noSim ? AppColors.primary : AppColors.alert,
        ),
        title: Text(l10n.emergencyAutoTitle),
        subtitle: Text(subtitle, style: text.bodySmall?.copyWith(color: AppColors.muted)),
        trailing: automatic || !android
            ? null
            : TextButton(
                onPressed: () async {
                  await ref.read(emergencyPhoneProvider).requestAccess();
                  ref.invalidate(emergencyAutomaticProvider);
                },
                child: Text(l10n.commonAllow),
              ),
      ),
    );
  }
}
