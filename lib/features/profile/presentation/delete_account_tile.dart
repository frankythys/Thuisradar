import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../l10n/l10n.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/biometric_login.dart';
import '../../auth/data/pin_lock.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../../geofencing/application/geofencing_providers.dart';
import '../../location/application/location_providers.dart';
import 'profile_tile.dart';

/// "Account verwijderen" in Profiel: wist het account met al je gegevens op
/// de server (migratie 025) en meldt je daarna af op deze gsm. De beheerder
/// draagt eerst het beheer over zolang er nog anderen in het gezin zitten.
class DeleteAccountTile extends ConsumerStatefulWidget {
  const DeleteAccountTile({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<DeleteAccountTile> createState() => _DeleteAccountTileState();
}

class _DeleteAccountTileState extends ConsumerState<DeleteAccountTile> {
  bool _busy = false;

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _delete() async {
    final l10n = context.l10n;
    final myId = ref.read(currentUserIdProvider);
    if (myId == null || _busy) return;
    final members = ref.read(familyMembersProvider(widget.family.id)).value ?? const <FamilyMember>[];
    final isOwner = members.any((member) => member.userId == myId && member.isOwner);
    if (isOwner && members.any((member) => member.userId != myId)) {
      _snack(l10n.profileDeleteAccountOwnerFirst);
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(context.l10n.profileDeleteAccountTitle),
        content: Text(context.l10n.profileDeleteAccountBody),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: Text(context.l10n.commonCancel)),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            child: Text(context.l10n.profileDeleteAccountConfirm),
          ),
        ],
      ),
    );
    if (confirm != true || !mounted) return;

    setState(() => _busy = true);
    final container = ProviderScope.containerOf(context);
    try {
      await ref.read(accountDeletionRepositoryProvider).deleteMyAccount();
    } on Exception catch (error) {
      debugPrint('Account verwijderen mislukt: $error');
      if (mounted) {
        setState(() => _busy = false);
        _snack(
          error.toString().contains('beheer over')
              ? l10n.profileDeleteAccountOwnerFirst
              : l10n.profileDeleteAccountFailed,
        );
      }
      return;
    }

    // Het account is weg: niets meer delen en alles op deze gsm vergeten.
    container.read(locationTrackerProvider.notifier).stop(reason: 'account verwijderd');
    await container.read(geofenceSyncProvider.notifier).stop();
    await container.read(pushServiceProvider).unregister();
    try {
      await container.read(authRepositoryProvider).signOut();
    } on Exception catch (error) {
      debugPrint('Afmelden na account verwijderen mislukt: $error');
    }
    final login = container.read(biometricLoginProvider);
    await login.forgetRememberedLogin();
    await login.disable();
    await container.read(pinLockProvider).disable(myId);
    container.invalidate(pinEnabledProvider(myId));
    if (mounted) {
      _snack(l10n.profileDeleteAccountDone);
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) => ProfileTile(
    icon: Icons.delete_forever_outlined,
    title: context.l10n.profileDeleteAccount,
    subtitle: _busy ? context.l10n.profileDeleteAccountBusy : context.l10n.profileDeleteAccountSubtitle,
    danger: true,
    onTap: _busy ? null : _delete,
  );
}
