import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../auth/application/auth_providers.dart';
import '../application/family_providers.dart';

/// Eerste keer: een familie aanmaken of er een joinen met een code.
class FamilySetupScreen extends ConsumerStatefulWidget {
  const FamilySetupScreen({super.key});

  @override
  ConsumerState<FamilySetupScreen> createState() => _FamilySetupScreenState();
}

class _FamilySetupScreenState extends ConsumerState<FamilySetupScreen> {
  final _familyName = TextEditingController();
  final _inviteCode = TextEditingController();
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _familyName.dispose();
    _inviteCode.dispose();
    super.dispose();
  }

  Future<void> _run(Future<void> Function() action) async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await action();
      ref.invalidate(myFamilyProvider);
    } on PostgrestException catch (e) {
      if (mounted) setState(() => _error = e.message);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _create() {
    final name = _familyName.text.trim();
    if (name.isEmpty) return;
    _run(() => ref.read(familyRepositoryProvider).createFamily(name));
  }

  void _join() {
    final code = _inviteCode.text.trim();
    if (code.isEmpty) return;
    _run(() => ref.read(familyRepositoryProvider).joinFamily(code));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Jouw familie'),
        actions: [
          TextButton(
            onPressed: () => ref.read(authRepositoryProvider).signOut(),
            child: const Text('Uitloggen'),
          ),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _SetupCard(
            title: 'Nieuwe familie',
            subtitle: 'Je krijgt een code om de anderen uit te nodigen.',
            field: TextField(
              controller: _familyName,
              decoration: const InputDecoration(labelText: 'Naam van de familie'),
            ),
            buttonLabel: 'Familie aanmaken',
            onPressed: _busy ? null : _create,
          ),
          const SizedBox(height: 16),
          _SetupCard(
            title: 'Uitnodiging gekregen?',
            subtitle: 'Vul de code in die je van een gezinslid kreeg.',
            field: TextField(
              controller: _inviteCode,
              textCapitalization: TextCapitalization.characters,
              decoration: const InputDecoration(labelText: 'Uitnodigingscode'),
            ),
            buttonLabel: 'Familie joinen',
            onPressed: _busy ? null : _join,
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            Text(_error!, style: TextStyle(color: Theme.of(context).colorScheme.error)),
          ],
        ],
      ),
    );
  }
}

class _SetupCard extends StatelessWidget {
  const _SetupCard({
    required this.title,
    required this.subtitle,
    required this.field,
    required this.buttonLabel,
    required this.onPressed,
  });

  final String title;
  final String subtitle;
  final Widget field;
  final String buttonLabel;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      color: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              title,
              style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(subtitle),
            const SizedBox(height: 16),
            field,
            const SizedBox(height: 12),
            FilledButton(onPressed: onPressed, child: Text(buttonLabel)),
          ],
        ),
      ),
    );
  }
}
