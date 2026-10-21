import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_view.dart';
import '../../family/presentation/family_gate.dart';
import '../application/auth_providers.dart';
import 'login_screen.dart';
import 'new_password_screen.dart';

/// Toont het loginscherm of de app, afhankelijk van de sessie. Kwam iemand
/// binnen via de link uit "Wachtwoord vergeten", dan eerst Nieuw wachtwoord.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final recovering = ref.watch(passwordRecoveryProvider);
    return ref
        .watch(sessionProvider)
        .when(
          data: (session) => session == null
              ? const LoginScreen()
              : recovering
              ? const NewPasswordScreen()
              : const FamilyGate(),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: ErrorView(message: '$error')),
        );
  }
}
