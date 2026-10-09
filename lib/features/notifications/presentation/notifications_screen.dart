import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/contact_actions.dart';
import '../../../shared/widgets/filter_chips.dart';
import '../../location/application/location_providers.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../../places/application/places_providers.dart';
import '../application/events_providers.dart';
import '../domain/family_event.dart';
import '../domain/unread.dart';

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
        .where(isLowBattery)
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

    final filterIndex = _filters.indexWhere((f) => f.type == _filter);

    return Scaffold(
      appBar: BrandedAppBar(
        title: 'Meldingen',
        actions: [
          // Openen markeert al alles als gelezen; wissen staat in het menu.
          PopupMenuButton<String>(
            tooltip: 'Meer opties',
            icon: const Icon(Icons.more_vert, color: AppColors.primary),
            enabled: visible.isNotEmpty,
            onSelected: (_) => _clear(),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: 'clear',
                child: ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(Icons.delete_outline, color: AppColors.alert),
                  title: Text('Meldingen wissen'),
                ),
              ),
            ],
          ),
        ],
      ),
      body: events.when(
        data: (_) => ListView(
          padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceMd, tokens.spaceLg),
          children: [
            FilterChips(
              labels: [for (final f in _filters) f.label],
              selectedIndex: filterIndex < 0 ? 0 : filterIndex,
              onSelected: (i) => setState(() => _filter = _filters[i].type),
            ),
            SizedBox(height: tokens.spaceMd),
            if (_filter == null || _filter == FamilyEventType.unknown)
              for (final battery in lowBatteries)
                Padding(
                  padding: EdgeInsets.only(bottom: tokens.spaceSm),
                  child: _BatteryRow(
                    name: nameOf(battery.userId),
                    level: battery.battery ?? 0,
                    member: members.where((m) => m.userId == battery.userId).firstOrNull,
                  ),
                ),
            if (visible.isEmpty &&
                (_filter != null && _filter != FamilyEventType.unknown || lowBatteries.isEmpty))
              const EmptyState(
                icon: Icons.notifications_outlined,
                title: 'Geen meldingen',
                message: 'Nieuwe gezinsactiviteiten verschijnen hier.',
              ),
            for (final day in _byDay(visible)) ...[
              Padding(
                padding: EdgeInsets.fromLTRB(tokens.spaceXs, tokens.spaceSm, 0, tokens.spaceSm),
                child: Text(
                  formatDayLabel(day.first.createdAt, now: now).toUpperCase(),
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.muted),
                ),
              ),
              AppCard(
                padding: EdgeInsets.zero,
                child: Column(
                  children: [
                    for (final (index, event) in day.indexed) ...[
                      if (index > 0) const Divider(height: 1),
                      _EventTile(
                        event: event,
                        text: _describe(event, nameOf(event.actorUserId), placeOf(event.placeId)),
                        when: formatClock(event.createdAt),
                      ),
                    ],
                  ],
                ),
              ),
            ],
            SizedBox(height: tokens.spaceMd),
            Row(
              children: [
                const Icon(Icons.lock_outline, size: 16, color: AppColors.muted),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(
                    'Alleen je gezin ziet deze meldingen.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
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

  static const _filters = <({String label, FamilyEventType? type})>[
    (label: 'Alles', type: null),
    (label: 'Aankomst', type: FamilyEventType.arrival),
    (label: 'Vertrek', type: FamilyEventType.departure),
    (label: 'Batterij', type: FamilyEventType.unknown),
    (label: 'SOS', type: FamilyEventType.sos),
  ];

  /// Meldingen per kalenderdag, in de volgorde waarin ze binnenkwamen.
  static List<List<FamilyEvent>> _byDay(List<FamilyEvent> events) {
    final days = <List<FamilyEvent>>[];
    for (final event in events) {
      if (days.isEmpty || isOtherDay(days.last.last.createdAt, event.createdAt)) {
        days.add([event]);
      } else {
        days.last.add(event);
      }
    }
    return days;
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

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm + tokens.spaceXs),
      child: Row(
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: isSos ? AppColors.alertSoft : AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, size: 18, color: color),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Text(text, style: theme.titleSmall?.copyWith(color: isSos ? AppColors.alert : null)),
          ),
          SizedBox(width: tokens.spaceSm),
          Text(when, style: theme.labelMedium?.copyWith(color: AppColors.muted)),
        ],
      ),
    );
  }
}

/// Lage batterij als compacte rij met een knop om meteen te bellen.
class _BatteryRow extends StatelessWidget {
  const _BatteryRow({required this.name, required this.level, this.member});

  final String name;
  final int level;
  final FamilyMember? member;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final who = member;
    return Container(
      padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceSm, tokens.spaceSm),
      decoration: BoxDecoration(
        color: AppColors.alertSoft,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
      ),
      child: Row(
        children: [
          const Icon(Icons.battery_alert, color: AppColors.alert),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('$name: batterij $level%', style: text.titleSmall),
                Text('Live-locatie kan wegvallen', style: text.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
          if (who != null)
            TextButton.icon(
              onPressed: () => callMember(context, who),
              style: TextButton.styleFrom(foregroundColor: AppColors.alert),
              icon: const Icon(Icons.call_outlined, size: 18),
              label: const Text('Bel'),
            ),
        ],
      ),
    );
  }
}
