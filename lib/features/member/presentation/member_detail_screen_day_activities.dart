part of 'member_detail_screen.dart';

/// De dag als Life360-kaartjes, nieuwste bovenaan: elke rit met zijn eigen
/// route op een kaart (van → naar, tijd, afstand, topsnelheid) en elk
/// verblijf met plek, tijd en duur.
class _DayActivities extends StatelessWidget {
  const _DayActivities({required this.history, required this.places, required this.onSaveAsPlace});

  final DayHistory history;
  final List<Place> places;
  final void Function(double latitude, double longitude) onSaveAsPlace;

  @override
  Widget build(BuildContext context) {
    final activities = buildDayActivities(attachPlaceNames(history.entries, places), history.points);
    if (activities.isEmpty) {
      return const EmptyState(
        icon: Icons.history,
        title: 'Geen geschiedenis',
        message: 'Voor deze dag is er nog geen locatiegeschiedenis.',
      );
    }
    final tokens = context.tokens;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final activity in activities.reversed) ...[
          DrivingActivityCard(
            activity: activity,
            places: places,
            route: activityTrack(activity, history.points),
            onSaveAsPlace: () => onSaveAsPlace(activity.latitude, activity.longitude),
          ),
          SizedBox(height: tokens.spaceSm),
        ],
      ],
    );
  }
}
