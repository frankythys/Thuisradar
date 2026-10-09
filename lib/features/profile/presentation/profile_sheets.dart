import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../application/profile_providers.dart';

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

/// Gezin: uitnodigingscode (kopiëren), de leden en "iemand uitnodigen".
Future<void> showFamilySheet(
  BuildContext context, {
  required Family family,
  required List<FamilyMember> members,
  required VoidCallback onInvite,
}) {
  final tokens = context.tokens;
  final text = Theme.of(context).textTheme;
  return _sheet(
    context,
    family.name,
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceXs, tokens.spaceSm),
          decoration: BoxDecoration(
            color: AppColors.primarySoft,
            borderRadius: BorderRadius.circular(tokens.radiusMd),
          ),
          child: Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('UITNODIGINGSCODE', style: text.labelSmall?.copyWith(color: AppColors.muted)),
                    Text(family.inviteCode, style: text.titleLarge?.copyWith(color: AppColors.primary)),
                  ],
                ),
              ),
              IconButton(
                tooltip: 'Code kopiëren',
                icon: const Icon(Icons.content_copy, color: AppColors.primary),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: family.inviteCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(const SnackBar(content: Text('Code gekopieerd')));
                  }
                },
              ),
            ],
          ),
        ),
        SizedBox(height: tokens.spaceSm),
        for (final member in members)
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: MemberAvatar(member: member, size: 36),
            title: Text(member.displayName),
            subtitle: Text(member.isOwner ? 'Beheerder' : 'Gezinslid'),
          ),
        SizedBox(height: tokens.spaceSm),
        FilledButton.icon(
          onPressed: () {
            Navigator.pop(context);
            onInvite();
          },
          icon: const Icon(Icons.person_add_alt_1_outlined),
          label: const Text('Iemand uitnodigen'),
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
    'Meldingen',
    Consumer(
      builder: (context, ref, _) {
        final prefs = ref.watch(notificationPreferencesProvider).value ?? const <String, dynamic>{};
        return Column(
          children: [
            for (final (key, title, subtitle) in const [
              ('arrival', 'Aankomst', 'Als iemand bij een plaats aankomt'),
              ('departure', 'Vertrek', 'Als iemand een plaats verlaat'),
              ('sos', 'Noodberichten (SOS)', 'Altijd aanlaten is aangeraden'),
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
    'Privacy & beveiliging',
    Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'Alleen leden van jouw gezin zien je locatie, plaatsen en berichten. De verbinding is '
          'versleuteld. Je kunt locatie delen altijd pauzeren in je profiel.',
          style: text.bodyMedium,
        ),
        SizedBox(height: tokens.spaceLg),
        OutlinedButton.icon(
          onPressed: () async {
            Navigator.pop(context);
            await onForgetLogin();
          },
          icon: const Icon(Icons.fingerprint),
          label: const Text('Opgeslagen login verwijderen'),
        ),
      ],
    ),
  );
}
