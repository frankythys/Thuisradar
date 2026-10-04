import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';

/// Eén tegelprovider/netwerkclient per kaart, ook bij live statusupdates.
/// TileLayer beheert de provider en sluit hem bij het verwijderen van de kaart.
class AppMapTiles extends StatefulWidget {
  const AppMapTiles({super.key});

  @override
  State<AppMapTiles> createState() => _AppMapTilesState();
}

class _AppMapTilesState extends State<AppMapTiles> {
  late final _tiles = TileLayer(
    urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
    userAgentPackageName: 'be.thuisradar.thuisradar',
    // Behoud enkele reeds geladen rijen langer bij terugschuiven.
    // Geen extra vooraf downloaden: de laadbuffer blijft één rij.
    keepBuffer: 3,
    panBuffer: 1,
  );

  @override
  Widget build(BuildContext context) => _tiles;
}
