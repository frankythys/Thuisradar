import 'package:flutter/material.dart';

import '../../../l10n/l10n.dart';

/// De uitleg die Google Play vóór de Android-vraag om locatie eist: waarvoor
/// de app locatie gebruikt, ook als ze gesloten is of niet gebruikt wordt.
/// Geeft true bij "Akkoord"; enkel dan mag de Android-vraag volgen.
Future<bool> showLocationDisclosure(BuildContext context) async {
  final accepted = await showDialog<bool>(
    context: context,
    barrierDismissible: false,
    builder: (context) {
      final l10n = context.l10n;
      return AlertDialog(
        icon: const Icon(Icons.location_on_outlined),
        title: Text(l10n.locationDisclosureTitle),
        content: SingleChildScrollView(child: Text(l10n.locationDisclosureBody)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text(l10n.locationDisclosureDecline),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(l10n.locationDisclosureAccept),
          ),
        ],
      );
    },
  );
  return accepted ?? false;
}
