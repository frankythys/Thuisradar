import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../application/auth_providers.dart';

/// Na de link uit "Wachtwoord vergeten": de gebruiker is al aangemeld (de link
/// geldt als login) en kiest hier een nieuw wachtwoord. "Later" laat het oude
/// wachtwoord staan en gaat gewoon verder naar de app.
class NewPasswordScreen extends ConsumerStatefulWidget {
  const NewPasswordScreen({super.key});

  @override
  ConsumerState<NewPasswordScreen> createState() => _NewPasswordScreenState();
}

class _NewPasswordScreenState extends ConsumerState<NewPasswordScreen> {
  final _formKey = GlobalKey<FormState>();
  final _password = TextEditingController();
  final _repeat = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_formKey.currentState!.validate()) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).updatePassword(_password.text);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(l10n.authNewPasswordSaved)));
      ref.read(passwordRecoveryProvider.notifier).finish();
    } on AuthWeakPasswordException {
      setState(() => _error = l10n.authPasswordWeak);
    } on AuthException catch (error) {
      setState(
        () => _error = error.code == ErrorCode.samePassword.code
            ? l10n.authNewPasswordSame
            : l10n.authNewPasswordFailed,
      );
    } on Exception catch (error) {
      debugPrint('Nieuw wachtwoord opslaan mislukt: $error');
      setState(() => _error = l10n.authNewPasswordFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Scaffold(
      appBar: BrandedAppBar(title: l10n.authNewPasswordTitle),
      body: SafeArea(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: EdgeInsets.all(tokens.spaceMd),
            children: [
              Text(l10n.authNewPasswordIntro, style: Theme.of(context).textTheme.bodyMedium),
              SizedBox(height: tokens.spaceMd),
              TextFormField(
                controller: _password,
                obscureText: true,
                autofillHints: const [AutofillHints.newPassword],
                decoration: InputDecoration(
                  labelText: l10n.authNewPasswordField,
                  helperText: l10n.authPasswordHelper,
                  helperMaxLines: 2,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                ),
                validator: (value) => value == null || value.length < 8 ? l10n.authPasswordTooShort : null,
              ),
              SizedBox(height: tokens.spaceSm),
              TextFormField(
                controller: _repeat,
                obscureText: true,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _save(),
                decoration: InputDecoration(
                  labelText: l10n.authNewPasswordRepeat,
                  prefixIcon: const Icon(Icons.lock_outline, color: AppColors.primary),
                ),
                validator: (value) => value == _password.text ? null : l10n.authNewPasswordMismatch,
              ),
              if (_error != null) ...[
                SizedBox(height: tokens.spaceSm),
                Text(_error!, style: const TextStyle(color: AppColors.alert)),
              ],
              SizedBox(height: tokens.spaceMd),
              FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.authNewPasswordSave)),
              TextButton(
                onPressed: _busy ? null : ref.read(passwordRecoveryProvider.notifier).finish,
                child: Text(l10n.authNewPasswordLater),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
