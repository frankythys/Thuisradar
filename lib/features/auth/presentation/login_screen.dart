import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/radar_logo.dart';
import '../application/auth_providers.dart';
import '../data/biometric_login.dart';

part 'login_screen_actions.dart';
part 'login_screen_field.dart';
part 'login_screen_header.dart';
part 'login_screen_privacy_chip.dart';
part 'login_screen_privacy_note.dart';

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
  bool _remember = true;
  bool _loadingSaved = true;
  String? _message;

  @override
  void initState() {
    super.initState();
    _restoreLogin();
  }

  Future<void> _restoreLogin() async {
    try {
      final saved = await ref.read(biometricLoginProvider).rememberedLogin();
      if (!mounted) return;
      // A late storage response must not overwrite the user's typing.
      if (saved != null && _email.text.isEmpty && _password.text.isEmpty) {
        _email.text = saved['email']!;
        _password.text = saved['password']!;
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'Opgeslagen inloggegevens konden niet worden geladen. Vul ze opnieuw in.');
      }
    } finally {
      if (mounted) setState(() => _loadingSaved = false);
    }
  }

  Future<void> _setRemember(bool value) async {
    setState(() {
      _remember = value;
      _busy = true;
    });
    try {
      if (!value) {
        await ref.read(biometricLoginProvider).forgetRememberedLogin();
      }
    } catch (_) {
      if (mounted) {
        setState(() => _message = 'De opgeslagen login kon niet worden verwijderd. Probeer opnieuw.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

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
    final service = ref.read(biometricLoginProvider);
    final email = _email.text.trim();
    final password = _password.text;
    final remember = _remember;
    try {
      if (_mode == _Mode.login) {
        await auth.signIn(email: email, password: password);
        await service.rememberSuccessfulLogin(email: email, password: password, remember: remember);
        // Laat Android/Chrome z'n eigen "Wachtwoord opslaan?"-popup tonen.
        TextInput.finishAutofillContext();
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
    } catch (_) {
      if (mounted) {
        setState(
          () => _message = 'Inloggen of het onthouden van je gegevens is niet gelukt. Probeer opnieuw.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _toggleMode() => setState(() {
    _mode = _mode == _Mode.login ? _Mode.register : _Mode.login;
    _message = null;
  });

  Future<void> _resetPassword() async {
    if (!_email.text.contains('@')) {
      setState(() => _message = 'Vul eerst je e-mailadres in.');
      return;
    }
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text.trim());
      if (mounted) {
        setState(() => _message = 'Controleer je e-mail om je wachtwoord opnieuw in te stellen.');
      }
    } on Exception {
      if (mounted) {
        setState(() => _message = 'De herstelmail kon niet worden verstuurd. Probeer opnieuw.');
      }
    }
  }

  Future<void> _biometric() async {
    if (_busy) return;
    setState(() => _busy = true);
    final service = ref.read(biometricLoginProvider);
    final auth = ref.read(authRepositoryProvider);
    try {
      final enabled = await service.enabled;
      if (!mounted) return;
      if (!enabled) {
        if (!_formKey.currentState!.validate()) return;
        final allow = await showDialog<bool>(
          context: context,
          builder: (context) => AlertDialog(
            title: const Text('Biometrie inschakelen'),
            content: const Text(
              'Bewaar je login versleuteld op dit toestel om voortaan met je vingerafdruk of gezicht in te loggen. Je kunt dit verwijderen in je profiel.',
            ),
            actions: [
              TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
              FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Inschakelen')),
            ],
          ),
        );
        if (allow != true || !mounted) return;
      }
      setState(() {
        _busy = true;
        _message = null;
      });
      await service.signIn(auth, email: _email.text.trim(), password: _password.text, remember: _remember);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is StateError
              ? error.message.toString()
              : 'Biometrisch inloggen lukt niet. Gebruik je e-mailadres en wachtwoord.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _Mode.register;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          // Minstens schermhoog, zodat de knoppen onderaan staan; scrollt alleen
          // als het toetsenbord of een klein scherm de ruimte opeist.
          builder: (context, constraints) => SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceMd, tokens.spaceLg, tokens.spaceLg),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight - tokens.spaceMd - tokens.spaceLg),
              child: IntrinsicHeight(
                child: Form(
                  key: _formKey,
                  child: AutofillGroup(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _LoginHeader(onBack: isRegister ? _toggleMode : null),
                        SizedBox(height: tokens.spaceXl),
                        // Zet het formulier iets onder het midden, dicht bij de duim.
                        const Spacer(),
                        Text(isRegister ? 'Maak je account' : 'Welkom terug', style: text.headlineLarge),
                        SizedBox(height: tokens.spaceXs),
                        Text(
                          isRegister
                              ? 'Een veilige en besloten cirkel voor jouw gezin.'
                              : 'Log in om te zien waar je gezin is.',
                          style: text.bodyMedium?.copyWith(color: AppColors.muted),
                        ),
                        SizedBox(height: tokens.spaceLg),
                        if (isRegister) ...[
                          _Field(
                            label: 'Naam',
                            helper: 'Zo zien je gezinsleden je, bv. Papa',
                            controller: _name,
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Vul een naam in' : null,
                          ),
                          SizedBox(height: tokens.spaceMd),
                        ],
                        _Field(
                          label: 'E-mailadres',
                          controller: _email,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || !v.contains('@') ? 'Ongeldig e-mailadres' : null,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _Field(
                          label: 'Wachtwoord',
                          helper: isRegister ? 'Minimaal 8 tekens' : null,
                          controller: _password,
                          icon: Icons.lock_outline,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            tooltip: _obscure ? 'Wachtwoord tonen' : 'Wachtwoord verbergen',
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                          validator: (v) => v == null || v.length < 8 ? 'Minstens 8 tekens' : null,
                        ),
                        if (!isRegister)
                          _RememberRow(
                            value: _remember,
                            onChanged: _busy || _loadingSaved
                                ? null
                                : (value) => _setRemember(value ?? false),
                            onForgot: _busy ? null : _resetPassword,
                          ),
                        if (_message != null)
                          Padding(
                            padding: EdgeInsets.only(top: tokens.spaceSm),
                            child: Text(_message!, style: text.bodyMedium?.copyWith(color: AppColors.alert)),
                          ),
                        if (isRegister) ...[SizedBox(height: tokens.spaceLg), const _PrivacyNote()],
                        const Spacer(),
                        SizedBox(height: tokens.spaceXl),
                        _LoginActions(
                          label: isRegister ? 'Account aanmaken' : 'Inloggen',
                          busy: _busy,
                          onSubmit: _submit,
                          onBiometric: isRegister ? null : _biometric,
                        ),
                        SizedBox(height: tokens.spaceSm),
                        TextButton(
                          onPressed: _busy ? null : _toggleMode,
                          child: Text(isRegister ? 'Ik heb al een account' : 'Nieuw? Maak een account'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
