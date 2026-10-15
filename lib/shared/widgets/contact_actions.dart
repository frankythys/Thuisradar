import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../features/family/domain/family_member.dart';
import '../../l10n/l10n.dart';

Future<void> callMember(BuildContext context, FamilyMember member) async {
  if (member.phone == null || member.phone!.isEmpty) {
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.contactNoPhone(member.displayName))));
    return;
  }
  try {
    final opened = await launchUrl(Uri(scheme: 'tel', path: member.phone));
    if (!opened) throw StateError('No dialer');
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.contactDialerFailed)));
    }
  }
}

Future<void> chooseContact(BuildContext context, List<FamilyMember> members) async {
  final member = await showModalBottomSheet<FamilyMember>(
    context: context,
    builder: (context) => SafeArea(
      child: ListView(
        shrinkWrap: true,
        children: [
          ListTile(title: Text(context.l10n.contactCallMember)),
          for (final member in members)
            ListTile(
              leading: const Icon(Icons.phone_outlined),
              title: Text(member.displayName),
              subtitle: Text(member.phone ?? context.l10n.contactNoPhoneShort),
              onTap: () => Navigator.pop(context, member),
            ),
        ],
      ),
    ),
  );
  if (member != null && context.mounted) await callMember(context, member);
}
