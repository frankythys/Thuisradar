import '../../../core/utils/startup_diagnostics.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../application/auth_providers.dart';
import '../data/pin_lock.dart';
import '../../../l10n/l10n.dart';

/// Bedekt de volledige navigator, ook als een profiel/detailpagina open staat.
/// De sessie en achtergrondlocatie blijven actief terwijl de UI vergrendeld is.
class AppPinLock extends ConsumerWidget {
  const AppPinLock({super.key, required this.child, required this.onSignedOut});
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
      return Material(child: Center(child: Text(context.l10n.authSessionFailed)));
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
  final _pin = TextEditingController();
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
    _pin.dispose();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Vergrendel de toegangscode bij terugkeer uit de achtergrond.
    if (state == AppLifecycleState.paused && !_busy) {
      _pin.clear();
      setState(() => _locked = true);
    }
  }

  Future<void> _unlockPin() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _message = null;
    });
    try {
      final accepted = await ref.read(pinLockProvider).verify(widget.userId, _pin.text);
      _pin.clear();
      if (mounted) {
        setState(() {
          _locked = !accepted;
          _message = accepted ? null : context.l10n.authPinWrong;
        });
      }
    } catch (error) {
      if (mounted) {
        setState(
          () => _message = switch (error) {
            PinLockError(kind: PinLockErrorKind.busy) => context.l10n.authPinBusy,
            PinLockError(kind: PinLockErrorKind.notSet) => context.l10n.authPinNotSet,
            PinLockError(kind: PinLockErrorKind.tooManyAttempts, :final waitSeconds) =>
              context.l10n.authPinTooMany(waitSeconds),
            _ => context.l10n.authPinCheckFailed,
          },
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
    final container = ProviderScope.containerOf(context);
    try {
      // Alleen aanmelden via Google/wachtwoord biedt een alternatief voor de scan.
      await auth.signOut();
      widget.onSignedOut();
      await container.read(pinLockProvider).disable(widget.userId);
      container.invalidate(pinEnabledProvider(widget.userId));
    } catch (_) {
      if (mounted) setState(() => _message = context.l10n.authReloginFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    ref.listen(pinLockRequestProvider, (previous, next) {
      if (previous != next) {
        _pin.clear();
        setState(() => _locked = true);
      }
    });
    final preference = ref.watch(appLockEnabledProvider(widget.userId));
    final pinEnabled = ref.watch(pinEnabledProvider(widget.userId));
    final blocked = preference.isLoading || preference.hasError || (preference.value == true && _locked);
    // Meetpunt: vanaf hier is de app zichtbaar (met vergrendeling: na de pincode).
    if (!blocked) ref.read(startupDiagnosticsProvider)?.checkpointOnce('app zichtbaar (ontgrendeld)');
    return Stack(
      fit: StackFit.expand,
      children: [
        Offstage(
          offstage: blocked,
          child: TickerMode(enabled: !blocked, child: widget.child),
        ),
        if (blocked)
          Overlay.wrap(
            child: Material(
              color: Theme.of(context).scaffoldBackgroundColor,
              child: SafeArea(
                child: Center(
                  child: SingleChildScrollView(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            context.l10n.authUnlockTitle,
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                          const SizedBox(height: 24),
                          if (preference.isLoading)
                            const CircularProgressIndicator()
                          else ...[
                            if (pinEnabled.value == true) ...[
                              const SizedBox(height: 20),
                              TextField(
                                controller: _pin,
                                enabled: !_busy,
                                obscureText: true,
                                enableInteractiveSelection: false,
                                keyboardType: TextInputType.number,
                                maxLength: 6,
                                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                                decoration: InputDecoration(
                                  labelText: context.l10n.pinTitle,
                                  counterText: '',
                                ),
                                onSubmitted: (_) => _unlockPin(),
                              ),
                              const SizedBox(height: 12),
                              FilledButton(
                                onPressed: _busy ? null : _unlockPin,
                                child: Text(context.l10n.authUnlock),
                              ),
                            ],
                            const SizedBox(height: 16),
                            Text(
                              _message ??
                                  (preference.hasError
                                      ? context.l10n.authLockLoadFailed
                                      : context.l10n.authUnlockToContinue),
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 16),
                            if (preference.hasError)
                              TextButton(
                                onPressed: () => ref.invalidate(appLockEnabledProvider(widget.userId)),
                                child: Text(context.l10n.commonTryAgain),
                              ),
                            TextButton(
                              onPressed: _busy ? null : _signOut,
                              child: Text(context.l10n.authSignInAgain),
                            ),
                          ],
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}
