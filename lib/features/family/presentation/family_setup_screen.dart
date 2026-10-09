import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../auth/application/auth_providers.dart';
import '../application/family_providers.dart';
import '../domain/family.dart';
import 'invite_screen.dart';
import 'invite_code_input.dart';
import 'welcome_screen.dart';

part 'family_setup_screen_card_header.dart';
part 'family_setup_screen_badge.dart';
part 'family_setup_screen_field_label.dart';
part 'family_setup_screen_step_pill.dart';

/// Scherm 7: een familie aanmaken of er een joinen met een code.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _familyName = TextEditingController();
  final _inviteCode = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _familyName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<Family> Function() action, Widget Function(Family) next) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final family = await action();
      ref.invalidate(myFamilyProvider);
      if (!mounted) return;
      await Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => next(family)));
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _create() {
    final name = _familyName.text.trim();
    if (name.isEmpty) return;
    _run(
      () => ref.read(familyRepositoryProvider).createFamily(name),
      (family) => InviteScreen(family: family, justCreated: true),
    );
  }

  void _join() {
    final code = _inviteCode.text.trim();
    if (code.isEmpty) return;
    _run(
      () => ref.read(familyRepositoryProvider).joinFamily(code),
      (family) => WelcomeScreen(family: family),
    );
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: BrandedAppBar(
        title: 'Jouw familie',
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Uitloggen'),
          ),
        ],
      ),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            Row(
              children: [
                _StepPill(),
                const Spacer(),
                Text('Gezinsconfiguratie', style: text.bodyMedium?.copyWith(color: AppColors.muted)),
              ],
            ),
            SizedBox(height: tokens.spaceMd),
            Text('Jouw familie', style: text.headlineLarge),
            SizedBox(height: tokens.spaceSm),
            Text(
              'Kies hoe je aan de slag wilt gaan met CircleBeacon.',
              style: text.bodyLarge?.copyWith(color: AppColors.muted),
            ),
            SizedBox(height: tokens.spaceLg),
            AppCard(
              padding: EdgeInsets.all(tokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardHeader(
                    icon: Icons.home_rounded,
                    iconColor: AppColors.primary,
                    iconBackground: AppColors.primarySoft,
                    title: 'Nieuwe familie maken',
                    badge: 'Nieuw',
                    body: 'Start een nieuwe besloten gezinskring en nodig je gezinsleden uit.',
                  ),
                  SizedBox(height: tokens.spaceMd),
                  _FieldLabel(label: 'Familienaam', trailing: 'Privé & gecodeerd'),
                  SizedBox(height: tokens.spaceSm),
                  TextField(
                    controller: _familyName,
                    decoration: const InputDecoration(
                      hintText: 'Familie Thys',
                      fillColor: AppColors.surfaceLow,
                      prefixIcon: Icon(Icons.groups_outlined, color: AppColors.primary),
                    ),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  FilledButton(
                    onPressed: _busy ? null : _create,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text('Familie aanmaken'),
                        SizedBox(width: tokens.spaceSm),
                        const Icon(Icons.arrow_forward, size: 20),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spaceLg),
            Row(
              children: [
                const Expanded(child: Divider()),
                Padding(
                  padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd),
                  child: Text('OF AANSLUITEN', style: text.labelMedium?.copyWith(color: AppColors.muted)),
                ),
                const Expanded(child: Divider()),
              ],
            ),
            SizedBox(height: tokens.spaceLg),
            AppCard(
              padding: EdgeInsets.all(tokens.spaceLg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _CardHeader(
                    icon: Icons.vpn_key_outlined,
                    iconColor: AppColors.secondary,
                    iconBackground: const Color(0xFFE7DEFF),
                    title: 'Ik heb een uitnodigingscode',
                    body: 'Voer de 8-tekens lange code in die je van een gezinslid hebt ontvangen.',
                  ),
                  SizedBox(height: tokens.spaceMd),
                  Row(
                    children: [
                      const Expanded(child: _FieldLabel(label: 'Toegangscode')),
                      TextButton(
                        onPressed: () async {
                          final data = await Clipboard.getData(Clipboard.kTextPlain);
                          if (mounted && data?.text != null) {
                            _inviteCode.text = data!.text!
                                .replaceAll(RegExp('[^a-zA-Z0-9]'), '')
                                .toUpperCase()
                                .substring(
                                  0,
                                  data.text!.replaceAll(RegExp('[^a-zA-Z0-9]'), '').length.clamp(0, 8),
                                );
                          }
                        },
                        child: const Text('Plak klembord'),
                      ),
                    ],
                  ),
                  SizedBox(height: tokens.spaceSm),
                  InviteCodeInput(controller: _inviteCode),
                  SizedBox(height: tokens.spaceMd),
                  FilledButton.icon(
                    onPressed: _busy ? null : _join,
                    icon: const Icon(Icons.group_add_outlined, size: 20),
                    label: const Text('Deelnemen aan familie'),
                    style: FilledButton.styleFrom(
                      backgroundColor: AppColors.primarySoft,
                      foregroundColor: AppColors.primary,
                    ),
                  ),
                ],
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: tokens.spaceMd),
              Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.alert)),
            ],
            SizedBox(height: tokens.spaceLg),
            Container(
              padding: EdgeInsets.all(tokens.spaceMd),
              decoration: BoxDecoration(
                color: AppColors.ground,
                borderRadius: BorderRadius.circular(tokens.radiusCard),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Text(
                      'Alleen uitgenodigde leden zien elkaar op de CircleBeacon kaart.',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
