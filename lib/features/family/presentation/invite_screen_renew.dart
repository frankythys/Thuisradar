part of 'invite_screen.dart';

/// "Geldig tot 18/10 om 14:05", of dat de code verlopen is. Null als de
/// vervaldatum onbekend is (migratie 017 nog niet uitgevoerd).
String? inviteValidity(Family family, DateTime now, {required bool isOwner}) {
  final expiresAt = family.inviteExpiresAt;
  if (expiresAt == null) return null;
  if (family.inviteExpiredAt(now)) {
    return isOwner
        ? 'Deze code is verlopen. Maak een nieuwe code.'
        : 'Deze code is verlopen. Vraag de beheerder een nieuwe code.';
  }
  return 'Geldig tot ${expiresAt.day}/${expiresAt.month} om ${formatClock(expiresAt)}';
}

/// Beheerder: een nieuwe code maken. De oude werkt daarna niet meer, zodat een
/// code die te ver rondging (groepschat, screenshot) geen toegang meer geeft.
class _RenewCodeButton extends ConsumerStatefulWidget {
  const _RenewCodeButton({required this.familyId});

  final String familyId;

  @override
  ConsumerState<_RenewCodeButton> createState() => _RenewCodeButtonState();
}

class _RenewCodeButtonState extends ConsumerState<_RenewCodeButton> {
  bool _busy = false;

  Future<void> _renew() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Nieuwe code maken?'),
        content: const Text(
          'De huidige code werkt dan niet meer. Wie al lid is, blijft lid. De nieuwe code is 7 dagen geldig.',
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Nieuwe code')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(familyRepositoryProvider).rotateInviteCode(widget.familyId);
      ref.invalidate(familyInviteProvider(widget.familyId));
      messenger.showSnackBar(const SnackBar(content: Text('Nieuwe code gemaakt. De oude werkt niet meer.')));
    } on Exception catch (error) {
      debugPrint('Nieuwe uitnodigingscode mislukt: $error');
      messenger.showSnackBar(
        const SnackBar(content: Text('Nieuwe code maken is niet gelukt. Probeer opnieuw.')),
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
    onPressed: _busy ? null : _renew,
    icon: const Icon(Icons.autorenew, size: 20),
    label: const Text('Nieuwe code maken'),
  );
}
