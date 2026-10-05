import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../application/driving_providers.dart';

String drivingNumber(double value) => value.toStringAsFixed(1).replaceAll('.', ',');
String drivingDate(DateTime date) => '${date.day}/${date.month}';
String drivingTime(DateTime date) =>
    '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';

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
