import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../location/domain/travel_mode.dart';
import '../application/driving_providers.dart';

import 'package:intl/intl.dart';

import '../../../core/utils/time_format.dart';
import '../../../l10n/l10n.dart';
import '../../location/presentation/trip_text.dart';

/// "13,2" met het decimaalteken van de taal.
String drivingNumber(AppLocalizations l10n, double value) =>
    NumberFormat('0.0', l10n.localeName).format(value);

/// "4.512" — duizendtallen zoals in de taal gebruikelijk.
String drivingCount(AppLocalizations l10n, int value) =>
    NumberFormat.decimalPattern(l10n.localeName).format(value);

/// "4.512 stappen" of "1 stap".
String drivingSteps(AppLocalizations l10n, int steps) => l10n.drivingSteps(steps, drivingCount(l10n, steps));
String drivingDate(DateTime date) => '${date.day}/${date.month}';
String drivingTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// "79 m" voor korte stukken, anders "13,2 km".
String drivingDistance(AppLocalizations l10n, double? meters) =>
    meters == null ? l10n.drivingDistanceUnknown : formatDistance(l10n, meters);

/// "7 uur 56 min" of "45 min".
String drivingDuration(AppLocalizations l10n, Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return l10n.durationMinutes(minutes);
  return l10n.drivingHoursMinutes(hours, minutes);
}

/// "Vandaag", "Gisteren" of "ma 6/10".
String drivingDayLabel(AppLocalizations l10n, DateTime day, {required DateTime now}) =>
    formatDayLabel(l10n, day, now: now);

/// Weekoverzicht in drie tegels: aantal, kilometers en een derde cijfer dat
/// past bij het vervoermiddel (hoogste snelheid met de auto, gemiddelde met
/// de fiets, tijd te voet of in totaal).
class DrivingSummary extends StatelessWidget {
  const DrivingSummary({super.key, required this.reports, this.mode = TravelMode.car});
  final List<MemberDrivingReport> reports;

  /// Null: alle verplaatsingen samen.
  final TravelMode? mode;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final count = reports.fold(0, (sum, r) => sum + r.report.of(mode).length);
    final km = reports.fold(0.0, (sum, r) => sum + r.report.kilometersOf(mode));
    final duration = reports.fold(Duration.zero, (sum, r) => sum + r.report.durationOf(mode));
    final hours = duration.inSeconds / 3600;
    final (String, String) third = switch (mode) {
      TravelMode.car => _fastest(l10n),
      TravelMode.bike => (hours <= 0 ? '—' : '${(km / hours).round()}', l10n.drivingAverageSpeed),
      TravelMode.walk => switch (reports.map((r) => r.report.stepsOf(mode)).nonNulls.toList()) {
        final known when known.isNotEmpty => (
          drivingCount(l10n, known.fold(0, (a, b) => a + b)),
          l10n.drivingStepsTile,
        ),
        _ => (_hours(l10n, duration), l10n.drivingWalked),
      },
      null => (_hours(l10n, duration), l10n.drivingOnTheMoveTile),
    };
    final countLabel = travelNoun(l10n, mode, count);
    // Even hoge tegels, ook als de naam bij de snelheid op twee regels valt.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(value: '$count', label: countLabel),
          ),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: _Tile(value: drivingNumber(l10n, km), label: l10n.drivingKilometres),
          ),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: _Tile(value: third.$1, label: third.$2),
          ),
        ],
      ),
    );
  }

  (String, String) _fastest(AppLocalizations l10n) {
    final ranked = reports.where((r) => r.report.topSpeed != null).toList()
      ..sort((a, b) => b.report.topSpeed!.compareTo(a.report.topSpeed!));
    final fastest = ranked.firstOrNull;
    return (
      fastest == null ? '—' : '${fastest.report.topSpeed!.round()}',
      fastest == null ? l10n.drivingTopSpeed : l10n.drivingTopSpeedBy(fastest.member.displayName),
    );
  }

  /// "2u05" (uren en minuten) voor een tegel.
  static String _hours(AppLocalizations l10n, Duration duration) =>
      l10n.drivingHoursShort(duration.inHours, duration.inMinutes.remainder(60).toString().padLeft(2, '0'));
}

class _Tile extends StatelessWidget {
  const _Tile({required this.value, required this.label});

  final String value;
  final String label;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(value, style: text.headlineMedium, maxLines: 1),
          Text(
            label,
            style: text.bodySmall?.copyWith(color: AppColors.muted),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
