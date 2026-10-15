import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/radar_logo.dart';
import '../../location/application/location_diagnostics.dart';
import '../application/auth_providers.dart';
import '../data/biometric_login.dart';
import 'google_sign_in_button.dart';
import '../../../l10n/l10n.dart';

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
    // In het diagnoselogboek: een appstart zonder "delen gestart" is dan
    // meteen verklaard.
    ref.read(locationDiagnosticsProvider).event('aanmeldscherm', 'niet aangemeld, locatie delen staat uit');
    _restoreLogin();
  }

  Future<void> _restoreLogin() async {
    try {
      final email = await ref.read(biometricLoginProvider).rememberedEmail();
      if (!mounted) return;
      // A late storage response must not overwrite the user's typing.
      // Enkel het e-mailadres: het wachtwoord wordt nooit meer ingevuld.
      if (email != null && _email.text.isEmpty) _email.text = email;
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.l10n.authSavedLoadFailed);
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
        setState(() => _message = context.l10n.authSavedRemoveFailed);
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

  Future<void> _google() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      await ref.read(authRepositoryProvider).signInWithGoogle();
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.l10n.authGoogleFailed);
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
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
          setState(() => _message = context.l10n.authConfirmEmail);
        }
      }
    } on AuthException catch (e) {
      if (mounted) setState(() => _message = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _message = context.l10n.authSignInFailed);
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
      setState(() => _message = context.l10n.authEnterEmailFirst);
      return;
    }
    try {
      await ref.read(authRepositoryProvider).resetPassword(_email.text.trim());
      if (mounted) {
        setState(() => _message = context.l10n.authResetSent);
      }
    } on Exception {
      if (mounted) {
        setState(() => _message = context.l10n.authResetFailed);
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
            title: Text(context.l10n.authBiometricTitle),
            content: Text(context.l10n.authBiometricBody),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context, false),
                child: Text(context.l10n.commonCancel),
              ),
              FilledButton(
                onPressed: () => Navigator.pop(context, true),
                child: Text(context.l10n.authBiometricEnable),
              ),
            ],
          ),
        );
        if (allow != true || !mounted) return;
      }
      setState(() {
        _busy = true;
        _message = null;
      });
      await service.signIn(
        auth,
        email: _email.text.trim(),
        password: _password.text,
        remember: _remember,
        reason: context.l10n.authBiometricReason,
      );
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error) {
            BiometricLoginError(kind: BiometricLoginErrorKind.noBiometrics) => context.l10n.authBiometricNone,
            BiometricLoginError(kind: BiometricLoginErrorKind.missingCredentials) =>
              context.l10n.authBiometricMissing,
            _ => context.l10n.authBiometricFailed,
          },
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isRegister = _mode == _Mode.register;
    final l10n = context.l10n;
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Scaffold(
      body: SafeArea(
        child: LayoutBuilder(
          // Minstens schermhoog voor een gecentreerd formulier; scrollt alleen
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
                        // Verdeel vrije ruimte boven en onder het formulier.
                        const Spacer(),
                        Text(
                          isRegister ? l10n.authCreateAccountTitle : l10n.authWelcomeBack,
                          style: text.headlineLarge,
                        ),
                        SizedBox(height: tokens.spaceXs),
                        Text(
                          isRegister ? l10n.authRegisterIntro : l10n.authLoginIntro,
                          style: text.bodyMedium?.copyWith(color: AppColors.muted),
                        ),
                        SizedBox(height: tokens.spaceLg),
                        if (isRegister) ...[
                          _Field(
                            label: l10n.commonName,
                            helper: l10n.authNameHelper,
                            controller: _name,
                            icon: Icons.person_outline,
                            textInputAction: TextInputAction.next,
                            validator: (v) => v == null || v.trim().isEmpty ? l10n.authNameRequired : null,
                          ),
                          SizedBox(height: tokens.spaceMd),
                        ],
                        _Field(
                          label: l10n.authEmail,
                          controller: _email,
                          icon: Icons.mail_outline,
                          keyboardType: TextInputType.emailAddress,
                          autofillHints: const [AutofillHints.email],
                          textInputAction: TextInputAction.next,
                          validator: (v) => v == null || !v.contains('@') ? l10n.authEmailInvalid : null,
                        ),
                        SizedBox(height: tokens.spaceMd),
                        _Field(
                          label: l10n.authPassword,
                          helper: isRegister ? l10n.authPasswordHelper : null,
                          controller: _password,
                          icon: Icons.lock_outline,
                          obscureText: _obscure,
                          autofillHints: const [AutofillHints.password],
                          onFieldSubmitted: (_) => _submit(),
                          suffix: IconButton(
                            tooltip: _obscure ? l10n.authShowPassword : l10n.authHidePassword,
                            onPressed: () => setState(() => _obscure = !_obscure),
                            icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
                          ),
                          validator: (v) => v == null || v.length < 8 ? l10n.authPasswordTooShort : null,
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
                        SizedBox(height: tokens.spaceLg),
                        _LoginActions(
                          label: isRegister ? l10n.authCreateAccount : l10n.authSignIn,
                          busy: _busy,
                          onSubmit: _submit,
                        ),
                        SizedBox(height: tokens.spaceXl),
                        GoogleSignInButton(onPressed: _busy ? null : _google),
                        if (!isRegister) ...[
                          SizedBox(height: tokens.spaceXxl),
                          _BiometricButton(onPressed: _busy ? null : _biometric),
                        ],
                        SizedBox(height: tokens.spaceMd),
                        TextButton(
                          onPressed: _busy ? null : _toggleMode,
                          child: Text(isRegister ? l10n.authHaveAccount : l10n.authNewAccount),
                        ),
                        const Spacer(),
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
