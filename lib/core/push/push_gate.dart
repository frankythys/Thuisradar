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
  Future<void> _pending = Future.value();

  @override
  void initState() {
    super.initState();
    final service = ref.read(pushServiceProvider);
    _pending = service.init();
    // Also register a session that was already restored before this gate mounted.
    // Serialize changes so a slow logout cannot delete the next account's token.
    ref.listenManual(currentUserIdProvider, (previous, next) {
      _pending = _pending
          .then((_) async {
            if (!mounted) return;
            if (next != null) {
              await service.registerFor(next);
            } else if (previous != null) {
              await service.unregister();
            }
          })
          .catchError((Object error) {
            debugPrint('Pushregistratie mislukt: $error');
          });
    }, fireImmediately: true);
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
