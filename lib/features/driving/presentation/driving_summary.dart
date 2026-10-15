import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../location/domain/travel_mode.dart';
import '../application/driving_providers.dart';
import '../../../core/utils/calendar.dart';
import '../../../l10n/l10n.dart';
import '../../location/presentation/trip_text.dart';

String drivingNumber(double value) => value.toStringAsFixed(1).replaceAll('.', ',');

/// "4.512" — duizendtallen met een punt, zoals in Vlaanderen.
String drivingCount(int value) =>
    value.toString().replaceAllMapped(RegExp(r'\B(?=(\d{3})+(?!\d))'), (_) => '.');

/// "4.512 stappen" of "1 stap".
String drivingSteps(int steps) => '${drivingCount(steps)} ${steps == 1 ? 'stap' : 'stappen'}';
String drivingDate(DateTime date) => '${date.day}/${date.month}';
String drivingTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

/// "79 m" voor korte stukken, anders "13,2 km".
String drivingDistance(double? meters) {
  if (meters == null) return 'afstand onbekend';
  if (meters < 1000) return '${meters.round()} m';
  return '${drivingNumber(meters / 1000)} km';
}

/// "7 uur 56 min" of "45 min".
String drivingDuration(Duration duration) {
  final hours = duration.inHours;
  final minutes = duration.inMinutes.remainder(60);
  if (hours == 0) return '$minutes min';
  return '$hours uur $minutes min';
}

const _weekdayNames = ['ma', 'di', 'wo', 'do', 'vr', 'za', 'zo'];

/// "Vandaag", "Gisteren" of "ma 6/10".
String drivingDayLabel(DateTime day, {required DateTime now}) {
  final today = DateTime(now.year, now.month, now.day);
  final target = DateTime(day.year, day.month, day.day);
  final difference = calendarDaysBetween(target, today);
  if (difference == 0) return 'Vandaag';
  if (difference == 1) return 'Gisteren';
  return '${_weekdayNames[target.weekday - 1]} ${target.day}/${target.month}';
}

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
    final count = reports.fold(0, (sum, r) => sum + r.report.of(mode).length);
    final km = reports.fold(0.0, (sum, r) => sum + r.report.kilometersOf(mode));
    final duration = reports.fold(Duration.zero, (sum, r) => sum + r.report.durationOf(mode));
    final hours = duration.inSeconds / 3600;
    final (String, String) third = switch (mode) {
      TravelMode.car => _fastest(),
      TravelMode.bike => (hours <= 0 ? '—' : '${(km / hours).round()}', 'km/u gemiddeld'),
      TravelMode.walk => switch (reports.map((r) => r.report.stepsOf(mode)).nonNulls.toList()) {
        final known when known.isNotEmpty => (drivingCount(known.fold(0, (a, b) => a + b)), 'stappen'),
        _ => (_hours(duration), 'gewandeld'),
      },
      null => (_hours(duration), 'onderweg'),
    };
    final countLabel = travelNoun(context.l10n, mode, count);
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
            child: _Tile(value: drivingNumber(km), label: 'kilometer'),
          ),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: _Tile(value: third.$1, label: third.$2),
          ),
        ],
      ),
    );
  }

  (String, String) _fastest() {
    final ranked = reports.where((r) => r.report.topSpeed != null).toList()
      ..sort((a, b) => b.report.topSpeed!.compareTo(a.report.topSpeed!));
    final fastest = ranked.firstOrNull;
    return (
      fastest == null ? '—' : '${fastest.report.topSpeed!.round()}',
      fastest == null ? 'km/u max' : 'km/u max · ${fastest.member.displayName}',
    );
  }

  /// "2u05" (uren en minuten) voor een tegel.
  static String _hours(Duration duration) =>
      '${duration.inHours}u${duration.inMinutes.remainder(60).toString().padLeft(2, '0')}';
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
