import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../location/application/location_diagnostics.dart';
import 'profile_tile.dart';
import '../../../l10n/l10n.dart';

/// Deelt het lokale locatielogboek (GPS → filter → upload) als tekstbestand,
/// om gaten in de locatiegeschiedenis te onderzoeken.
class DiagnosticsExportTile extends ConsumerWidget {
  const DiagnosticsExportTile({super.key});

  Future<void> _export(BuildContext context, WidgetRef ref) async {
    final box = context.findRenderObject() as RenderBox?;
    final messenger = ScaffoldMessenger.of(context);
    final l10n = context.l10n;
    try {
      await ref.read(locationDiagnosticsProvider).flush();
      final file = await ref.read(diagnosticsStoreProvider).file();
      if (!await file.exists()) {
        messenger.showSnackBar(SnackBar(content: Text(l10n.profileDiagnosticsEmpty)));
        return;
      }
      await SharePlus.instance.share(
        ShareParams(
          files: [XFile(file.path, mimeType: 'text/plain')],
          subject: l10n.profileDiagnosticsSubject,
          sharePositionOrigin: box == null ? null : box.localToGlobal(Offset.zero) & box.size,
        ),
      );
    } catch (_) {
      messenger.showSnackBar(SnackBar(content: Text(l10n.profileExportFailed)));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) => ProfileTile(
    icon: Icons.bug_report_outlined,
    title: context.l10n.profileDiagnosticsTitle,
    subtitle: context.l10n.profileDiagnosticsSubtitle,
    onTap: () => _export(context, ref),
  );
}
