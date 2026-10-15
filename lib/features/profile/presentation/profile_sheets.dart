import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../../family/presentation/invite_code_controls.dart';
import '../application/profile_providers.dart';
import '../../../l10n/l10n.dart';

Future<void> _sheet(BuildContext context, String title, Widget child) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (context) {
      final tokens = context.tokens;
      return SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(tokens.spaceLg, 0, tokens.spaceLg, tokens.spaceLg),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(title, style: Theme.of(context).textTheme.titleLarge),
              SizedBox(height: tokens.spaceMd),
              child,
            ],
          ),
        ),
      );
    },
  );
}

/// Gezin: uitnodigingscode (kopiëren, geldigheid, voor de beheerder "Nieuwe
/// code maken"), de leden en "iemand uitnodigen".
/// Voor de beheerder ([onMakeOwner] en [onRemove]) krijgt elk ander lid een
/// menu: beheerder maken of uit het gezin verwijderen.
Future<void> showFamilySheet(
  BuildContext context, {
  required Family family,
  required List<FamilyMember> members,
  required VoidCallback onInvite,
  void Function(FamilyMember member)? onMakeOwner,
  void Function(FamilyMember member)? onRemove,
}) {
  final tokens = context.tokens;
  return _sheet(
    context,
    family.name,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Code, geldigheid en (beheerder) "Nieuwe code maken".
        InviteCodePanel(family: family),
        SizedBox(height: tokens.spaceSm),
        for (final member in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: MemberAvatar(member: member, size: 36),
            title: Text(member.displayName),
            subtitle: Text(member.isOwner ? context.l10n.commonOwner : context.l10n.commonMember),
            trailing: (onRemove == null && onMakeOwner == null) || member.isOwner
                ? null
                : PopupMenuButton<void Function(FamilyMember)>(
                    tooltip: context.l10n.profileMemberOptions(member.displayName),
                    icon: const Icon(Icons.more_vert),
                    onSelected: (action) {
                      Navigator.pop(context);
                      action(member);
                    },
                    itemBuilder: (context) => [
                      if (onMakeOwner != null)
                        PopupMenuItem(
                          value: onMakeOwner,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.admin_panel_settings_outlined),
                            title: Text(context.l10n.profileMakeOwnerConfirm),
                          ),
                        ),
                      if (onRemove != null)
                        PopupMenuItem(
                          value: onRemove,
                          child: ListTile(
                            contentPadding: EdgeInsets.zero,
                            leading: const Icon(Icons.person_remove_outlined, color: AppColors.alert),
                            title: Text(context.l10n.profileRemoveFromFamily),
                          ),
                        ),
                    ],
                  ),
          ),
        SizedBox(height: tokens.spaceSm),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onInvite();
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: Text(context.l10n.profileInviteSomeone),
        ),
      ],
    ),
  );
}

/// Meldingen: aankomst, vertrek en SOS aan of uit.
Future<void> showNotificationsSheet(
  BuildContext context, {
  required Future<void> Function(String key, bool enabled) onChanged,
}) {
  return _sheet(
    context,
    context.l10n.profileNotifications,
    Consumer(
      builder: (context, ref, _) {
        final prefs = ref.watch(notificationPreferencesProvider).value ?? const <String, dynamic>{};
        return Column(
          children: [
            for (final (key, title, subtitle) in [
              ('arrival', context.l10n.profileArrival, context.l10n.profileArrivalSubtitle),
              ('departure', context.l10n.profileDeparture, context.l10n.profileDepartureSubtitle),
              ('sos', context.l10n.profileSosNotifications, context.l10n.profileSosNotificationsSubtitle),
            ])
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(title),
                subtitle: Text(subtitle),
                value: prefs[key] as bool? ?? true,
                onChanged: (value) => onChanged(key, value),
              ),
          ],
        );
      },
    ),
  );
}

/// Privacy & beveiliging: uitleg en opgeslagen login/vingerafdruk wissen.
Future<void> showPrivacySheet(BuildContext context, {required Future<void> Function() onForgetLogin}) {
  final text = Theme.of(context).textTheme;
  final tokens = context.tokens;
  return _sheet(
    context,
    context.l10n.profilePrivacy,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(context.l10n.profilePrivacyText, style: text.bodyMedium),
        SizedBox(height: tokens.spaceLg),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await onForgetLogin();
          },
          icon: const Icon(Icons.fingerprint),
          label: Text(context.l10n.profileForgetLogin),
        ),
      ],
    ),
  );
}
