import 'package:flutter/material.dart';

import '../../../shared/widgets/app_bottom_nav.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../family/domain/family.dart';
import '../../map/presentation/map_screen.dart';

/// Hoofdframe met de vier tabs. Plaatsen/Chat/Meldingen zijn nog lege
/// "binnenkort"-staten; die worden in Fase D ingevuld.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key, required this.family});

  final Family family;

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  AppTab _tab = AppTab.kaart;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
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
    );
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
