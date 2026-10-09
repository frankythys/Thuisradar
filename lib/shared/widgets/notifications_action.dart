import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme/app_colors.dart';
import '../../features/family/application/family_providers.dart';
import '../../features/notifications/application/events_providers.dart';
import '../../features/notifications/presentation/notifications_screen.dart';

/// Belletje in de app-balk dat de meldingen opent, met een badge zodra er
/// ongelezen meldingen zijn. Verbergt zich tot er een familie is.
class NotificationsAction extends ConsumerWidget {
  const NotificationsAction({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final family = ref.watch(myFamilyProvider).value;
    if (family == null) return const SizedBox.shrink();

    final unread = ref.watch(unreadCountProvider(family.id));
    const bell = Icon(Icons.notifications_outlined, color: AppColors.primary);

    return IconButton(
      tooltip: 'Meldingen',
      icon: unread > 0 ? Badge(label: Text('$unread'), child: bell) : bell,
      onPressed: () {
        // Openen = alles als gelezen markeren (badge verdwijnt).
        markNotificationsSeen(ref, family.id).catchError((Object e) => debugPrint('Meldingen gelezen: $e'));
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => NotificationsScreen(family: family)));
      },
    );
  }
}
