import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../location/application/tracking_status.dart';

/// Waarschuwing bovenaan wanneer je eigen locatie niet gedeeld wordt.
class TrackingBanner extends StatelessWidget {
  const TrackingBanner({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onOpenSettings,
  });

  final TrackingStatus status;
  final VoidCallback onRetry;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final (message, action) = switch (status) {
      TrackingStatus.permissionDenied => ('Geef toestemming voor je locatie.', ('Toestaan', onRetry)),
      TrackingStatus.permissionDeniedForever => (
        'Locatie is geblokkeerd. Zet het aan in de instellingen.',
        ('Instellingen', onOpenSettings),
      ),
      TrackingStatus.serviceDisabled => ('Zet locatie (GPS) aan op je telefoon.', ('Opnieuw', onRetry)),
      TrackingStatus.offline => ('Geen verbinding. Je locatie wordt later bijgewerkt.', null),
      TrackingStatus.error => ('Je locatie kon niet gelezen worden.', ('Opnieuw', onRetry)),
      _ => (null, null),
    };
    if (message == null) return const SizedBox.shrink();

    return Material(
      color: const Color(0xFFFDF3EE),
      elevation: 2,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            const Icon(Icons.location_off_outlined, color: AppColors.alert),
            const SizedBox(width: 12),
            Expanded(child: Text(message)),
            if (action != null) TextButton(onPressed: action.$2, child: Text(action.$1)),
          ],
        ),
      ),
    );
  }
}
