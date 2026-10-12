import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../data/biometric_login.dart';

/// Bedekt de volledige navigator, ook als een profiel/detailpagina open staat.
/// De sessie en achtergrondlocatie blijven actief terwijl de UI vergrendeld is.
class BiometricLock extends ConsumerWidget {
  const BiometricLock({super.key, required this.child, required this.onSignedOut});
  final Widget child;
  final VoidCallback onSignedOut;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final session = ref.watch(sessionProvider);
    final userId = session.value?.user.id;
    if (session.isLoading && userId == null) {
      return const ColoredBox(
        color: Colors.white,
        child: Center(child: CircularProgressIndicator()),
      );
    }
    if (session.hasError) {
      return const Material(child: Center(child: Text('Je sessie kon niet worden geladen. Open de app opnieuw.')));
    }
    if (userId == null) return child;
    return _SessionLock(key: ValueKey(userId), userId: userId, onSignedOut: onSignedOut, child: child);
  }
}

class _SessionLock extends ConsumerStatefulWidget {
  const _SessionLock({super.key, required this.userId, required this.child, required this.onSignedOut});
  final String userId;
  final Widget child;
  final VoidCallback onSignedOut;

  @override
  ConsumerState<_SessionLock> createState() => _SessionLockState();
}

class _SessionLockState extends ConsumerState<_SessionLock> with WidgetsBindingObserver {
  bool _locked = true;
  bool _busy = false;
  String? _message;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Een biometrisch systeemvenster mag zichzelf niet opnieuw vergrendelen.
    if (state == AppLifecycleState.paused && !_busy) {
      setState(() => _locked = true);
    }
  }

  Future<void> _unlock() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final accepted = await ref.read(biometricLoginProvider).authenticate();
      if (mounted && accepted) setState(() => _locked = false);
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = error is StateError
              ? error.message.toString()
              : 'Vingerscan lukt niet. Probeer opnieuw of log opnieuw in.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _signOut() async {
    if (_busy) return;
    setState(() => _busy = true);
    final auth = ref.read(authRepositoryProvider);
    final biometric = ref.read(biometricLoginProvider);
    final container = ProviderScope.containerOf(context);
    try {
      // Alleen aanmelden via Google/wachtwoord biedt een alternatief voor de scan.
      await auth.signOut();
      widget.onSignedOut();
      await biometric.forgetOnSignOut();
      container.invalidate(biometricEnabledProvider(widget.userId));
    } catch (_) {
      if (mounted) setState(() => _message = 'Opnieuw inloggen starten is niet gelukt. Probeer opnieuw.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final preference = ref.watch(biometricEnabledProvider(widget.userId));
    final blocked = preference.isLoading || preference.hasError || (preference.value == true && _locked);
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: blocked,
          child: TickerMode(enabled: !blocked, child: widget.child),
        ),
        if (blocked)
          Material(
            color: Theme.of(context).scaffoldBackgroundColor,
            child: SafeArea(
              child: Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('CircleBeacon ontgrendelen', style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 24),
                      if (preference.isLoading)
                        const CircularProgressIndicator()
                      else ...[
                        Semantics(
                          label: 'Ontgrendelen met biometrie',
                          child: IconButton.filledTonal(
                            onPressed: _busy || preference.hasError ? null : _unlock,
                            icon: const Icon(Icons.fingerprint, size: 48),
                          ),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          _message ??
                              (preference.hasError
                                  ? 'Vingerscan-instelling kon niet worden geladen.'
                                  : 'Gebruik je vingerafdruk om verder te gaan.'),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 16),
                        if (preference.hasError)
                          TextButton(
                            onPressed: () => ref.invalidate(biometricEnabledProvider(widget.userId)),
                            child: const Text('Opnieuw proberen'),
                          ),
                        TextButton(onPressed: _busy ? null : _signOut, child: const Text('Opnieuw inloggen')),
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
