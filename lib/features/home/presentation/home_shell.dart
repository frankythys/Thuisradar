import '../../../core/utils/resync_signal.dart';
import '../../location/application/location_providers.dart';
import '../../profile/presentation/profile_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/lazy_indexed_stack.dart';
import '../../auth/application/auth_providers.dart';
import '../../chat/presentation/chat_screen.dart';
import '../../driving/presentation/driving_screen.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../map/presentation/map_screen.dart';
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
  late final AppLifecycleListener _lifecycle;

  @override
  void initState() {
    super.initState();
    // Terug op de voorgrond: Android kan op de achtergrond zowel de GPS-stroom
    // als het realtime-kanaal stilgelegd hebben. Haal alles vers op, anders
    // blijft de kaart iemand tonen op een plek van een kwartier geleden.
    _lifecycle = AppLifecycleListener(onResume: _onResume);
  }

  @override
  void dispose() {
    _lifecycle.dispose();
    super.dispose();
  }

  void _onResume() {
    ref.read(resyncSignalProvider).notify();
    ref.read(locationTrackerProvider.notifier).resume();
  }

  @override
  Widget build(BuildContext context) {
    final familyId = widget.family.id;
    final myId = ref.watch(currentUserIdProvider);
    final active = ref.watch(activeSosProvider(familyId)).value ?? const [];
    final incoming = sosToShow(active, myUserId: myId, dismissed: _dismissed);

    return Stack(
      children: [
        Scaffold(
          body: LazyIndexedStack(
            index: _tab.index,
            builders: [
              (_) => MapScreen(family: widget.family),
              (_) => _tab == AppTab.rijden ? DrivingScreen(family: widget.family) : const SizedBox.shrink(),
              (_) => PlacesScreen(family: widget.family),
              (_) => ChatScreen(family: widget.family),
            ],
          ),
          bottomNavigationBar: AppBottomNav(
            offline:
                _tab == AppTab.kaart && ref.watch(familyLocationsProvider(familyId)).value?.isEmpty == true,
            onFamily: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ProfileScreen(family: widget.family)),
            ),
            onSettings: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => ProfileScreen(family: widget.family)),
            ),
            current: _tab,
            onSelected: _onSelectTab,
          ),
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
  }

  String _nameFor(String userId, String familyId) {
    final members = ref.read(familyMembersProvider(familyId)).value ?? const [];
    for (final member in members) {
      if (member.userId == userId) return member.displayName;
    }
    return 'Een gezinslid';
  }
}
