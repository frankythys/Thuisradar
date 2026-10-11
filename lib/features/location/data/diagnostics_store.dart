import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// Waar het diagnoselogboek zijn regels naartoe schrijft.
abstract interface class DiagnosticsSink {
  Future<void> append(List<String> lines);
}

/// Bewaart het locatie-diagnoselogboek lokaal in een tekstbestand, zodat het
/// ook bruikbaar blijft wanneer uploaden naar de server mislukt.
class DiagnosticsStore implements DiagnosticsSink {
  DiagnosticsStore({Future<Directory> Function()? directory})
    : _directory = directory ?? getApplicationSupportDirectory;

  /// Boven deze grootte houden we enkel de laatste [_keepLines] regels.
  static const _maxBytes = 1024 * 1024;
  static const _keepLines = 6000;

  final Future<Directory> Function() _directory;

  Future<File> file() async => File('${(await _directory()).path}/locatie_diagnose.log');

  @override
  Future<void> append(List<String> lines) async {
    if (lines.isEmpty) return;
    final target = await file();
    await target.writeAsString('${lines.join('\n')}\n', mode: FileMode.append, flush: true);
    if (await target.length() > _maxBytes) {
      final all = await target.readAsLines();
      await target.writeAsString(
        '${all.skip(all.length > _keepLines ? all.length - _keepLines : 0).join('\n')}\n',
        flush: true,
      );
    }
  }
}
