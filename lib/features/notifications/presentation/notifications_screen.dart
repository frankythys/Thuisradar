import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../places/application/places_providers.dart';
import '../application/events_providers.dart';
import '../domain/family_event.dart';

/// Scherm 15: feed van aankomst, vertrek en SOS.
class NotificationsScreen extends ConsumerWidget {
  const NotificationsScreen({super.key, required this.family});

  final Family family;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final events = ref.watch(familyEventsProvider(family.id));
    final members = ref.watch(familyMembersProvider(family.id)).value ?? const [];
    final places = ref.watch(familyPlacesProvider(family.id)).value ?? const [];
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

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Meldingen'),
      body: events.when(
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.notifications_outlined,
                title: 'Nog geen meldingen',
                message: 'Aankomst, vertrek en SOS van je gezin verschijnen hier.',
              )
            : ListView.separated(
                padding: EdgeInsets.all(tokens.spaceLg),
                itemCount: list.length,
                separatorBuilder: (_, _) => SizedBox(height: tokens.spaceSm),
                itemBuilder: (context, i) {
                  final event = list[i];
                  return _EventTile(
                    event: event,
                    text: _describe(event, nameOf(event.actorUserId), placeOf(event.placeId)),
                    when: formatRelative(event.createdAt, now: now),
                  );
                },
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Meldingen laden mislukt.\n$e',
          onRetry: () => ref.invalidate(familyEventsProvider(family.id)),
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

    return Row(
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
    );
  }
}
