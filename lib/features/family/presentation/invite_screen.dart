import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../permissions/presentation/permissions_screen.dart';
import '../application/family_providers.dart';
import '../domain/family.dart';
import 'invite_code_controls.dart';
import '../../../l10n/l10n.dart';

part 'invite_screen_success_hero.dart';
part 'invite_screen_code_card.dart';
part 'invite_screen_how_it_works.dart';
part 'invite_screen_step_badge.dart';

/// Scherm 8: na het aanmaken van een familie. Toont de code en laat die delen.
class InviteScreen extends ConsumerWidget {
  const InviteScreen({super.key, required this.family, this.justCreated = false});

  final Family family;

  /// Net na het aanmaken: "Familie aangemaakt!" en een knop door naar de app.
  /// Vanuit kaart of profiel gewoon "Nodig je gezin uit".
  final bool justCreated;

  Future<void> _share(BuildContext context, Family family) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text: context.l10n.familyInviteShareText(family.name, family.inviteCode),
          subject: context.l10n.familyInviteShareSubject,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text(context.l10n.familyInviteShareFailed)));
      }
    }
  }

  Future<void> _copy(BuildContext context, Family family) async {
    await Clipboard.setData(ClipboardData(text: family.inviteCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(context.l10n.commonCodeCopied)));
    }
  }

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    // De actuele code (na "Nieuwe code" of het verwijderen van een lid); tot
    // die geladen is, de code die we al kenden.
    final family = ref.watch(familyInviteProvider(this.family.id)).value ?? this.family;
    final isOwner = ref.watch(isFamilyOwnerProvider(family.id));

    return Scaffold(
      appBar: BrandedAppBar(title: context.l10n.familyInviteTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceSm, tokens.spaceLg, tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SuccessHero(justCreated: justCreated),
              SizedBox(height: tokens.spaceMd),
              Text(
                justCreated ? context.l10n.familyCreatedHeadline : context.l10n.familyInviteHeadline,
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                context.l10n.familyInviteIntro,
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceLg),
              _CodeCard(code: family.inviteCode, onCopy: () => _copy(context, family)),
              SizedBox(height: tokens.spaceXs),
              InviteValidityText(family: family, isOwner: isOwner, textAlign: TextAlign.center),
              SizedBox(height: tokens.spaceMd),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: () => _share(buttonContext, family),
                  icon: const Icon(Icons.share, size: 20),
                  label: Text(context.l10n.familyInviteSend),
                ),
              ),
              if (isOwner) ...[SizedBox(height: tokens.spaceSm), RenewInviteCodeButton(familyId: family.id)],
              SizedBox(height: tokens.spaceLg),
              const _HowItWorks(),
              if (justCreated) ...[
                SizedBox(height: tokens.spaceMd),
                TextButton(
                  onPressed: () => _continue(context),
                  child: Text(context.l10n.familyContinueToApp),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
