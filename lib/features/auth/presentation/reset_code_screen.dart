import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../application/auth_providers.dart';

/// Na "Wachtwoord vergeten": de code uit de herstelmail intypen. Werkt waar je
/// de mail ook leest (ook op een pc), en een linkscanner van de mailprovider
/// kan een code niet opgebruiken. De knop in de mail blijft werken op de gsm;
/// komt die binnen, dan sluit dit scherm vanzelf. Na een geldige code toont
/// AuthGate "Nieuw wachtwoord" (zelfde herstel-event als de link).
class ResetCodeScreen extends ConsumerStatefulWidget {
  const ResetCodeScreen({super.key, required this.email});

  final String email;

  @override
  ConsumerState<ResetCodeScreen> createState() => _ResetCodeScreenState();
}

class _ResetCodeScreenState extends ConsumerState<ResetCodeScreen> {
  final _code = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    final code = _code.text.trim();
    if (_busy || code.length < 6) return;
    final l10n = context.l10n;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await ref.read(authRepositoryProvider).verifyRecoveryCode(email: widget.email, code: code);
      // Het herstel-event sluit dit scherm (zie build).
    } on AuthException catch (error) {
      debugPrint('Herstelcode geweigerd: ${error.code}');
      if (mounted) setState(() => _error = l10n.authResetCodeInvalid);
    } on Exception catch (error) {
      debugPrint('Herstelcode controleren mislukt: $error');
      if (mounted) setState(() => _error = l10n.authResetCodeFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(passwordRecoveryProvider, (_, recovering) {
      if (recovering) Navigator.of(context).popUntil((route) => route.isFirst);
    });
    final tokens = context.tokens;
    final l10n = context.l10n;
    return Scaffold(
      appBar: BrandedAppBar(title: l10n.authResetCodeTitle),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceMd),
          children: [
            Text(l10n.authResetCodeIntro(widget.email), style: Theme.of(context).textTheme.bodyMedium),
            SizedBox(height: tokens.spaceMd),
            TextField(
              controller: _code,
              autofocus: true,
              keyboardType: TextInputType.number,
              autofillHints: const [AutofillHints.oneTimeCode],
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(10)],
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _confirm(),
              decoration: InputDecoration(
                labelText: l10n.authResetCodeField,
                prefixIcon: const Icon(Icons.pin_outlined, color: AppColors.primary),
              ),
            ),
            if (_error != null) ...[
              SizedBox(height: tokens.spaceSm),
              Text(_error!, style: const TextStyle(color: AppColors.alert)),
            ],
            SizedBox(height: tokens.spaceMd),
            FilledButton(onPressed: _busy ? null : _confirm, child: Text(l10n.authResetCodeConfirm)),
          ],
        ),
      ),
    );
  }
}
