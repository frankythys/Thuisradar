import 'package:flutter/material.dart';

import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../location/domain/member_location.dart';
import '../../../../l10n/l10n.dart';

/// Kop van het ontvangen alarm, in de alarmkleur van het thema, met een
/// kruisje rechtsboven.
class SosReceivedHeader extends StatelessWidget {
  const SosReceivedHeader({
    super.key,
    required this.name,
    required this.createdAt,
    required this.location,
    required this.now,
    required this.onClose,
  });

  final String name;
  final DateTime createdAt;
  final MemberLocation? location;
  final DateTime now;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;
    final battery = location?.battery;
    final details = [
      context.l10n.sosAt(formatClock(createdAt)),
      if (battery != null) context.l10n.sosBattery(battery),
    ].join(' · ');

    return Container(
      padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceMd, tokens.spaceXs, tokens.spaceMd),
      decoration: BoxDecoration(
        color: scheme.errorContainer,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: scheme.error),
                    SizedBox(width: tokens.spaceXs),
                    Text(
                      context.l10n.sosEmergencyAlarm,
                      style: text.labelSmall?.copyWith(color: scheme.error),
                    ),
                  ],
                ),
                SizedBox(height: tokens.spaceXs),
                Text(
                  context.l10n.sosNeedsHelp(name),
                  style: text.headlineMedium?.copyWith(color: scheme.error),
                ),
                SizedBox(height: tokens.spaceXs),
                Text(details, style: text.bodySmall?.copyWith(color: scheme.onErrorContainer)),
              ],
            ),
          ),
          IconButton(
            tooltip: context.l10n.commonClose,
            onPressed: onClose,
            icon: Icon(Icons.close, color: scheme.onErrorContainer),
          ),
        ],
      ),
    );
  }
}
