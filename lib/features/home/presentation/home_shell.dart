import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../map/presentation/map_screen.dart';
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

    return Stack(
      children: [
        Scaffold(
          body: IndexedStack(
            index: _tab.index,
            children: [
              MapScreen(family: widget.family),
              const _SoonTab(
                title: 'Plaatsen',
                icon: Icons.place_outlined,
                message: 'Binnenkort stel je hier veilige zones in met aankomst- en vertrekmeldingen.',
              ),
              const _SoonTab(
                title: 'Chat',
                icon: Icons.chat_bubble_outline,
                message: 'Binnenkort kun je hier met je gezin chatten.',
              ),
              const _SoonTab(
                title: 'Meldingen',
                icon: Icons.notifications_outlined,
                message: 'Binnenkort zie je hier aankomst, vertrek en SOS-meldingen.',
              ),
            ],
          ),
          bottomNavigationBar: AppBottomNav(current: _tab, onSelected: (tab) => setState(() => _tab = tab)),
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

  String _nameFor(String userId, String familyId) {
    final members = ref.read(familyMembersProvider(familyId)).value ?? const [];
    for (final member in members) {
      if (member.userId == userId) return member.displayName;
    }
    return 'Een gezinslid';
  }
}

class _SoonTab extends StatelessWidget {
  const _SoonTab({required this.title, required this.icon, required this.message});

  final String title;
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: BrandedAppBar(title: title),
      body: EmptyState(icon: icon, title: 'Binnenkort', message: message),
    );
  }
}
