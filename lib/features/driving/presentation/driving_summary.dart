import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../application/driving_providers.dart';

String drivingNumber(double value) => value.toStringAsFixed(1).replaceAll('.', ',');
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
  final difference = today.difference(target).inDays;
  if (difference == 0) return 'Vandaag';
  if (difference == 1) return 'Gisteren';
  return '${_weekdayNames[target.weekday - 1]} ${target.day}/${target.month}';
}

/// Weekoverzicht in drie tegels: ritten, kilometers en hoogste snelheid.
class DrivingSummary extends StatelessWidget {
  const DrivingSummary({super.key, required this.reports});
  final List<MemberDrivingReport> reports;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final trips = reports.fold(0, (sum, r) => sum + r.report.trips.length);
    final km = reports.fold(0.0, (sum, r) => sum + r.report.kilometers);
    final ranked = reports.where((r) => r.report.topSpeed != null).toList()
      ..sort((a, b) => b.report.topSpeed!.compareTo(a.report.topSpeed!));
    final fastest = ranked.firstOrNull;
    // Even hoge tegels, ook als de naam bij de snelheid op twee regels valt.
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: _Tile(value: '$trips', label: trips == 1 ? 'rit' : 'ritten'),
          ),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: _Tile(value: drivingNumber(km), label: 'kilometer'),
          ),
          SizedBox(width: tokens.spaceSm),
          Expanded(
            child: _Tile(
              value: fastest == null ? '—' : '${fastest.report.topSpeed!.round()}',
              label: fastest == null ? 'km/u max' : 'km/u max · ${fastest.member.displayName}',
            ),
          ),
        ],
      ),
    );
  }
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
