import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
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
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    final myId = ref.read(currentUserIdProvider);
    final members = ref.read(familyMembersProvider(widget.family.id)).value ?? const [];
    final me = members.where((m) => m.userId == myId);
    _name = TextEditingController(text: me.isEmpty ? '' : me.first.displayName);
  }

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _saveName() async {
    final name = _name.text.trim();
    if (name.isEmpty || _busy) return;
    setState(() => _busy = true);
    try {
      await ref.read(authRepositoryProvider).updateDisplayName(name);
      ref.invalidate(familyMembersProvider(widget.family.id));
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Naam opgeslagen')));
      }
    } on Exception {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Opslaan mislukt')));
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
    ref.invalidate(myFamilyProvider);
    if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Profiel'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text('Jouw naam', style: text.titleMedium),
                  SizedBox(height: tokens.spaceSm),
                  TextField(
                    controller: _name,
                    decoration: const InputDecoration(
                      hintText: 'Naam',
                      prefixIcon: Icon(Icons.person_outline, color: AppColors.primary),
                    ),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  FilledButton(onPressed: _busy ? null : _saveName, child: const Text('Naam opslaan')),
                ],
              ),
            ),
            SizedBox(height: tokens.spaceLg),
            AppCard(
              child: Column(
                children: [
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.groups_outlined, color: AppColors.primary),
                    title: Text(widget.family.name),
                    subtitle: const Text('Jouw familie'),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.logout, color: AppColors.muted),
                    title: const Text('Uitloggen'),
                    onTap: () => ref.read(authRepositoryProvider).signOut(),
                  ),
                  const Divider(height: 1),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.exit_to_app, color: AppColors.alert),
                    title: Text('Familie verlaten', style: TextStyle(color: AppColors.alert)),
                    onTap: _leaveFamily,
                  ),
                ],
              ),
            ),
            SizedBox(height: tokens.spaceLg),
            Center(
              child: Text(
                'Thuisradar · versie 1.0.0',
                style: text.bodySmall?.copyWith(color: AppColors.muted),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
