import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../permissions/presentation/permissions_screen.dart';
import '../domain/family.dart';

/// Scherm 8: na het aanmaken van een familie. Toont de code en laat die delen.
class InviteScreen extends StatelessWidget {
  const InviteScreen({super.key, required this.family});

  final Family family;

  Future<void> _share() async {
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
      appBar: const BrandedAppBar(title: 'Familie uitnodigen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _SuccessHero(),
              SizedBox(height: tokens.spaceLg),
              Text('Familie aangemaakt!', style: text.headlineLarge, textAlign: TextAlign.center),
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
                label: const Text('Delen'),
              ),
              SizedBox(height: tokens.spaceSm),
              OutlinedButton.icon(
                onPressed: () => _copy(context),
                icon: const Icon(Icons.copy, size: 20),
                label: const Text('Code kopiëren'),
              ),
              SizedBox(height: tokens.spaceLg),
              const _HowItWorks(),
              SizedBox(height: tokens.spaceLg),
              TextButton(onPressed: () => _continue(context), child: const Text('Doorgaan naar app')),
            ],
          ),
        ),
      ),
    );
  }
}

class _SuccessHero extends StatelessWidget {
  const _SuccessHero();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 96,
        height: 96,
        decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
        child: const Icon(Icons.check_circle, size: 56, color: AppColors.primary),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.code});

  final String code;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.vpn_key_outlined, size: 18, color: AppColors.primary),
              SizedBox(width: tokens.spaceSm),
              Text('Jouw unieke gezinscode', style: text.titleMedium),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Container(
            width: double.infinity,
            padding: EdgeInsets.symmetric(vertical: tokens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Text(
              code.split('').join(' '),
              style: text.headlineLarge?.copyWith(color: AppColors.primary),
              textAlign: TextAlign.center,
            ),
          ),
          SizedBox(height: tokens.spaceMd),
          Text('Alleen voor jouw gezin', style: text.bodySmall?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}

class _HowItWorks extends StatelessWidget {
  const _HowItWorks();

  static const _steps = [
    'Laat hen de Thuisradar app installeren.',
    'Kies "Ik heb een uitnodigingscode" en vul bovenstaande code in.',
    'Jullie zien elkaar direct veilig op de kaart.',
  ];

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Hoe werkt het voor gezinsleden?', style: text.titleLarge),
          SizedBox(height: tokens.spaceMd),
          for (final (index, step) in _steps.indexed) ...[
            if (index > 0) SizedBox(height: tokens.spaceMd),
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _StepBadge(number: index + 1),
                SizedBox(width: tokens.spaceMd),
                Expanded(child: Text(step, style: text.bodyMedium)),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _StepBadge extends StatelessWidget {
  const _StepBadge({required this.number});

  final int number;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 28,
      height: 28,
      alignment: Alignment.center,
      decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
      child: Text(
        '$number',
        style: Theme.of(context).textTheme.labelLarge?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
