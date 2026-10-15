import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/time_format.dart';
import '../application/family_providers.dart';
import '../domain/family.dart';
import '../../../l10n/l10n.dart';

/// "Geldig tot 18/10 om 14:05", of dat de code verlopen is. Null als de
/// vervaldatum onbekend is (migratie 017 nog niet uitgevoerd).
String? inviteValidity(AppLocalizations l10n, Family family, DateTime now, {required bool isOwner}) {
  final expiresAt = family.inviteExpiresAt;
  if (expiresAt == null) return null;
  if (family.inviteExpiredAt(now)) {
    return isOwner ? l10n.familyCodeExpiredOwner : l10n.familyCodeExpiredMember;
  }
  return l10n.familyCodeValidUntil('${expiresAt.day}/${expiresAt.month}', formatClock(expiresAt));
}

/// De geldigheid van de code als kleine regel, rood als ze verlopen is.
class InviteValidityText extends StatelessWidget {
  const InviteValidityText({super.key, required this.family, required this.isOwner, this.textAlign});

  final Family family;
  final bool isOwner;
  final TextAlign? textAlign;

  @override
  Widget build(BuildContext context) {
    final now = DateTime.now();
    final validity = inviteValidity(context.l10n, family, now, isOwner: isOwner);
    if (validity == null) return const SizedBox.shrink();
    return Text(
      validity,
      textAlign: textAlign,
      style: Theme.of(context).textTheme.bodySmall
          ?.copyWith(color: family.inviteExpiredAt(now) ? AppColors.alert : AppColors.muted),
    );
  }
}

/// Profiel › Gezin: de actuele code (kopiëren), tot wanneer ze geldig is en,
/// voor de beheerder, "Nieuwe code maken".
class InviteCodePanel extends ConsumerWidget {
  const InviteCodePanel({super.key, required this.family});

  /// De bekende code; de panel toont de actuele zodra die geladen is.
  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final invite = ref.watch(familyInviteProvider(family.id)).value ?? family;
    final isOwner = ref.watch(isFamilyOwnerProvider(family.id));
    return Column(
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
                    Text(
                      context.l10n.familyInviteCodeLabel,
                      style: text.labelSmall?.copyWith(color: AppColors.muted),
                    ),
                    Text(invite.inviteCode, style: text.titleLarge?.copyWith(color: AppColors.primary)),
                    InviteValidityText(family: invite, isOwner: isOwner),
                  ],
                ),
              ),
              IconButton(
                tooltip: context.l10n.commonCopyCode,
                icon: const Icon(Icons.content_copy, color: AppColors.primary),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: invite.inviteCode));
                  if (context.mounted) {
                    ScaffoldMessenger.of(context)
                        .showSnackBar(SnackBar(content: Text(context.l10n.commonCodeCopied)));
                  }
                },
              ),
            ],
          ),
        ),
        if (isOwner) ...[SizedBox(height: tokens.spaceSm), RenewInviteCodeButton(familyId: family.id)],
      ],
    );
  }
}

/// Beheerder: een nieuwe code maken. De oude werkt daarna niet meer, zodat een
/// code die te ver rondging (groepschat, screenshot) geen toegang meer geeft.
class RenewInviteCodeButton extends ConsumerStatefulWidget {
  const RenewInviteCodeButton({super.key, required this.familyId});

  final String familyId;

  @override
  ConsumerState<RenewInviteCodeButton> createState() => _RenewInviteCodeButtonState();
}

class _RenewInviteCodeButtonState extends ConsumerState<RenewInviteCodeButton> {
  bool _busy = false;

  Future<void> _renew() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.familyRenewTitle),
        content: Text(context.l10n.familyRenewBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(context.l10n.familyRenewConfirm),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(familyRepositoryProvider).rotateInviteCode(widget.familyId);
      ref.invalidate(familyInviteProvider(widget.familyId));
      messenger.showSnackBar(SnackBar(content: Text(l10n.familyRenewDone)));
    } on Exception catch (error) {
      debugPrint('Nieuwe uitnodigingscode mislukt: $error');
      messenger.showSnackBar(SnackBar(content: Text(l10n.familyRenewFailed)));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _renew,
    icon: const Icon(Icons.autorenew, size: 20),
    label: Text(context.l10n.familyRenewButton),
  );
}
