import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/radar_logo.dart';
import '../application/auth_providers.dart';
import '../data/biometric_login.dart';

part 'login_screen_field.dart';
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
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
          child: Form(
            key: _formKey,
            child: AutofillGroup(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  if (isRegister)
                    Row(
                      children: [
                        IconButton(onPressed: _toggleMode, icon: const Icon(Icons.arrow_back)),
                        const Spacer(),
                        const _PrivacyChip(),
                      ],
                    ),
                  const SizedBox(height: 24),
                  const Center(child: RadarLogo(size: 64)),
                  const SizedBox(height: 12),
                  Text('CircleBeacon', style: text.titleMedium, textAlign: TextAlign.center),
                  if (!isRegister) ...[
                    const SizedBox(height: 6),
                    Text(
                      '• • VEILIG & VERTROUWD',
                      style: text.labelSmall?.copyWith(color: AppColors.primary),
                      textAlign: TextAlign.center,
                    ),
                  ],
                  const SizedBox(height: 24),
                  Container(
                    padding: EdgeInsets.all(isRegister ? 0 : 24),
                    decoration: BoxDecoration(
                      color: isRegister ? AppColors.ground : Colors.white,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          isRegister ? 'Maak je account' : 'Welkom terug',
                          style: text.headlineLarge,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          isRegister
                              ? 'Een veilige en besloten cirkel voor jouw gezin.'
                              : 'Log in om verbonden te blijven met je familie.',
                          style: text.bodyMedium?.copyWith(color: AppColors.muted),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 24),
                        if (isRegister) ...[
                          _Field(
                            label: 'Naam',
                            trailingLabel: 'Voor je gezin',
                            helper: 'Zo zien je gezinsleden je, bv. Papa',
                            controller: _name,
                            hintText: 'bv. Peter of Papa',
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().isEmpty ? 'Vul een naam in' : null,
                          ),
                          const SizedBox(height: 16),
                        ],
                        _Field(
                          label: 'E-mailadres',
                          controller: _email,
                          hintText: 'naam@voorbeeld.be',
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || !v.contains('@') ? 'Ongeldig e-mailadres' : null,
                        ),
                        const SizedBox(height: 16),
                        _Field(
                          label: 'Wachtwoord',
                          helper: isRegister ? 'Minimaal 8 tekens' : null,
                          controller: _password,
                          hintText: isRegister ? 'Minimaal 8 tekens' : '••••••••',
                          icon: Icons.lock_outline,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                          validator: (v) => v == null || v.length < 8 ? 'Minstens 8 tekens' : null,
                        ),
                        if (!isRegister)
                          Material(
                            color: Colors.transparent,
                            child: CheckboxListTile(
                              contentPadding: EdgeInsets.zero,
                              controlAffinity: ListTileControlAffinity.leading,
                              title: const Text('Inloggegevens onthouden'),
                              subtitle: const Text(
                                'E-mailadres en wachtwoord versleuteld bewaren op dit toestel.',
                              ),
                              value: _remember,
                              onChanged: _busy || _loadingSaved
                                  ? null
                                  : (value) => _setRemember(value ?? false),
                            ),
                          ),
                        if (!isRegister)
                          Align(
                            alignment: Alignment.centerRight,
                            child: TextButton(
                              onPressed: _busy ? null : _resetPassword,
                              child: const Text('Wachtwoord vergeten?'),
                            ),
                          ),
                        if (_message != null)
                          Padding(
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            child: Text(_message!, style: text.bodyMedium?.copyWith(color: AppColors.alert)),
                          ),
                        const SizedBox(height: 20),
                        if (isRegister) ...[const _PrivacyNote(), const SizedBox(height: 28)],
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
                                    const SizedBox(width: 8),
                                    const Icon(Icons.arrow_forward, size: 18),
                                  ],
                                ),
                        ),
                        if (!isRegister) ...[
                          const Padding(
                            padding: EdgeInsets.symmetric(vertical: 18),
                            child: Row(
                              children: [
                                Expanded(child: Divider()),
                                Padding(padding: EdgeInsets.symmetric(horizontal: 16), child: Text('OF')),
                                Expanded(child: Divider()),
                              ],
                            ),
                          ),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: AppColors.surfaceLow,
                              foregroundColor: AppColors.primary,
                            ),
                            onPressed: _busy ? null : _biometric,
                            icon: const Icon(Icons.fingerprint),
                            label: const Text('Inloggen met biometrie'),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextButton(
                    onPressed: _busy ? null : _toggleMode,
                    child: Text(isRegister ? 'Ik heb al een account' : 'Nieuw? Maak een account'),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.lock_outline, size: 14, color: AppColors.muted),
                      const SizedBox(width: 6),
                      Flexible(
                        child: Text(
                          'Versleuteld & alleen zichtbaar voor jouw gezin',
                          style: text.bodySmall,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Gelabeld invoerveld met leidend icoon en optionele helper-tekst.
