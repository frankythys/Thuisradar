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

part 'family_setup_screen_choice_tile.dart';
part 'family_setup_screen_field_label.dart';
part 'family_setup_screen_forms.dart';

/// Hoe start je: zelf een familie maken of er een joinen met een code.
enum SetupChoice { create, join }

/// Scherm 7: een familie aanmaken of er een joinen met een code. Twee
/// keuzetegels naast elkaar; alleen het gekozen formulier staat open.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _familyName = TextEditingController();
  final _inviteCode = TextEditingController();
  SetupChoice _choice = SetupChoice.create;
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

  Future<void> _pasteCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final clean = (data?.text ?? '').replaceAll(RegExp('[^a-zA-Z0-9]'), '').toUpperCase();
    if (!mounted || clean.isEmpty) return;
    _inviteCode.text = clean.substring(0, clean.length.clamp(0, 8));
  }

  void _choose(SetupChoice choice) => setState(() {
    _choice = choice;
    _error = null;
  });

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final creating = _choice == SetupChoice.create;

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
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceSm, tokens.spaceLg, tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text('Hoe wil je starten?', style: text.headlineMedium),
              SizedBox(height: tokens.spaceXs),
              Text(
                'Maak een nieuwe familie of sluit aan met een code.',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
              ),
              SizedBox(height: tokens.spaceMd),
              IntrinsicHeight(
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Expanded(
                      child: _ChoiceTile(
                        icon: Icons.home_rounded,
                        label: 'Nieuwe familie',
                        selected: creating,
                        onTap: () => _choose(SetupChoice.create),
                      ),
                    ),
                    SizedBox(width: tokens.spaceSm + tokens.spaceXs),
                    Expanded(
                      child: _ChoiceTile(
                        icon: Icons.vpn_key_outlined,
                        label: 'Ik heb een code',
                        selected: !creating,
                        onTap: () => _choose(SetupChoice.join),
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              AppCard(
                padding: EdgeInsets.all(tokens.spaceMd),
                child: creating
                    ? _CreateForm(controller: _familyName, busy: _busy, onSubmit: _create)
                    : _JoinForm(controller: _inviteCode, busy: _busy, onSubmit: _join, onPaste: _pasteCode),
              ),
              if (_error != null) ...[
                SizedBox(height: tokens.spaceSm),
                Text(_error!, style: text.bodyMedium?.copyWith(color: AppColors.alert)),
              ],
              SizedBox(height: tokens.spaceMd),
              Row(
                children: [
                  const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                  SizedBox(width: tokens.spaceSm),
                  Expanded(
                    child: Text(
                      'Alleen wie je uitnodigt, ziet je op de kaart.',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
