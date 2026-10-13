import 'member_location.dart';

/// Locaties die nog naar de server moeten, bv. omdat er even geen internet
/// was. Puur: geen Flutter of Supabase.
///
/// - Altijd de oudste eerst versturen: zo eindigt de kaart op de nieuwste
///   plek, ook zonder de volgorde-bewaking van migratie 016, en komt elk
///   gemist punt in de geschiedenis.
/// - Begrensd tot [capacity]: wordt de rij te lang, dan valt elk tweede oude
///   punt weg (het spoor wordt grover, nooit afgekapt), het nieuwste blijft.
/// - Na een mislukte poging wachten we steeds langer ([retryDelay]), zodat er
///   zonder netwerk niet elke 5 s een vergeefse poging is.
class PendingUploads {
  PendingUploads({this.capacity = 120});

  final int capacity;
  final _items = <MemberLocation>[];
  int _failures = 0;

  bool get isEmpty => _items.isEmpty;
  int get length => _items.length;

  /// Opeenvolgende mislukte pogingen sinds de laatste gelukte.
  int get failures => _failures;

  /// Het volgende punt om te versturen: het oudste.
  MemberLocation? get next => _items.isEmpty ? null : _items.first;

  void add(MemberLocation location) {
    final at = location.updatedAt;
    _items.removeWhere((item) => item.updatedAt == at);
    final index = _items.indexWhere((item) => item.updatedAt.isAfter(at));
    _items.insert(index < 0 ? _items.length : index, location);
    if (_items.length > capacity) _thin();
  }

  /// Het oudste punt is aangekomen (of door de server geweigerd: dan heeft
  /// opnieuw proberen geen zin).
  void sent() {
    if (_items.isNotEmpty) _items.removeAt(0);
    _failures = 0;
  }

  /// Een poging mislukte (geen netwerk, time-out): geeft terug hoe lang te
  /// wachten voor de volgende poging.
  Duration failed() {
    _failures++;
    return retryDelay(_failures);
  }

  void clear() {
    _items.clear();
    _failures = 0;
  }

  /// Wachttijd na [failures] mislukte pogingen: 5 s, 10 s, 20 s, dan 30 s.
  static Duration retryDelay(int failures) {
    const steps = [5, 10, 20, 30];
    return Duration(seconds: steps[(failures - 1).clamp(0, steps.length - 1)]);
  }

  /// Elk tweede punt van de oudste helft weg; het nieuwste blijft altijd.
  void _thin() {
    final half = _items.length ~/ 2;
    final kept = [
      for (final (index, item) in _items.indexed)
        if (index >= half || index.isEven) item,
    ];
    _items
      ..clear()
      ..addAll(kept);
  }
}
