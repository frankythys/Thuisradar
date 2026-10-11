import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../location/application/location_diagnostics.dart';
import 'profile_tile.dart';

/// Deelt het lokale locatielogboek (GPS → filter → upload) als tekstbestand,
/// om gaten in de locatiegeschiedenis te onderzoeken.
class DiagnosticsExportTile extends ConsumerWidget {
  const DiagnosticsExportTile({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(locationDiagnosticsProvider).flush();
      final file = await ref.read(diagnosticsStoreProvider).file();
      if (!await file.exists()) {
        messenger.showSnackBar(const SnackBar(content: Text('Nog geen locatiediagnose opgeslagen.')));
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: 'Locatiediagnose',
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(const SnackBar(content: Text('Exporteren is niet gelukt. Probeer opnieuw.')));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProfileTile(
    icon: Icons.bug_report_outlined,
    title: 'Locatiediagnose exporteren',
    subtitle: 'Logboek van GPS, filter en upload delen',
    onTap: () => _export(context, ref),
  );
}
