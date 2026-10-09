import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Signaal "haal alles opnieuw vers op": verstuurd als de app terug op de
/// voorgrond komt en bij de knop Verversen. Realtime-stromen luisteren hierop
/// (zie `resilientStream`) en openen zich dan opnieuw, zonder laadscherm.
class ResyncSignal {
  final _controller = StreamController<void>.broadcast();

  Stream<void> get stream => _controller.stream;

  void notify() {
    if (!_controller.isClosed) _controller.add(null);
  }

  Future<void> dispose() => _controller.close();
}

final resyncSignalProvider = Provider<ResyncSignal>((ref) {
  final signal = ResyncSignal();
  ref.onDispose(signal.dispose);
  return signal;
});
