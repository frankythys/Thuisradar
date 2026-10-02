import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

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
    final textTheme = Theme.of(context).textTheme;

    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Thuisradar', style: textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 8),
                  Text(isRegister ? 'Maak een account aan' : 'Log in om je familie te zien'),
                  const SizedBox(height: 32),
                  if (isRegister) ...[
                    TextFormField(
                      controller: _name,
                      decoration: const InputDecoration(labelText: 'Naam (bv. Papa)'),
                      textInputAction: TextInputAction.next,
                      validator: (v) => (v == null || v.trim().isEmpty) ? 'Vul een naam in' : null,
                    ),
                    const SizedBox(height: 16),
                  ],
                  TextFormField(
                    controller: _email,
                    decoration: const InputDecoration(labelText: 'E-mailadres'),
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    textInputAction: TextInputAction.next,
                    validator: (v) => (v == null || !v.contains('@')) ? 'Ongeldig e-mailadres' : null,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    decoration: const InputDecoration(labelText: 'Wachtwoord'),
                    obscureText: true,
                    autofillHints: const [AutofillHints.password],
                    onFieldSubmitted: (_) => _submit(),
                    validator: (v) => (v == null || v.length < 8) ? 'Minstens 8 tekens' : null,
                  ),
                  if (_message != null) ...[
                    const SizedBox(height: 16),
                    Text(_message!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
                  ],
                  const SizedBox(height: 24),
                  FilledButton(
                    onPressed: _busy ? null : _submit,
                    child: _busy
                        ? const SizedBox.square(
                            dimension: 20,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          )
                        : Text(isRegister ? 'Account aanmaken' : 'Inloggen'),
                  ),
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
    );
  }
}
