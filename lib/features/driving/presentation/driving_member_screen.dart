import 'package:flutter/material.dart';

import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../application/driving_providers.dart';
import '../domain/driving_report.dart';
import 'driving_summary.dart';

class DrivingMemberScreen extends StatelessWidget {
  const DrivingMemberScreen({super.key, required this.data, required this.week});
  final MemberDrivingReport data;
  final DateTime week;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    return Scaffold(
      appBar: BrandedAppBar(title: data.member.displayName),
      body: ListView(
        padding: EdgeInsets.all(tokens.spaceMd),
        children: [
          Text(
            '${drivingDate(week)} – ${drivingDate(DateTime(week.year, week.month, week.day + 6))}',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          SizedBox(height: tokens.spaceMd),
          DrivingSummary(reports: [data]),
          SizedBox(height: tokens.spaceLg),
          Text('Ritten deze week', style: Theme.of(context).textTheme.titleLarge),
          SizedBox(height: tokens.spaceMd),
          if (data.report.trips.isEmpty)
            Text(
              data.report.hasHistory
                  ? 'Nog geen ritten herkend in deze week.'
                  : 'Geen locatiegeschiedenis voor deze week.',
            ),
          for (final trip in data.report.trips.reversed) ...[
            _TripCard(trip: trip),
            SizedBox(height: tokens.spaceMd),
          ],
        ],
      ),
    );
  }
}

class _TripCard extends StatelessWidget {
  const _TripCard({required this.trip});
  final DrivingTrip trip;

  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '${drivingDate(trip.start)} · ${drivingTime(trip.start)} – ${drivingTime(trip.end)}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SizedBox(height: context.tokens.spaceSm),
        Text('${drivingNumber(trip.kilometers)} km · ${trip.end.difference(trip.start).inMinutes} min'),
        Text('Hoogste snelheid: ${trip.topSpeed.round()} km/u'),
      ],
    ),
  );
}
