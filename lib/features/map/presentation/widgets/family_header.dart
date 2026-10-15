import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../family/domain/family.dart';
import '../../../../l10n/l10n.dart';

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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(context.l10n.mapCodeCopiedSend(family.inviteCode))));
  }

  @override
  Widget build(BuildContext context) {
    return PopupMenuButton<_HeaderAction>(
      tooltip: context.l10n.mapFamilyMenu,
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
            title: Text(context.l10n.mapInviteMember),
            subtitle: Text(context.l10n.mapCode(family.inviteCode)),
          ),
        ),
        PopupMenuItem(
          value: _HeaderAction.profile,
          child: ListTile(leading: const Icon(Icons.person_outline), title: Text(context.l10n.profileTitle)),
        ),
        PopupMenuItem(
          value: _HeaderAction.signOut,
          child: ListTile(leading: const Icon(Icons.logout), title: Text(context.l10n.profileSignOut)),
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
