import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../profile/presentation/profile_tile.dart';
import '../application/emergency_providers.dart';
import 'emergency_contacts_screen.dart';

/// Rij in het profiel: wie je noodcontacten zijn, tik om ze te wijzigen.
class EmergencyContactsTile extends ConsumerWidget {
  const EmergencyContactsTile({super.key, required this.senderName});

  final String senderName;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final contacts = ref.watch(myEmergencyContactsProvider).value ?? const [];
    return ProfileTile(
      icon: Icons.contact_emergency_outlined,
      title: 'Noodcontacten',
      subtitle: contacts.isEmpty
          ? 'Nog niemand · krijgen een sms bij SOS'
          : '${contacts.map((contact) => contact.name).join(' en ')} · sms bij SOS',
      onTap: () =>
          Navigator.of(context)
              .push(MaterialPageRoute<void>(builder: (_) => EmergencyContactsScreen(senderName: senderName))),
    );
  }
}
