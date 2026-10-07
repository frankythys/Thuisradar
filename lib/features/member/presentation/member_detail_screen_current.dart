part of 'member_detail_screen.dart';

/// Life360-stijl kaart met de huidige, nog lopende status: waar het lid nu is,
/// sinds hoe laat (de eindtijd loopt mee tot nu), en een knop om de
/// geschiedenis te verversen — want die wordt niet automatisch bijgehouden.
class _CurrentStayCard extends ConsumerWidget {
  const _CurrentStayCard({
    required this.location,
    required this.entries,
    required this.places,
    required this.now,
    required this.onRefresh,
  });

  final MemberLocation location;
  final List<TimelineEntry> entries;
  final List<Place> places;
  final DateTime now;
  final VoidCallback onRefresh;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final moving = TripStatus.at(location, now).speedKmh != null;

    Place? here;
    for (final place in places) {
      if (distanceMeters(location.latitude, location.longitude, place.latitude, place.longitude) <=
          place.radiusMeters) {
        here = place;
        break;
      }
    }

    // Begin van de lopende stop: de laatste stop in de tijdlijn van vandaag.
    DateTime? since;
    for (final entry in entries) {
      if (entry.kind == TimelineKind.stop) since = entry.start;
    }
    final ongoing = !moving && since != null;

    final String title;
    final IconData icon;
    if (moving) {
      title = 'Onderweg';
      icon = Icons.directions_car_filled_outlined;
    } else if (here != null) {
      title = here.name;
      icon = placeIcon(here.icon);
    } else {
      final address = ref
          .watch(placeAddressProvider(snapToAddressGrid(location.latitude, location.longitude)))
          .value;
      title = address == null || address.isEmpty ? 'Onbekend' : address.label;
      icon = Icons.location_on;
    }

    final subtitle = ongoing
        ? '${formatClock(since)} – ${formatClock(now)}'
        : TripStatus.at(location, now).description(location, now);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: AppColors.primarySoft),
        boxShadow: tokens.shadowLevel1,
      ),
      padding: EdgeInsets.all(tokens.spaceMd),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleLarge),
                    SizedBox(height: tokens.spaceXs),
                    Text(subtitle, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceMd),
              Container(
                width: 48,
                height: 48,
                decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, color: AppColors.primary),
              ),
            ],
          ),
          Padding(
            padding: EdgeInsets.symmetric(vertical: tokens.spaceSm),
            child: const Divider(height: 1),
          ),
          Row(
            children: [
              if (ongoing) ...[
                const Icon(Icons.schedule, size: 16, color: AppColors.muted),
                const SizedBox(width: 6),
                Text('Nu aan de gang', style: text.bodyMedium),
              ],
              const Spacer(),
              TextButton.icon(
                onPressed: onRefresh,
                icon: const Icon(Icons.refresh, size: 18),
                label: const Text('Verversen'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
