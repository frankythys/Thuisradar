part of 'member_detail_screen.dart';

/// De dag als Life360-kaartjes, nieuwste bovenaan: elke rit met zijn eigen
/// route op een kaart (van → naar, tijd, afstand, topsnelheid) en elk
/// verblijf met plek, tijd en duur. Losse lijstitems i.p.v. één kolom, zodat
/// de lijst enkel de zichtbare ritkaarten opbouwt.
List<Widget> _dayActivities(
  BuildContext context, {
  required DayDriving day,
  required List<Place> places,
  required void Function(double latitude, double longitude) onSaveAsPlace,
}) {
  if (day.activities.isEmpty) {
    return const [
      EmptyState(
        icon: Icons.history,
        title: 'Geen geschiedenis',
        message: 'Voor deze dag is er nog geen locatiegeschiedenis.',
      ),
    ];
  }
  final tokens = context.tokens;
  return [
    for (var index = day.activities.length - 1; index >= 0; index--)
      Padding(
        padding: EdgeInsets.only(bottom: tokens.spaceSm),
        child: DrivingActivityCard(
          activity: day.activities[index],
          places: places,
          route: day.trackAt(index),
          onSaveAsPlace: () => onSaveAsPlace(day.activities[index].latitude, day.activities[index].longitude),
        ),
      ),
  ];
}
