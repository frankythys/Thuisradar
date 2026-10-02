import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_view.dart';
import '../../family/presentation/family_gate.dart';
import '../application/auth_providers.dart';
import 'login_screen.dart';

/// Toont het loginscherm of de app, afhankelijk van de sessie.
class AuthGate extends ConsumerWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(sessionProvider)
        .when(
          data: (session) => session == null ? const LoginScreen() : const FamilyGate(),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(body: ErrorView(message: '$error')),
        );
  }
}
