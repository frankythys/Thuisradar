/// Zet de stappenteller van de laatste seconden om in "te voet" of niet.
class StepWindow {
  /// Vergelijk met een meting tussen [_minGap] en [_window] geleden.
  static const _window = Duration(seconds: 20);
  static const _minGap = Duration(seconds: 4);

  /// Zoveel stappen of meer: te voet. Zoveel of minder: niet te voet.
  static const _onFootSteps = 6;
  static const _stillSteps = 2;

  final _samples = <({DateTime at, int steps})>[];

  /// Heeft dit toestel een stappenteller (ooit een waarde gestuurd)?
  bool known = false;

  /// Te voet volgens de stappen tot [at]; null als dat nog niet te zeggen is.
  bool? onFoot(DateTime at, int? steps) {
    if (steps == null) return null;
    known = true;
    // Een lagere teller (nieuwe dag, herstart) begint opnieuw.
    _samples.removeWhere((s) => at.difference(s.at) > _window || s.steps > steps);
    final reference = _samples.where((s) => at.difference(s.at) >= _minGap).firstOrNull;
    _samples.add((at: at, steps: steps));
    if (reference == null) return null;
    final walked = steps - reference.steps;
    if (walked >= _onFootSteps) return true;
    return walked <= _stillSteps ? false : null;
  }

  void clear() {
    _samples.clear();
    known = false;
  }
}
