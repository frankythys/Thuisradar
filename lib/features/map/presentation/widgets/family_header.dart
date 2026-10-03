import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../family/domain/family.dart';

enum _HeaderAction { copyInvite, profile, signOut }

/// Knop linksboven met de familienaam en een menu (uitnodigen, profiel, uitloggen).
class FamilyHeader extends StatelessWidget {
  const FamilyHeader({super.key, required this.family, required this.onSignOut, required this.onProfile});

  final Family family;
  final VoidCallback onSignOut;
  final VoidCallback onProfile;

  Future<void> _copyInvite(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: family.inviteCode));
    if (!context.mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Code ${family.inviteCode} gekopieerd. Stuur hem naar je gezinslid.')),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HeaderAction>(
      tooltip: 'Familiemenu',
      position: PopupMenuPosition.under,
      onSelected: (action) => switch (action) {
        _HeaderAction.copyInvite => _copyInvite(context),
        _HeaderAction.profile => onProfile(),
        _HeaderAction.signOut => onSignOut(),
      },
      itemBuilder: (_) => [
        PopupMenuItem(
          value: _HeaderAction.copyInvite,
          child: ListTile(
            leading: const Icon(Icons.person_add_alt),
            title: const Text('Gezinslid uitnodigen'),
            subtitle: Text('Code: ${family.inviteCode}'),
          ),
        ),
        const PopupMenuItem(
          value: _HeaderAction.profile,
          child: ListTile(leading: Icon(Icons.person_outline), title: Text('Profiel')),
        ),
        const PopupMenuItem(
          value: _HeaderAction.signOut,
          child: ListTile(leading: Icon(Icons.logout), title: Text('Uitloggen')),
        ),
      ],
      child: Material(
        color: Colors.white,
        elevation: 4,
        shadowColor: const Color(0x40121C1C),
        shape: const StadiumBorder(),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(family.name, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
              const SizedBox(width: 4),
              const Icon(Icons.expand_more, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
