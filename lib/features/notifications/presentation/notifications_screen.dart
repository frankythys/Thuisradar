import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/privacy_note.dart';
import '../../auth/application/auth_providers.dart';
import '../../location/application/location_providers.dart';
import '../../../shared/widgets/location_preview.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../places/application/places_providers.dart';
import '../application/events_providers.dart';
import '../domain/family_event.dart';

/// Scherm 15: feed van aankomst, vertrek en SOS.
class NotificationsScreen extends ConsumerStatefulWidget {
  const NotificationsScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<NotificationsScreen> createState() => _NotificationsScreenState();
}

class _NotificationsScreenState extends ConsumerState<NotificationsScreen> {
  DateTime? _clearedAt;
  FamilyEventType? _filter;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final cleared = await ref.read(notificationsStoreProvider).clearedAt(widget.family.id);
      if (mounted) setState(() => _clearedAt = cleared);
    });
  }

  Future<void> _clear() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Meldingen wissen?'),
        content: const Text('Je wist je meldingen op dit toestel. Nieuwe meldingen verschijnen gewoon weer.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Wissen')),
        ],
      ),
    );
    if (confirm != true) return;

    final now = DateTime.now();
    await ref.read(notificationsStoreProvider).clear(widget.family.id, now);
    if (mounted) setState(() => _clearedAt = now);
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final events = ref.watch(familyEventsProvider(widget.family.id));
    final members = ref.watch(familyMembersProvider(widget.family.id)).value ?? const [];
    final places = ref.watch(familyPlacesProvider(widget.family.id)).value ?? const [];
    final lowBatteries = (ref.watch(familyLocationsProvider(widget.family.id)).value ?? const [])
        .where((l) => (l.battery ?? 100) <= 20 && l.isCharging != true)
        .toList();
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    String nameOf(String userId) {
      for (final m in members) {
        if (m.userId == userId) return m.displayName;
      }
      return 'Een gezinslid';
    }

    String? placeOf(String? placeId) {
      if (placeId == null) return null;
      for (final p in places) {
        if (p.id == placeId) return p.name;
      }
      return null;
    }

    final visible = [
      for (final e in events.value ?? const <FamilyEvent>[])
        if ((_clearedAt == null || e.createdAt.isAfter(_clearedAt!)) &&
            (_filter == null || e.type == _filter))
          e,
    ];

    return Scaffold(
      appBar: BrandedAppBar(
        title: 'Meldingen',
        actions: [if (visible.isNotEmpty) TextButton(onPressed: _clear, child: const Text('Wissen'))],
      ),
      body: events.when(
        data: (_) => ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            Row(
              children: [
                Expanded(child: Text('Meldingen', style: Theme.of(context).textTheme.headlineLarge)),
                TextButton.icon(
                  onPressed: () async {
                    final userId = ref.read(currentUserIdProvider);
                    if (userId != null) {
                      await ref.read(eventsRepositoryProvider).markSeen(userId, widget.family.id);
                      ref.invalidate(lastSeenProvider(widget.family.id));
                    }
                  },
                  icon: const Icon(Icons.done_all, size: 16),
                  label: const Text('Alles gelezen'),
                ),
              ],
            ),
            const Text('Recente gezinsactiviteiten en veiligheidsupdates'),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final entry in <FamilyEventType?, String>{
                  null: 'Alles',
                  FamilyEventType.arrival: 'Aankomst',
                  FamilyEventType.departure: 'Vertrek',
                  FamilyEventType.unknown: 'Batterij',
                  FamilyEventType.sos: 'SOS',
                }.entries)
                  ChoiceChip(
                    label: Text(entry.value),
                    selected: _filter == entry.key,
                    onSelected: (_) => setState(() => _filter = entry.key),
                  ),
              ],
            ),
            const SizedBox(height: 20),
            if (_filter == null || _filter == FamilyEventType.unknown)
              for (final battery in lowBatteries)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  padding: const EdgeInsets.all(18),
                  decoration: BoxDecoration(
                    color: AppColors.alertSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        children: [
                          const Icon(Icons.battery_alert, color: AppColors.alert),
                          const SizedBox(width: 10),
                          Expanded(
                            child: Text(
                              'Lage batterij: ${nameOf(battery.userId)}',
                              style: Theme.of(context).textTheme.titleMedium,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Batterijniveau is gedaald naar ${battery.battery}%. Bereikbaarheid en live-locatie kunnen beperkt worden.',
                      ),
                      const SizedBox(height: 12),
                      Align(
                        alignment: Alignment.centerRight,
                        child: FilledButton.icon(
                          style: FilledButton.styleFrom(
                            backgroundColor: const Color(0xFF7B3500),
                            minimumSize: const Size(0, 40),
                          ),
                          onPressed: () => openDirections(context, battery.latitude, battery.longitude),
                          icon: const Icon(Icons.navigation_outlined, size: 16),
                          label: const Text('Start navigatie'),
                        ),
                      ),
                    ],
                  ),
                ),
            if (visible.isEmpty &&
                (_filter != null && _filter != FamilyEventType.unknown || lowBatteries.isEmpty))
              const EmptyState(
                icon: Icons.notifications_outlined,
                title: 'Geen meldingen',
                message: 'Nieuwe gezinsactiviteiten verschijnen hier.',
              ),
            for (var i = 0; i < visible.length; i++) ...[
              if (i == 0 || visible[i].createdAt.day != visible[i - 1].createdAt.day)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(
                    visible[i].createdAt.year == now.year &&
                            visible[i].createdAt.month == now.month &&
                            visible[i].createdAt.day == now.day
                        ? 'Vandaag'
                        : '${visible[i].createdAt.day}/${visible[i].createdAt.month}',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: _EventTile(
                  event: visible[i],
                  text: _describe(visible[i], nameOf(visible[i].actorUserId), placeOf(visible[i].placeId)),
                  when: formatClock(visible[i].createdAt),
                ),
              ),
            ],
            const SizedBox(height: 16),
            const PrivacyNote(
              title: 'Privacy voorop',
              body: 'Locatiemeldingen worden uitsluitend aan je eigen gezinsleden getoond.',
            ),
          ],
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Meldingen laden mislukt.\n$e',
          onRetry: () => ref.invalidate(familyEventsProvider(widget.family.id)),
        ),
      ),
    );
  }

  String _describe(FamilyEvent event, String name, String? place) {
    final where = place ?? 'een plaats';
    return switch (event.type) {
      FamilyEventType.sos => '$name heeft SOS gestuurd',
      FamilyEventType.arrival => '$name is aangekomen op $where',
      FamilyEventType.departure => '$name is vertrokken van $where',
      FamilyEventType.unknown => 'Gebeurtenis',
    };
  }
}

class _EventTile extends StatelessWidget {
  const _EventTile({required this.event, required this.text, required this.when});

  final FamilyEvent event;
  final String text;
  final String when;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final isSos = event.type == FamilyEventType.sos;
    final color = isSos ? AppColors.alert : AppColors.primary;
    final icon = switch (event.type) {
      FamilyEventType.sos => Icons.warning_amber_rounded,
      FamilyEventType.arrival => Icons.login,
      FamilyEventType.departure => Icons.logout,
      FamilyEventType.unknown => Icons.circle_notifications_outlined,
    };

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: isSos ? AppColors.alertSoft : Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: isSos ? AppColors.alertSoft : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(child: Text(text, style: theme.bodyLarge)),
          SizedBox(width: tokens.spaceSm),
          Text(when, style: theme.labelMedium?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}
