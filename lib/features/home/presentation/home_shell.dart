import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_bottom_nav.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../map/presentation/map_screen.dart';
import '../../notifications/application/events_providers.dart';
import '../../notifications/presentation/notifications_screen.dart';
import '../../places/presentation/places_screen.dart';
import '../../sos/application/sos_providers.dart';
import '../../sos/domain/sos_alert.dart';
import '../../sos/presentation/sos_received_overlay.dart';

/// Hoofdframe met de vier tabs. Toont bovenop alles een SOS-overlay zodra een
/// ander gezinslid een alarm stuurt. Plaatsen/Chat/Meldingen zijn nog lege
/// "binnenkort"-staten; die worden in Fase D ingevuld.
class HomeShell extends ConsumerStatefulWidget {
  const HomeShell({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends ConsumerState<HomeShell> {
  AppTab _tab = AppTab.kaart;
  final _dismissed = <String>{};

  @override
  Widget build(BuildContext context) {
    final familyId = widget.family.id;
    final myId = ref.watch(currentUserIdProvider);
    final active = ref.watch(activeSosProvider(familyId)).value ?? const [];
    final incoming = sosToShow(active, myUserId: myId, dismissed: _dismissed);
    final unread = ref.watch(unreadCountProvider(familyId));

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _tab.index,
            children: [
              MapScreen(family: widget.family),
              PlacesScreen(family: widget.family),
              ChatScreen(family: widget.family),
              NotificationsScreen(family: widget.family),
            ],
          ),
          bottomNavigationBar: AppBottomNav(current: _tab, meldingenBadge: unread, onSelected: _onSelectTab),
        ),
        if (incoming != null)
          Positioned.fill(
            child: SosReceivedOverlay(
              alert: incoming,
              name: _nameFor(incoming.userId, familyId),
              onShowOnMap: () => setState(() {
                _tab = AppTab.kaart;
                _dismissed.add(incoming.id);
              }),
              onDismiss: () => setState(() => _dismissed.add(incoming.id)),
            ),
          ),
      ],
    );
  }

  void _onSelectTab(AppTab tab) {
    setState(() => _tab = tab);
    // Meldingen openen = alles als gelezen markeren (badge verdwijnt).
    if (tab == AppTab.meldingen) {
      final familyId = widget.family.id;
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        ref.read(eventsRepositoryProvider).markSeen(userId, familyId).then((_) {
          if (mounted) ref.invalidate(lastSeenProvider(familyId));
        });
      }
    }
  }

  String _nameFor(String userId, String familyId) {
    final members = ref.read(familyMembersProvider(familyId)).value ?? const [];
    for (final member in members) {
      if (member.userId == userId) return member.displayName;
    }
    return 'Een gezinslid';
  }
}
