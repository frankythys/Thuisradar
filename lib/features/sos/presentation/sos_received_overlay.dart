import '../application/sos_providers.dart';
import '../../family/application/family_providers.dart';
import '../../location/application/location_providers.dart';
import '../../../shared/widgets/contact_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/location_preview.dart';
import '../../../shared/widgets/app_card.dart';

import 'package:url_launcher/url_launcher.dart';

import '../../auth/application/auth_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../domain/sos_alert.dart';

/// Scherm 18: volledig-scherm alarm bij de andere gezinsleden wanneer iemand SOS stuurt.
class SosReceivedOverlay extends ConsumerStatefulWidget {
  const SosReceivedOverlay({
    super.key,
    required this.alert,
    required this.name,
    required this.onShowOnMap,
    required this.onDismiss,
  });

  final SosAlert alert;
  final String name;
  final VoidCallback onShowOnMap;
  final VoidCallback onDismiss;

  @override
  ConsumerState<SosReceivedOverlay> createState() => _SosReceivedState();
}

class _SosReceivedState extends ConsumerState<SosReceivedOverlay> {
  SosAlert get alert => widget.alert;
  String get name => widget.name;
  VoidCallback get onShowOnMap => widget.onShowOnMap;
  VoidCallback get onDismiss => widget.onDismiss;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final id = ref.read(currentUserIdProvider);
      if (id == null || id == alert.userId) return;
      try {
        await ref.read(sosRepositoryProvider).acknowledge(alert.id, id);
      } catch (_) {}
    });
  }

  @override
  Widget build(BuildContext context) {
    final members = ref.watch(familyMembersProvider(alert.familyId)).value ?? const [];
    final sender = members.where((m) => m.userId == alert.userId).firstOrNull;
    final location = (ref.watch(familyLocationsProvider(alert.familyId)).value ?? const [])
        .where((l) => l.userId == alert.userId)
        .firstOrNull;
    final receipts = ref.watch(sosReceiptsProvider(alert.id)).value ?? const [];
    final latitude = location?.latitude ?? alert.latitude;
    final longitude = location?.longitude ?? alert.longitude;
    final text = Theme.of(context).textTheme;
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    return Material(
      color: AppColors.ground,
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Container(
              padding: const EdgeInsets.all(20),
              decoration: BoxDecoration(
                color: const Color(0xFFFFDAD6),
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '⚠ NOODSITUATIE · NU ACTIEF',
                    style: TextStyle(color: Color(0xFFBA1A1A), fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    '$name heeft hulp nodig',
                    style: text.headlineLarge?.copyWith(color: const Color(0xFF93000A)),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      Chip(label: Text('Zojuist geactiveerd · ${formatClock(alert.createdAt)}')),
                      Chip(
                        label: Text(
                          location == null
                              ? 'Locatie bij alarm'
                              : 'GPS · ${formatRelative(location.updatedAt, now: now)}',
                        ),
                      ),
                      if (location?.battery != null) Chip(label: Text('${location!.battery}%')),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),
            LocationPreview(
              latitude: latitude,
              longitude: longitude,
              initial: name.isEmpty ? '?' : name.substring(0, 1),
              height: 290,
            ),
            const SizedBox(height: 12),
            AppCard(
              child: Row(
                children: [
                  const CircleAvatar(
                    backgroundColor: AppColors.primary,
                    child: Icon(Icons.near_me, color: Colors.white),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${latitude.toStringAsFixed(5)}, ${longitude.toStringAsFixed(5)}',
                          style: text.titleMedium,
                        ),
                        Text(
                          'Locatie gedeeld ${formatRelative(alert.createdAt, now: now)}',
                          style: text.bodySmall,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 22),
            FilledButton.icon(
              onPressed: () => openDirections(context, latitude, longitude),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigeer nu direct erheen'),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: sender == null ? null : () => callMember(context, sender),
                    icon: const Icon(Icons.call_outlined),
                    label: Text('Bel $name'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFB8ECDD),
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () async {
                      final userId = ref.read(currentUserIdProvider);
                      if (userId == null) return;
                      try {
                        await ref.read(sosRepositoryProvider).acknowledge(alert.id, userId, onTheWay: true);
                        await ref
                            .read(chatRepositoryProvider)
                            .send(
                              familyId: alert.familyId,
                              userId: userId,
                              body: 'Ik ben onderweg om $name te helpen.',
                            );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Je gezin weet dat je onderweg bent.')),
                          );
                        }
                      } on Exception {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Bericht niet verstuurd. Probeer opnieuw.')),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.directions_walk),
                    label: const Text('Ben onderweg'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            TextButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
              icon: const Icon(Icons.emergency, color: Color(0xFFBA1A1A)),
              label: const Text(
                'Noodcentrales contacteren (112)',
                style: TextStyle(color: Color(0xFFBA1A1A)),
              ),
            ),
            const SizedBox(height: 20),
            for (final receipt in receipts)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: AppCard(
                  child: Text(
                    '${members.where((m) => m.userId == receipt["user_id"]).firstOrNull?.displayName ?? "Gezinslid"} · ${receipt["on_the_way"] == true ? "is onderweg" : "heeft de melding geopend"}',
                  ),
                ),
              ),
            TextButton.icon(
              onPressed: onShowOnMap,
              icon: const Icon(Icons.map_outlined),
              label: const Text('Toon op kaart'),
            ),
            AppCard(
              child: Row(
                children: [
                  const Icon(Icons.info_outline, color: AppColors.primary),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Blijf bereikbaar voor je gezin. Open de kaart voor de laatst gedeelde locatie.',
                      style: text.bodyMedium,
                    ),
                  ),
                ],
              ),
            ),
            TextButton(onPressed: onDismiss, child: const Text('Sluiten')),
          ],
        ),
      ),
    );
  }
}
