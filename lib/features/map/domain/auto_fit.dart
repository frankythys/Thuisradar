/// Beslist of de kaart automatisch passend gemaakt mag worden.
///
/// Regels: hoogstens één keer automatisch fitten; zodra de gebruiker zelf
/// zoomt/verschuift ([lock]) nooit meer automatisch; een bewuste actie
/// (centreerknop) mag altijd ([deliberate]).
class AutoFitController {
  bool _hasFitted = false;
  bool _locked = false;

  bool get hasFitted => _hasFitted;
  bool get isLocked => _locked;

  /// De gebruiker heeft zelf gezoomd/verschoven: geen auto-fit meer.
  void lock() => _locked = true;

  void markFitted() => _hasFitted = true;

  bool shouldFit({required bool mapReady, required bool hasPoints, bool deliberate = false}) {
    if (!mapReady || !hasPoints) return false;
    if (deliberate) return true;
    return !_hasFitted && !_locked;
  }
}
