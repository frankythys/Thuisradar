import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/auth/application/auth_providers.dart';
import 'push_providers.dart';

/// Initialiseert push bij het opstarten en registreert/verwijdert het FCM-token
/// wanneer de gebruiker in- of uitlogt. Toont gewoon [child].
class PushGate extends ConsumerStatefulWidget {
  const PushGate({super.key, required this.child});

  final Widget child;

  @override
  ConsumerState<PushGate> createState() => _PushGateState();
}

class _PushGateState extends ConsumerState<PushGate> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(pushServiceProvider).init();
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(currentUserIdProvider, (previous, next) {
      final service = ref.read(pushServiceProvider);
      if (next != null) {
        service.registerFor(next);
      } else if (previous != null) {
        service.unregister();
      }
    });
    return widget.child;
  }
}
