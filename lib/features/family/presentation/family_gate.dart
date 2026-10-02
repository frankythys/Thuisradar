import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/error_view.dart';
import '../../map/presentation/map_screen.dart';
import '../application/family_providers.dart';
import 'family_setup_screen.dart';

/// Toont de familie-instelling zolang de gebruiker nog geen familie heeft.
class FamilyGate extends ConsumerWidget {
  const FamilyGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ref
        .watch(myFamilyProvider)
        .when(
          data: (family) => family == null ? const FamilySetupScreen() : MapScreen(family: family),
          loading: () => const Scaffold(body: Center(child: CircularProgressIndicator())),
          error: (error, _) => Scaffold(
            body: ErrorView(
              message: 'Familie laden mislukt.\n$error',
              onRetry: () => ref.invalidate(myFamilyProvider),
            ),
          ),
        );
  }
}
