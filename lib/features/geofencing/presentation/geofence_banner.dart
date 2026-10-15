import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../application/geofence_status.dart';
import '../../../l10n/l10n.dart';

/// Melding op de kaart wanneer Android de zones (aankomst/vertrek met de app
/// dicht) niet bewaakt. Toestemming "Altijd toestaan" valt hier buiten.
class GeofenceBanner extends StatelessWidget {
  const GeofenceBanner({super.key, required this.status, required this.onRetry});

  final GeofenceStatus status;
  final VoidCallback onRetry;

  /// Tekst per stand; null = niets tonen.
  static String? messageFor(AppLocalizations l10n, GeofenceStatus status) => switch (status) {
    GeofenceStatus.unavailable => l10n.geofenceUnavailable,
    GeofenceStatus.error => l10n.geofenceError,
    GeofenceStatus.notConfigured => l10n.geofenceNotConfigured,
    GeofenceStatus.idle || GeofenceStatus.active || GeofenceStatus.permissionMissing => null,
  };

  @override
  Widget build(BuildContext context) {
    final message = messageFor(context.l10n, status);
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
            TextButton(onPressed: onRetry, child: Text(context.l10n.commonAgain)),
          ],
        ),
      ),
    );
  }
}
