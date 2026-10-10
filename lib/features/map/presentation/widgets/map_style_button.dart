import 'package:flutter/material.dart';

/// Zwevende knop: wisselen tussen gewone kaart en satelliet (Google Maps).
class MapStyleButton extends StatelessWidget {
  const MapStyleButton({super.key, required this.satellite, required this.onPressed});

  final bool satellite;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;
    return Material(
      color: colors.surface,
      shape: const CircleBorder(),
      elevation: 3,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Tooltip(
          message: satellite ? 'Gewone kaart' : 'Satelliet',
          child: SizedBox(
            width: 48,
            height: 48,
            child: Icon(satellite ? Icons.map_outlined : Icons.satellite_alt_outlined, color: colors.primary),
          ),
        ),
      ),
    );
  }
}
