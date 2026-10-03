import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../application/auth_providers.dart';

enum _Mode { login, register }

class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  _Mode _mode = _Mode.login;
  bool _busy = false;
  bool _obscure = true;
  String? _message;

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
    });

    final auth = ref.read(authRepositoryProvider);
    try {
      if (_mode == _Mode.login) {
        await auth.signIn(email: _email.text.trim(), password: _password.text);
      } else {
        final signedIn = await auth.signUp(
          email: _email.text.trim(),
          password: _password.text,
          displayName: _name.text.trim(),
        );
        if (!signedIn && mounted) {
          setState(() => _message = 'Bevestig je e-mailadres en log daarna in.');
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() => setState(() {
    _mode = _mode == _Mode.login ? _Mode.register : _Mode.login;
    _message = null;
  });

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _Mode.register;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const _PrivacyChip(),
                SizedBox(height: tokens.spaceLg),
                const _LogoTile(),
                SizedBox(height: tokens.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.location_on_outlined, size: 18, color: AppColors.ink),
                    SizedBox(width: tokens.spaceXs),
                    Text('Thuisradar', style: text.titleMedium),
                  ],
                ),
                SizedBox(height: tokens.spaceSm),
                Text(
                  isRegister ? 'Maak je account' : 'Welkom terug',
                  style: text.headlineLarge,
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.spaceSm),
                Text(
                  isRegister
                      ? 'Een veilige en besloten cirkel voor jouw gezin.'
                      : 'Log in om je familie te zien.',
                  style: text.bodyLarge?.copyWith(color: AppColors.muted),
                  textAlign: TextAlign.center,
                ),
                SizedBox(height: tokens.spaceXl),
                if (isRegister) ...[
                  _Field(
                    label: 'Naam',
                    trailingLabel: 'Voor je gezin',
                    helper: 'Zo zien je gezinsleden je, bv. Papa',
                    controller: _name,
                    hintText: 'bv. Peter of Papa',
                    icon: Icons.person_outline,
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || v.trim().isEmpty) ? 'Vul een naam in' : null,
                  ),
                  SizedBox(height: tokens.spaceMd),
                ],
                _Field(
                  label: 'E-mailadres',
                  controller: _email,
                  hintText: 'naam@voorbeeld.be',
                  icon: Icons.mail_outline,
                  keyboardType: TextInputType.emailAddress,
                  autofillHints: const [AutofillHints.email],
                  textInputAction: TextInputAction.next,
                  validator: (v) => (v == null || !v.contains('@')) ? 'Ongeldig e-mailadres' : null,
                ),
                SizedBox(height: tokens.spaceMd),
                _Field(
                  label: 'Wachtwoord',
                  helper: 'Minimaal 8 tekens',
                  controller: _password,
                  hintText: 'Minimaal 8 tekens',
                  icon: Icons.lock_outline,
                  obscureText: _obscure,
                  autofillHints: const [AutofillHints.password],
                  onFieldSubmitted: (_) => _submit(),
                  suffix: IconButton(
                    onPressed: () => setState(() => _obscure = !_obscure),
                    icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                  ),
                  validator: (v) => (v == null || v.length < 8) ? 'Minstens 8 tekens' : null,
                ),
                if (_message != null) ...[
                  SizedBox(height: tokens.spaceMd),
                  Text(_message!, style: text.bodyMedium?.copyWith(color: AppColors.alert)),
                ],
                SizedBox(height: tokens.spaceLg),
                if (isRegister) const _PrivacyNote(),
                if (isRegister) SizedBox(height: tokens.spaceLg),
                FilledButton(
                  onPressed: _busy ? null : _submit,
                  child: _busy
                      ? const SizedBox.square(
                          dimension: 20,
                          child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                        )
                      : Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(isRegister ? 'Account aanmaken' : 'Inloggen'),
                            SizedBox(width: tokens.spaceSm),
                            const Icon(Icons.arrow_forward, size: 20),
                          ],
                        ),
                ),
                TextButton(
                  onPressed: _busy ? null : _toggleMode,
                  child: Text(isRegister ? 'Ik heb al een account' : 'Nieuw? Maak een account'),
                ),
                SizedBox(height: tokens.spaceSm),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                    SizedBox(width: tokens.spaceXs),
                    Text(
                      'Versleuteld & alleen zichtbaar voor jouw gezin',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gelabeld invoerveld met leidend icoon en optionele helper-tekst.
class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hintText,
    required this.icon,
    this.trailingLabel,
    this.helper,
    this.obscureText = false,
    this.keyboardType,
    this.autofillHints,
    this.textInputAction,
    this.onFieldSubmitted,
    this.suffix,
    this.validator,
  });

  final String label;
  final String? trailingLabel;
  final String? helper;
  final TextEditingController controller;
  final String hintText;
  final IconData icon;
  final bool obscureText;
  final TextInputType? keyboardType;
  final Iterable<String>? autofillHints;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onFieldSubmitted;
  final Widget? suffix;
  final FormFieldValidator<String>? validator;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Text(label, style: text.titleMedium),
            const Spacer(),
            if (trailingLabel != null)
              Text(trailingLabel!, style: text.bodySmall?.copyWith(color: AppColors.muted)),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        TextFormField(
          controller: controller,
          obscureText: obscureText,
          keyboardType: keyboardType,
          autofillHints: autofillHints,
          textInputAction: textInputAction,
          onFieldSubmitted: onFieldSubmitted,
          validator: validator,
          decoration: InputDecoration(
            hintText: hintText,
            prefixIcon: Icon(icon, color: AppColors.primary),
            suffixIcon: suffix,
          ),
        ),
        if (helper != null) ...[
          SizedBox(height: tokens.spaceXs),
          Row(
            children: [
              const Icon(Icons.info_outline, size: 14, color: AppColors.muted),
              SizedBox(width: tokens.spaceXs),
              Text(helper!, style: text.bodySmall?.copyWith(color: AppColors.muted)),
            ],
          ),
        ],
      ],
    );
  }
}

class _PrivacyChip extends StatelessWidget {
  const _PrivacyChip();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Align(
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: const ShapeDecoration(color: Colors.white, shape: StadiumBorder()),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.shield_outlined, size: 16, color: AppColors.primary),
            const SizedBox(width: 6),
            Text('PRIVACY EERST', style: text.labelSmall?.copyWith(color: AppColors.primary)),
          ],
        ),
      ),
    );
  }
}

class _LogoTile extends StatelessWidget {
  const _LogoTile();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 64,
        height: 64,
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        ),
        child: const Icon(Icons.home_rounded, color: Colors.white, size: 34),
      ),
    );
  }
}

class _PrivacyNote extends StatelessWidget {
  const _PrivacyNote();

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Container(
      padding: EdgeInsets.all(tokens.spaceMd),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.verified_user_outlined, color: AppColors.primary),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Alleen voor genodigden', style: text.titleMedium),
                SizedBox(height: tokens.spaceXs),
                Text(
                  'Jouw locatiegegevens worden nooit verkocht of gedeeld buiten je gezinskring.',
                  style: text.bodyMedium?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
