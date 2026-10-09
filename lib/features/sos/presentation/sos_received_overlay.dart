import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../shared/widgets/contact_actions.dart';
import '../../../shared/widgets/location_preview.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/application/chat_providers.dart';
import '../../family/application/family_providers.dart';
import '../../location/application/location_providers.dart';
import '../application/sos_providers.dart';
import '../domain/sos_alert.dart';
import 'widgets/sos_address_line.dart';
import 'widgets/sos_received_header.dart';

/// Scherm 18: volledig-scherm alarm bij de andere gezinsleden wanneer iemand
/// SOS stuurt. Kop in de alarmkleur, kaart, adres en de acties eronder;
/// past zonder scrollen op 360 × 640.
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

  Future<void> _onTheWay() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(sosRepositoryProvider).acknowledge(alert.id, userId, onTheWay: true);
      await ref
          .read(chatRepositoryProvider)
          .send(familyId: alert.familyId, userId: userId, body: 'Ik ben onderweg om $name te helpen.');
      messenger.showSnackBar(const SnackBar(content: Text('Je gezin weet dat je onderweg bent.')));
    } on Exception {
      messenger.showSnackBar(const SnackBar(content: Text('Bericht niet verstuurd. Probeer opnieuw.')));
    }
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
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    final seen = [
      for (final receipt in receipts)
        '${members.where((m) => m.userId == receipt['user_id']).firstOrNull?.displayName ?? 'Gezinslid'} '
            '${receipt['on_the_way'] == true ? 'is onderweg' : 'heeft het gezien'}',
    ];

    return Material(
      color: AppColors.ground,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceMd),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SosReceivedHeader(
                name: name,
                createdAt: alert.createdAt,
                location: location,
                now: now,
                onClose: widget.onDismiss,
              ),
              SizedBox(height: tokens.spaceSm + tokens.spaceXs),
              Expanded(
                child: LocationPreview(
                  latitude: latitude,
                  longitude: longitude,
                  initial: name.isEmpty ? '?' : name.substring(0, 1),
                  height: double.infinity,
                ),
              ),
              SizedBox(height: tokens.spaceSm + tokens.spaceXs),
              SosAddressLine(
                familyId: alert.familyId,
                latitude: latitude,
                longitude: longitude,
                sharedAt: location?.updatedAt ?? alert.createdAt,
                now: now,
              ),
              if (seen.isNotEmpty) ...[
                SizedBox(height: tokens.spaceXs),
                Text(
                  seen.join(' · '),
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
              SizedBox(height: tokens.spaceSm + tokens.spaceXs),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => openDirections(context, latitude, longitude),
                      icon: const Icon(Icons.navigation_outlined, size: 20),
                      label: const Text('Navigeer'),
                    ),
                  ),
                  SizedBox(width: tokens.spaceSm),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: sender == null ? null : () => callMember(context, sender),
                      icon: const Icon(Icons.call_outlined, size: 20),
                      label: Text('Bel $name', maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                  ),
                ],
              ),
              SizedBox(height: tokens.spaceSm),
              FilledButton.tonalIcon(
                onPressed: _onTheWay,
                icon: const Icon(Icons.directions_walk, size: 20),
                label: const Text('Ik ben onderweg'),
              ),
              SizedBox(height: tokens.spaceXs),
              Row(
                children: [
                  Expanded(
                    child: TextButton.icon(
                      onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                      style: TextButton.styleFrom(foregroundColor: scheme.error),
                      icon: const Icon(Icons.emergency_outlined, size: 20),
                      label: const Text('Bel 112'),
                    ),
                  ),
                  Expanded(
                    child: TextButton.icon(
                      onPressed: widget.onShowOnMap,
                      icon: const Icon(Icons.map_outlined, size: 20),
                      label: const Text('Toon op kaart'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
