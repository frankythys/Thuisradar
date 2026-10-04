import '../../auth/data/biometric_login.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';

import 'package:flutter/services.dart';

import '../../../shared/widgets/member_avatar.dart';
import '../../../shared/widgets/privacy_note.dart';
import '../../family/presentation/invite_screen.dart';
import '../../location/application/location_providers.dart';
import '../application/profile_providers.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';

/// Scherm 19: profiel en familie-instellingen.
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  late final TextEditingController _name;
  final _phone = TextEditingController();
  bool _busy = false;
  bool _sharing = true;

  @override
  void initState() {
    super.initState();
    final myId = ref.read(currentUserIdProvider);
    final members =
        ref.read(familyMembersProvider(widget.family.id)).value ?? const [];
    final me = members.where((m) => m.userId == myId);
    _name = TextEditingController(text: me.isEmpty ? '' : me.first.displayName);
    _phone.text = me.firstOrNull?.phone ?? '';
    if (myId != null) {
      ref.read(profilePreferencesProvider).sharing(myId).then((value) {
        if (mounted) setState(() => _sharing = value);
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      final phone = _phone.text.trim();
      if (phone.isNotEmpty &&
          !RegExp(r'^\+?[0-9 ()-]{6,24}$').hasMatch(phone)) {
        throw const FormatException('Ongeldig telefoonnummer');
      }
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      final id = ref.read(currentUserIdProvider);
      if (id != null) {
        await ref
            .read(profileRepositoryProvider)
            .setPhone(id, phone.isEmpty ? null : phone);
      }
      ref.invalidate(familyMembersProvider(widget.family.id));
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Naam opgeslagen')));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Opslaan mislukt')));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _leaveFamily() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Familie verlaten?'),
        content: Text(
          'Je ziet ${widget.family.name} dan niet meer op de kaart.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
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
    await ref
        .read(familyRepositoryProvider)
        .leaveFamily(myId, widget.family.id);
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
      await ref
          .read(profileRepositoryProvider)
          .setNotification(userId, key, enabled);
      ref.invalidate(notificationPreferencesProvider);
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voorkeur opslaan mislukt. Probeer opnieuw.'),
          ),
        );
      }
    }
  }

  Future<void> _color(int index) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;
    try {
      await ref.read(profileRepositoryProvider).setColor(userId, index);
      ref.invalidate(familyMembersProvider(widget.family.id));
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(const SnackBar(content: Text('Kleur opslaan mislukt.')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final members =
        ref.watch(familyMembersProvider(widget.family.id)).value ?? const [];
    final userId = ref.watch(currentUserIdProvider);
    final me = members.where((m) => m.userId == userId).firstOrNull;
    final notificationPreferences =
        ref.watch(notificationPreferencesProvider).value ??
        const <String, dynamic>{};
    return Scaffold(
      appBar: const BrandedAppBar(title: 'Profiel & instellingen'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (me != null) Center(child: MemberAvatar(member: me, size: 88)),
            const SizedBox(height: 12),
            Text(
              me?.displayName ?? 'Jouw profiel',
              style: text.headlineMedium,
              textAlign: TextAlign.center,
            ),
            Text(
              'Jouw persoonlijke plek',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Center(child: Text('Kies je kleur', style: text.labelMedium)),
            const SizedBox(height: 10),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                for (var i = 0; i < AppColors.members.length; i++)
                  Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: Semantics(
                      label: 'Kaartkleur ${i + 1}',
                      selected: me?.colorIndex == i,
                      child: InkWell(
                        onTap: () => _color(i),
                        customBorder: const CircleBorder(),
                        child: CircleAvatar(
                          radius: 18,
                          backgroundColor: AppColors.members[i],
                          child: me?.colorIndex == i
                              ? const Icon(
                                  Icons.check,
                                  color: Colors.white,
                                  size: 18,
                                )
                              : null,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Locatie delen'),
                    subtitle: Text(
                      _sharing ? 'Actief voor je gezin' : 'Delen gepauzeerd',
                    ),
                    value: _sharing,
                    onChanged: _share,
                    secondary: const Icon(
                      Icons.share_location,
                      color: AppColors.primary,
                    ),
                  ),
                  const Text(
                    'Je gezin krijgt je locatie te zien zolang delen aanstaat.',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    onPressed: () => _share(!_sharing),
                    icon: Icon(_sharing ? Icons.pause : Icons.play_arrow),
                    label: Text(
                      _sharing
                          ? 'Pauzeer delen met je gezin'
                          : 'Hervat locatie delen',
                    ),
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    'Je laatst gedeelde locatie kan zichtbaar blijven. Hervat delen wanneer je er klaar voor bent.',
                    style: TextStyle(fontSize: 11, color: AppColors.muted),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(widget.family.name, style: text.titleLarge),
                      ),
                      IconButton(
                        tooltip: 'Gezinslid uitnodigen',
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                            builder: (_) => InviteScreen(family: widget.family),
                          ),
                        ),
                        icon: const Icon(Icons.group_add_outlined),
                      ),
                    ],
                  ),
                  const Text(
                    'Samen verbonden',
                    style: TextStyle(fontSize: 12, color: AppColors.muted),
                  ),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceLow,
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text('UITNODIGINGSCODE', style: text.labelSmall),
                              Text(
                                widget.family.inviteCode,
                                style: text.titleLarge,
                              ),
                            ],
                          ),
                        ),
                        TextButton.icon(
                          onPressed: () async {
                            await Clipboard.setData(
                              ClipboardData(text: widget.family.inviteCode),
                            );
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text('Code gekopieerd'),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.copy, size: 16),
                          label: const Text('Kopiëren'),
                        ),
                      ],
                    ),
                  ),
                  for (final member in members)
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      leading: MemberAvatar(member: member, size: 36),
                      title: Text(member.displayName, style: text.titleMedium),
                      subtitle: Text(
                        member.isOwner ? 'Beheerder' : 'Gezinslid',
                        style: text.bodySmall,
                      ),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Veiligheid & meldingen', style: text.titleLarge),
                  for (final entry in {
                    'arrival': 'Aankomst',
                    'departure': 'Vertrek',
                    'sos': 'Noodberichten (SOS)',
                  }.entries)
                    SwitchListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(entry.value),
                      subtitle: Text(
                        entry.key == 'sos'
                            ? 'Ontvang noodmeldingen van je gezin'
                            : 'Ontvang een melding bij ${entry.value.toLowerCase()}',
                      ),
                      value:
                          notificationPreferences[entry.key] as bool? ?? true,
                      onChanged: (v) => _notification(entry.key, v),
                    ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            const PrivacyNote(
              title: 'Privacy & gegevens',
              body: 'Locaties zijn alleen toegankelijk voor je eigen gezinsleden. Je kunt het delen op elk moment pauzeren.',
            ),
            const SizedBox(height: 20),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Jouw naam', style: text.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'Naam',
                      fillColor: AppColors.surfaceLow,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text('Telefoonnummer voor je gezin', style: text.titleMedium),
                  const SizedBox(height: 8),
                  TextField(
                    controller: _phone,
                    keyboardType: TextInputType.phone,
                    decoration: const InputDecoration(hintText: '+32 …'),
                  ),
                  const SizedBox(height: 12),
                  FilledButton(
                    onPressed: _busy ? null : _saveName,
                    child: const Text('Naam opslaan'),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            OutlinedButton.icon(
              onPressed: () async {
                await ref.read(biometricLoginProvider).disable();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Opgeslagen biometrische login verwijderd.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.fingerprint),
              label: const Text('Biometrische login verwijderen'),
            ),
            OutlinedButton.icon(
              onPressed: () async {
                ref.read(locationTrackerProvider.notifier).stop();
                await ref.read(authRepositoryProvider).signOut();
                if (context.mounted) {
                  Navigator.popUntil(context, (route) => route.isFirst);
                }
              },
              icon: const Icon(Icons.logout),
              label: const Text('Uitloggen'),
            ),
            TextButton.icon(
              onPressed: _leaveFamily,
              icon: const Icon(Icons.exit_to_app),
              label: const Text('Familie verlaten'),
              style: TextButton.styleFrom(foregroundColor: AppColors.alert),
            ),
            const SizedBox(height: 16),
            Text(
              'Thuisradar · versie 1.0.0',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
