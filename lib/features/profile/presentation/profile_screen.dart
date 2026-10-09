import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/biometric_login.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../../family/presentation/invite_screen.dart';
import '../../location/application/location_providers.dart';
import '../../onboarding/presentation/replay_onboarding_button.dart';
import '../application/profile_providers.dart';
import 'profile_edit_sheet.dart';
import 'profile_header.dart';
import 'profile_sheets.dart';
import 'profile_tile.dart';

/// Scherm 19: profiel en instellingen. Bovenaan wie je bent (met Bewerken),
/// daaronder locatie delen en een korte lijst; details openen in een onderblad.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  bool _sharing = true;

  @override
  void initState() {
    super.initState();
    final myId = ref.read(currentUserIdProvider);
    if (myId != null) {
      ref.read(profilePreferencesProvider).sharing(myId).then((value) {
        if (mounted) setState(() => _sharing = value);
      });
    }
  }

  Future<void> _edit(FamilyMember? me) async {
    final result = await showProfileEditSheet(
      context,
      name: me?.displayName ?? '',
      phone: me?.phone ?? '',
      colorIndex: me?.colorIndex ?? 0,
    );
    if (result == null || !mounted) return;
    final id = ref.read(currentUserIdProvider);
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(result.name);
      if (id != null) {
        await ref.read(profileRepositoryProvider).setPhone(id, result.phone.isEmpty ? null : result.phone);
        if (result.colorIndex != me?.colorIndex) {
          await ref.read(profileRepositoryProvider).setColor(id, result.colorIndex);
        }
      }
      ref.invalidate(familyMembersProvider(widget.family.id));
      if (mounted) _snack('Profiel opgeslagen');
    } on Exception {
      if (mounted) _snack('Opslaan mislukt. Probeer opnieuw.');
    }
  }

  void _snack(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  Future<void> _forgetLogin() async {
    final login = ref.read(biometricLoginProvider);
    try {
      await login.forgetRememberedLogin();
      await login.disable();
      if (mounted) _snack('Opgeslagen login en vingerafdruk verwijderd.');
    } catch (_) {
      if (mounted) _snack('Verwijderen is niet gelukt. Probeer opnieuw.');
    }
  }

  Future<void> _signOut() async {
    ref.read(locationTrackerProvider.notifier).stop();
    await ref.read(authRepositoryProvider).signOut();
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  Future<void> _leaveFamily() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Familie verlaten?'),
        content: Text('Je ziet ${widget.family.name} dan niet meer op de kaart.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            child: const Text('Verlaten'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    final myId = ref.read(currentUserIdProvider);
    if (myId == null) return;
    await ref.read(familyRepositoryProvider).leaveFamily(myId, widget.family.id);
    ref.read(locationTrackerProvider.notifier).stop();
    ref.invalidate(myFamilyProvider);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _share(bool enabled) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    await ref.read(profilePreferencesProvider).setSharing(userId, enabled);
    if (!mounted) return;
    setState(() => _sharing = enabled);
    final tracker = ref.read(locationTrackerProvider.notifier);
    if (enabled) {
      await tracker.start(userId: userId, familyId: widget.family.id);
    } else {
      tracker.stop();
    }
  }

  Future<void> _notification(String key, bool enabled) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(profileRepositoryProvider).setNotification(userId, key, enabled);
      ref.invalidate(notificationPreferencesProvider);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Voorkeur opslaan mislukt. Probeer opnieuw.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final members = ref.watch(familyMembersProvider(widget.family.id)).value ?? const <FamilyMember>[];
    final userId = ref.watch(currentUserIdProvider);
    final me = members.where((m) => m.userId == userId).firstOrNull;
    Widget group(List<Widget> rows) => AppCard(
      padding: EdgeInsets.zero,
      child: Column(
        children: [
          for (final (index, row) in rows.indexed) ...[if (index > 0) const Divider(height: 1), row],
        ],
      ),
    );

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Profiel'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceMd, tokens.spaceLg),
          children: [
            ProfileHeader(me: me, onEdit: () => _edit(me)),
            SizedBox(height: tokens.spaceMd),
            group([
              ProfileTile(
                icon: Icons.share_location,
                title: 'Locatie delen',
                subtitle: _sharing
                    ? 'Aan · je gezin ziet waar je bent'
                    : 'Gepauzeerd · je gezin ziet je niet',
                trailing: Switch(value: _sharing, onChanged: _share),
                onTap: () => _share(!_sharing),
              ),
            ]),
            SizedBox(height: tokens.spaceMd),
            group([
              ProfileTile(
                icon: Icons.groups_outlined,
                title: widget.family.name,
                subtitle:
                    '${members.length} ${members.length == 1 ? 'lid' : 'leden'} · code ${widget.family.inviteCode}',
                onTap: () => showFamilySheet(
                  context,
                  family: widget.family,
                  members: members,
                  onInvite: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => InviteScreen(family: widget.family))),
                ),
              ),
              ProfileTile(
                icon: Icons.notifications_outlined,
                title: 'Meldingen',
                subtitle: 'Aankomst, vertrek en SOS',
                onTap: () => showNotificationsSheet(context, onChanged: _notification),
              ),
              ProfileTile(
                icon: Icons.shield_outlined,
                title: 'Privacy & beveiliging',
                subtitle: 'Wie je ziet, opgeslagen login',
                onTap: () => showPrivacySheet(context, onForgetLogin: _forgetLogin),
              ),
              const ReplayOnboardingButton(),
            ]),
            SizedBox(height: tokens.spaceMd),
            group([
              ProfileTile(icon: Icons.logout, title: 'Uitloggen', onTap: _signOut),
              ProfileTile(
                icon: Icons.exit_to_app,
                title: 'Familie verlaten',
                danger: true,
                onTap: _leaveFamily,
              ),
            ]),
            SizedBox(height: tokens.spaceMd),
            Text(
              'CircleBeacon · versie 1.0.0',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(color: AppColors.muted),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
