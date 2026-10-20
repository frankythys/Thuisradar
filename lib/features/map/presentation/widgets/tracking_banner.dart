import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../location/application/tracking_status.dart';
import '../../../../l10n/l10n.dart';

/// Waarschuwing bovenaan wanneer je eigen locatie niet gedeeld wordt.
class TrackingBanner extends StatelessWidget {
  const TrackingBanner({
    super.key,
    required this.status,
    required this.onRetry,
    required this.onAllow,
    required this.onOpenSettings,
  });

  final TrackingStatus status;
  final VoidCallback onRetry;

  /// Toestemming vragen: eerst de uitleg, dan de Android-vraag.
  final VoidCallback onAllow;
  final VoidCallback onOpenSettings;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final (message, action) = switch (status) {
      TrackingStatus.permissionDenied => (l10n.mapTrackingPermission, (l10n.commonAllow, onAllow)),
      TrackingStatus.permissionDeniedForever => (
        l10n.mapTrackingBlocked,
        (l10n.commonSettings, onOpenSettings),
      ),
      TrackingStatus.serviceDisabled => (l10n.mapTrackingGpsOff, (l10n.commonAgain, onRetry)),
      TrackingStatus.offline => (l10n.mapTrackingOffline, (l10n.commonTryAgain, onRetry)),
      TrackingStatus.error => (l10n.mapTrackingError, (l10n.commonAgain, onRetry)),
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
