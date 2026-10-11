import 'package:flutter/material.dart';

import '../../../shared/widgets/icon_filter_chips.dart';
import '../../location/domain/travel_mode.dart';

/// Icoon per vervoermiddel.
IconData travelModeIcon(TravelMode mode) => switch (mode) {
  TravelMode.walk => Icons.directions_walk,
  TravelMode.bike => Icons.directions_bike,
  TravelMode.car => Icons.directions_car,
};

/// 3D-afbeelding per vervoermiddel voor de kaartjes, zoals Life360.
String travelModeImage(TravelMode mode) => switch (mode) {
  TravelMode.walk => 'assets/markers/wandelen.png',
  TravelMode.bike => 'assets/markers/fiets.png',
  TravelMode.car => 'assets/markers/auto.png',
};

/// De keuzes van de filter, in volgorde; null is "alles".
const travelModeFilters = <TravelMode?>[null, TravelMode.car, TravelMode.bike, TravelMode.walk];

/// Rij icoon-chips: Alles, Auto, Fiets, Wandelen.
class TravelModeFilter extends StatelessWidget {
  const TravelModeFilter({super.key, required this.mode, required this.onChanged});

  final TravelMode? mode;
  final ValueChanged<TravelMode?> onChanged;

  @override
  Widget build(BuildContext context) => IconFilterChips(
    items: [
      for (final filter in travelModeFilters)
        filter == null
            ? const IconFilterItem(icon: Icons.route, label: 'Alles')
            : IconFilterItem(icon: travelModeIcon(filter), label: filter.label),
    ],
    selectedIndex: travelModeFilters.indexOf(mode),
    onSelected: (index) => onChanged(travelModeFilters[index]),
  );
}
