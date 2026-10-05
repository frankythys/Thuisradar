import 'package:flutter/material.dart';

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

class DrivingSummary extends StatelessWidget {
  const DrivingSummary({super.key, required this.reports});
  final List<MemberDrivingReport> reports;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final trips = reports.fold(0, (sum, r) => sum + r.report.trips.length);
    final km = reports.fold(0.0, (sum, r) => sum + r.report.kilometers);
    final ranked = reports.where((r) => r.report.topSpeed != null).toList()
      ..sort((a, b) => b.report.topSpeed!.compareTo(a.report.topSpeed!));
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text('Wekelijks rijveiligheidsoverzicht', style: text.headlineSmall, textAlign: TextAlign.center),
        SizedBox(height: tokens.spaceLg),
        Wrap(
          spacing: tokens.spaceSm,
          runSpacing: tokens.spaceSm,
          children: [
            for (final item in const [
              (Icons.speed, 'Te snel'),
              (Icons.phone_android, 'Telefoongebruik'),
              (Icons.bolt, 'Hard optrekken'),
              (Icons.front_hand_outlined, 'Hard remmen'),
            ])
              Chip(avatar: Icon(item.$1), label: Text('${item.$2} · Niet gemeten')),
          ],
        ),
        SizedBox(height: tokens.spaceMd),
        AppCard(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Hoogste gemeten snelheid', style: text.titleMedium),
              SizedBox(height: tokens.spaceSm),
              Text(
                ranked.isEmpty ? '—' : '${ranked.first.report.topSpeed!.round()} km/u',
                style: text.headlineMedium,
              ),
              if (ranked.isNotEmpty) Text(ranked.first.member.displayName),
              const Divider(),
              Text('$trips ${trips == 1 ? 'rit' : 'ritten'}', style: text.titleLarge),
              Text('${drivingNumber(km)} kilometer in totaal', style: text.bodyLarge),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceMd),
        Text(
          'Ritten en afstanden zijn GPS-schattingen. Ook fietsen, openbaar vervoer of meerijden kunnen als rit worden herkend. '
          'Bij ontbrekende metingen kunnen ritten onvolledig zijn. Rijincidenten worden nog niet gemeten.',
          style: text.bodySmall,
        ),
      ],
    );
  }
}
