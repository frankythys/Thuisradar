import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';
import 'package:url_launcher/url_launcher.dart';

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
  const InviteScreen({super.key, required this.family});

  final Family family;

  Future<void> _share() async {
    final uri = Uri.https('wa.me', '/', {
      'text':
          'Kom bij ${family.name} op Thuisradar. Je gezinscode: ${family.inviteCode}',
    });
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}

    await SharePlus.instance.share(
      ShareParams(
        text:
            'Join onze familie "${family.name}" op Thuisradar.\n'
            'Open de app, kies "Ik heb een uitnodigingscode" en vul in: ${family.inviteCode}',
        subject: 'Uitnodiging voor Thuisradar',
      ),
    );
  }

  Future<void> _copy(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: family.inviteCode));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Code gekopieerd')));
    }
  }

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Familie uitnodigen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SuccessHero(),
              SizedBox(height: tokens.spaceLg),
              Text(
                'Familie aangemaakt!',
                style: text.headlineLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceSm),
              Text(
                'Nodig je gezinsleden uit om samen locaties en veilige aankomsten te delen.',
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceLg),
              _CodeCard(code: family.inviteCode),
              SizedBox(height: tokens.spaceLg),
              FilledButton.icon(
                onPressed: _share,
                icon: const Icon(Icons.share, size: 20),
                label: const Text('Delen via WhatsApp'),
              ),
              SizedBox(height: tokens.spaceSm),
              FilledButton.tonalIcon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('Code kopiëren'),
              ),
              SizedBox(height: tokens.spaceLg),
              const _HowItWorks(),
              SizedBox(height: tokens.spaceLg),
              TextButton(
                onPressed: () => _continue(context),
                child: const Text('Doorgaan naar app'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
