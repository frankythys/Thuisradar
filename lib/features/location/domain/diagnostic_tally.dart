import 'motion_filter.dart';

/// Telt per levensteken-periode waar elke GPS-meting eindigde:
/// ontvangen → aanvaard of geweigerd (met reden) → overgeslagen of geüpload.
///
/// Elke [summary] wordt één regel in het diagnoselogboek en zet de tellers
/// terug op nul. Ook een regel met enkel nullen telt: dan leefde de app wel,
/// maar kwam er geen meting binnen.
class DiagnosticTally {
  int received = 0;
  int accepted = 0;
  int throttled = 0;
  int uploadOk = 0;
  int uploadFailed = 0;

  /// Punten die nog wachten op een upload; wordt niet op nul gezet.
  int pending = 0;
  final Map<RejectReason, int> _rejected = {};
  double? _worstRejectedAccuracy;
  DateTime? _lastReceivedAt;
  DateTime? _lastUploadAt;

  void onReceived(DateTime at) {
    received++;
    _lastReceivedAt = at;
  }

  void onAccepted() => accepted++;

  void onRejected(RejectReason reason, double? accuracyMeters) {
    _rejected[reason] = (_rejected[reason] ?? 0) + 1;
    if (reason == RejectReason.inaccurate && accuracyMeters != null) {
      final worst = _worstRejectedAccuracy;
      if (worst == null || accuracyMeters > worst) _worstRejectedAccuracy = accuracyMeters;
    }
  }

  void onThrottled() => throttled++;

  void onUploadOk(DateTime at) {
    uploadOk++;
    _lastUploadAt = at;
  }

  void onUploadFailed() => uploadFailed++;

  int get rejected => _rejected.values.fold(0, (sum, count) => sum + count);

  /// Eén regel met de tellers sinds de vorige samenvatting; zet ze daarna op nul.
  String summary(DateTime now) {
    final reasons = [
      for (final reason in RejectReason.values)
        if (_rejected[reason] case final count?)
          reason == RejectReason.inaccurate && _worstRejectedAccuracy != null
              ? '${reason.label} $count (max ${_worstRejectedAccuracy!.round()} m)'
              : '${reason.label} $count',
    ];
    final line = StringBuffer(
      'ontvangen $received · aanvaard $accepted · geweigerd $rejected'
      '${reasons.isEmpty ? '' : ' [${reasons.join(', ')}]'}'
      ' · overgeslagen $throttled · upload ok $uploadOk · upload mislukt $uploadFailed'
      ' · laatste GPS ${_ago(_lastReceivedAt, now)} · laatste upload ${_ago(_lastUploadAt, now)}'
      '${pending > 0 ? ' · wachtrij $pending' : ''}',
    );
    received = accepted = throttled = uploadOk = uploadFailed = 0;
    _rejected.clear();
    _worstRejectedAccuracy = null;
    return line.toString();
  }

  static String _ago(DateTime? at, DateTime now) =>
      at == null ? 'nooit' : '${now.difference(at).inSeconds} s geleden';
}

/// Tijdstempel voor een logboekregel: lokale tijd, tot op de seconde.
String diagnosticTimestamp(DateTime at) {
  String two(int value) => value.toString().padLeft(2, '0');
  final local = at.toLocal();
  return '${local.year}-${two(local.month)}-${two(local.day)} '
      '${two(local.hour)}:${two(local.minute)}:${two(local.second)}';
}
