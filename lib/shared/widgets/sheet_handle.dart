import 'package:flutter/material.dart';

import '../../core/theme/app_colors.dart';

/// Greep bovenaan een uitschuifpaneel, met ruimte eronder: in de laagste
/// stand van het paneel is enkel de greep zichtbaar, de tekst valt erbuiten.
/// Gedeeld door de ledenlijst en het persoonsscherm, zodat beide panelen even
/// hoog stoppen en er hetzelfde uitzien.
class SheetHandle extends StatelessWidget {
  const SheetHandle({super.key});

  /// Hoogte van het vak met het streepje.
  static const handleHeight = 16.0;

  /// Extra ruimte tussen de greep en de tekst eronder.
  static const textDrop = 16.0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: handleHeight + textDrop,
      child: Align(
        alignment: Alignment.topCenter,
        child: SizedBox(
          height: handleHeight,
          child: Center(
            child: Container(
              width: 36,
              height: 4,
              decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
            ),
          ),
        ),
      ),
    );
  }
}
