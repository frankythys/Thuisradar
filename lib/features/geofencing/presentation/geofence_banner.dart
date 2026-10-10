import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../application/geofence_status.dart';

/// Melding op de kaart wanneer Android de zones (aankomst/vertrek met de app
/// dicht) niet bewaakt. Toestemming "Altijd toestaan" valt hier buiten.
class GeofenceBanner extends StatelessWidget {
  const GeofenceBanner({super.key, required this.status, required this.onRetry});

  final GeofenceStatus status;
  final VoidCallback onRetry;

  /// Tekst per stand; null = niets tonen.
  static String? messageFor(GeofenceStatus status) => switch (status) {
    GeofenceStatus.unavailable =>
      'Zones staan uit: zet "Google-locatienauwkeurigheid" aan '
          '(Instellingen › Locatie › Locatieservices).',
    GeofenceStatus.error => 'Zones staan niet aan bij Android. Aankomst en vertrek kunnen later komen.',
    GeofenceStatus.notConfigured => 'Zones zijn nog niet ingesteld op de server (migratie 014).',
    GeofenceStatus.idle || GeofenceStatus.active || GeofenceStatus.permissionMissing => null,
  };

  @override
  Widget build(BuildContext context) {
    final message = messageFor(status);
    if (message == null) return const SizedBox.shrink();
    return Material(
      color: AppColors.alertSoft,
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.wrong_location_outlined, color: AppColors.alert),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            TextButton(onPressed: onRetry, child: const Text('Opnieuw')),
          ],
        ),
      ),
    );
  }
}
