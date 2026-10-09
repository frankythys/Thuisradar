import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../permissions/presentation/permissions_screen.dart';
import '../domain/family.dart';

part 'invite_screen_success_hero.dart';
part 'invite_screen_code_card.dart';
part 'invite_screen_how_it_works.dart';
part 'invite_screen_step_badge.dart';

/// Scherm 8: na het aanmaken van een familie. Toont de code en laat die delen.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key, required this.family, this.justCreated = false});

  final Family family;

  /// Net na het aanmaken: "Familie aangemaakt!" en een knop door naar de app.
  /// Vanuit kaart of profiel gewoon "Nodig je gezin uit".
  final bool justCreated;

  Future<void> _share(BuildContext context) async {
    final box = context.findRenderObject() as RenderBox?;
    try {
      await SharePlus.instance.share(
        ShareParams(
          text:
              'Kom bij "${family.name}" op CircleBeacon.\n'
              'Open de app, kies "Ik heb een uitnodigingscode" en vul in: ${family.inviteCode}',
          subject: 'Uitnodiging voor CircleBeacon',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Verzenden lukt niet. Probeer opnieuw of kopieer de code.')),
        );
      }
    }
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: family.inviteCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Code gekopieerd')));
    }
  }

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Gezin uitnodigen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceSm, tokens.spaceLg, tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _SuccessHero(justCreated: justCreated),
              SizedBox(height: tokens.spaceMd),
              Text(
                justCreated ? 'Familie aangemaakt!' : 'Nodig je gezin uit',
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                'Stuur de code. Wie ze invult, ziet jullie meteen op de kaart.',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceLg),
              _CodeCard(code: family.inviteCode, onCopy: () => _copy(context)),
              SizedBox(height: tokens.spaceMd),
              Builder(
                builder: (buttonContext) => FilledButton.icon(
                  onPressed: () => _share(buttonContext),
                  icon: const Icon(Icons.share, size: 20),
                  label: const Text('Uitnodiging versturen'),
                ),
              ),
              SizedBox(height: tokens.spaceLg),
              const _HowItWorks(),
              if (justCreated) ...[
                SizedBox(height: tokens.spaceMd),
                TextButton(onPressed: () => _continue(context), child: const Text('Doorgaan naar app')),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
