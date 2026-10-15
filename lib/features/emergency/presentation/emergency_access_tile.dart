import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../application/emergency_providers.dart';

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
    final String subtitle;
    if (noSim) {
      subtitle = 'Deze gsm heeft geen simkaart (of geen gsm-netwerk): sms en bellen werken niet';
    } else if (automatic) {
      subtitle = 'Aan · bij een SOS vertrekken de sms en de oproep vanzelf';
    } else if (android) {
      subtitle = 'Nog geen toestemming · dan opent bij een SOS enkel de berichten-app';
    } else {
      subtitle = 'Op iPhone kan een app niet zelf sms\'en of bellen; de berichten-app opent met de sms klaar';
    }
    return AppCard(
      padding: EdgeInsets.zero,
      child: ListTile(
        leading: Icon(
          automatic && !noSim ? Icons.check_circle_outline : Icons.warning_amber_rounded,
          color: automatic && !noSim ? AppColors.primary : AppColors.alert,
        ),
        title: const Text("Automatisch sms'en en bellen"),
        subtitle: Text(subtitle, style: text.bodySmall?.copyWith(color: AppColors.muted)),
        trailing: automatic || !android
            ? null
            : TextButton(
                onPressed: () async {
                  await ref.read(emergencyPhoneProvider).requestAccess();
                  ref.invalidate(emergencyAutomaticProvider);
                },
                child: const Text('Toestaan'),
              ),
      ),
    );
  }
}
