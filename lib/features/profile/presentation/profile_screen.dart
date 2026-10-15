import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/push/push_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../auth/application/auth_providers.dart';
import '../../auth/data/biometric_login.dart';
import '../../auth/data/pin_lock.dart';
import '../../emergency/presentation/emergency_contacts_tile.dart';
import 'pin_settings_tile.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../../family/presentation/invite_screen.dart';
import '../../geofencing/application/geofencing_providers.dart';
import '../../location/application/location_providers.dart';
import '../../onboarding/presentation/replay_onboarding_button.dart';
import '../application/profile_providers.dart';
import 'diagnostics_export_tile.dart';
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
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        await ref.read(pinLockProvider).disable(userId);
        ref.invalidate(pinEnabledProvider(userId));
      }
      if (mounted) _snack('Opgeslagen login en vingerafdruk verwijderd.');
    } catch (_) {
      if (mounted) _snack('Verwijderen is niet gelukt. Probeer opnieuw.');
    }
  }

  Future<void> _lockOrSignOut() async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      final enabled = await ref.read(appLockEnabledProvider(userId).future);
      if (!mounted) return;
      if (enabled) {
        ref.read(pinLockRequestProvider.notifier).lock();
        Navigator.popUntil(context, (route) => route.isFirst);
      } else {
        await _signOut();
      }
    } catch (_) {
      if (mounted) _snack('Afsluiten is niet gelukt. Probeer opnieuw.');
    }
  }

  Future<void> _signOut() async {
    final userId = ref.read(currentUserIdProvider);
    final container = ProviderScope.containerOf(context);
    ref.read(locationTrackerProvider.notifier).stop(reason: 'uitgelogd');
    // Vóór het afmelden: de toestelsleutel en het pushtoken afmelden vraagt
    // nog een sessie.
    await ref.read(geofenceSyncProvider.notifier).stop();
    await ref.read(pushServiceProvider).forgetServerToken();
    try {
      await ref.read(authRepositoryProvider).signOut();
    } on Exception catch (error) {
      // Offline: de lokale sessie is al weg, enkel de serveraanroep faalde.
      debugPrint('Afmelden bij de server mislukt: $error');
    }
    if (userId != null) {
      await container.read(pinLockProvider).disable(userId);
      container.invalidate(pinEnabledProvider(userId));
    }
    if (mounted) Navigator.popUntil(context, (route) => route.isFirst);
  }

  /// Beheerder: het beheer overdragen. Er blijft één beheerder; jij wordt
  /// gewoon gezinslid (migratie 018).
  Future<void> _makeOwner(FamilyMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.displayName} beheerder maken?'),
        content: Text(
          'Jij wordt dan gewoon gezinslid. ${member.displayName} kan daarna codes vernieuwen, '
          'leden verwijderen (ook jou) en het beheer weer overdragen.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Beheerder maken')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(familyRepositoryProvider).transferOwnership(widget.family.id, member.userId);
      // De ledenlijst ververst via realtime; meteen opnieuw laden voor de
      // zekerheid, zodat de beheerknoppen meteen verdwijnen.
      ref.invalidate(familyMembersProvider(widget.family.id));
      if (mounted) _snack('${member.displayName} is nu beheerder.');
    } on Exception catch (error) {
      debugPrint('Beheer overdragen mislukt: $error');
      if (mounted) _snack('Beheer overdragen is niet gelukt. Probeer opnieuw.');
    }
  }

  /// Beheerder: iemand uit het gezin halen. Op de server verdwijnt die ook
  /// van de kaart en krijgt het gezin een nieuwe code (migratie 017).
  Future<void> _removeMember(FamilyMember member) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('${member.displayName} verwijderen?'),
        content: Text(
          '${member.displayName} ziet jullie dan niet meer en verdwijnt van de kaart. '
          'De uitnodigingscode wordt vernieuwd, zodat de oude code niet meer werkt.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ref.read(familyRepositoryProvider).removeMember(widget.family.id, member.userId);
      ref.invalidate(familyInviteProvider(widget.family.id));
      if (mounted) _snack('${member.displayName} is uit het gezin verwijderd.');
    } on Exception catch (error) {
      debugPrint('Lid verwijderen mislukt: $error');
      if (mounted) _snack('Verwijderen is niet gelukt. Probeer opnieuw.');
    }
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
    ref.read(locationTrackerProvider.notifier).stop(reason: 'familie verlaten');
    await ref.read(geofenceSyncProvider.notifier).stop();
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
    final zones = ref.read(geofenceSyncProvider.notifier);
    if (enabled) {
      await tracker.start(userId: userId, familyId: widget.family.id);
      await zones.start(userId: userId, familyId: widget.family.id);
    } else {
      tracker.stop(reason: 'locatie delen uitgezet in profiel');
      await zones.stop();
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
    final invite = ref.watch(familyInviteProvider(widget.family.id)).value ?? widget.family;
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
              if (userId != null) PinSettingsTile(userId: userId),
              ProfileTile(
                icon: Icons.groups_outlined,
                title: widget.family.name,
                subtitle:
                    '${members.length} ${members.length == 1 ? 'lid' : 'leden'} · code ${invite.inviteCode}',
                onTap: () => showFamilySheet(
                  context,
                  family: invite,
                  members: members,
                  onMakeOwner: me?.isOwner == true ? _makeOwner : null,
                  onRemove: me?.isOwner == true ? _removeMember : null,
                  onInvite: () =>
                      Navigator.of(context)
                          .push(MaterialPageRoute<void>(builder: (_) => InviteScreen(family: widget.family))),
                ),
              ),
              EmergencyContactsTile(senderName: me?.displayName ?? ''),
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
              const DiagnosticsExportTile(),
            ]),
            SizedBox(height: tokens.spaceMd),
            group([
              ProfileTile(
                icon: userId != null && ref.watch(appLockEnabledProvider(userId)).value == true
                    ? Icons.lock_outline
                    : Icons.logout,
                title: 'Uitloggen',
                subtitle: userId != null && ref.watch(appLockEnabledProvider(userId)).value == true
                    ? 'Opnieuw inloggen met je toegangscode'
                    : null,
                onTap: _lockOrSignOut,
              ),
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
