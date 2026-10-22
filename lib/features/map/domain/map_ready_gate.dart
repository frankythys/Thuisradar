import 'dart:async';

/// Wanneer de Google-kaart klaar is om de gezinsleden te tekenen. Een
/// aangemaakte controller betekent nog geen afgewerkte kaart, dus normaal pas
/// na de eerste camerabeweging ([cameraIdle]). Opent de kaart al op de
/// bewaarde plek, dan beweegt de camera niet en komt die nooit: dan [fallback]
/// na het aanmaken ([created]). Anders bleven de personen weg tot je scrolde.
class MapReadyGate {
  MapReadyGate({this.fallback = const Duration(milliseconds: 700)});

  final Duration fallback;
  final _ready = Completer<void>();
  Timer? _timer;

  Future<void> get future => _ready.future;
  bool get isReady => _ready.isCompleted;

  /// De kaart is aangemaakt: wacht nog op een camerabeweging, maar niet langer
  /// dan [fallback].
  void created() => _timer ??= Timer(fallback, _complete);

  /// De camera is (voor het eerst) tot rust gekomen.
  void cameraIdle() => _complete();

  void dispose() => _timer?.cancel();

  void _complete() {
    _timer?.cancel();
    if (!_ready.isCompleted) _ready.complete();
  }
}
