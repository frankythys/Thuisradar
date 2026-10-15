import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../auth/application/auth_providers.dart';
import '../application/emergency_providers.dart';
import '../domain/emergency_contact.dart';
import 'emergency_access_tile.dart';
import 'emergency_contact_fields.dart';
import '../../../l10n/l10n.dart';

/// Twee noodcontacten instellen: bij een SOS krijgen ze een sms met je
/// locatie, en contact 1 wordt daarna gebeld.
class EmergencyContactsScreen extends ConsumerStatefulWidget {
  const EmergencyContactsScreen({super.key, required this.senderName});

  /// Jouw naam, voor de test-sms.
  final String senderName;

  @override
  ConsumerState<EmergencyContactsScreen> createState() => _EmergencyContactsScreenState();
}

class _EmergencyContactsScreenState extends ConsumerState<EmergencyContactsScreen> {
  final _names = [TextEditingController(), TextEditingController()];
  final _phones = [TextEditingController(), TextEditingController()];
  final _errors = <EmergencyContactProblem?>[null, null];
  bool _loaded = false;
  bool _busy = false;

  @override
  void dispose() {
    for (final controller in [..._names, ..._phones]) {
      controller.dispose();
    }
    super.dispose();
  }

  void _fill(List<EmergencyContact> contacts) {
    if (_loaded) return;
    _loaded = true;
    for (final contact in contacts) {
      final index = contact.position - 1;
      if (index < 0 || index >= kMaxEmergencyContacts) continue;
      _names[index].text = contact.name;
      _phones[index].text = contact.phone;
    }
  }

  /// De ingevulde contacten, of null als er iets niet klopt.
  List<EmergencyContact>? _validated() {
    var ok = true;
    final contacts = <EmergencyContact>[];
    for (var index = 0; index < kMaxEmergencyContacts; index++) {
      final name = _names[index].text.trim();
      final phone = _phones[index].text.trim();
      _errors[index] = emergencyContactError(name, phone);
      if (_errors[index] != null) ok = false;
      if (name.isNotEmpty && phone.isNotEmpty) {
        contacts.add(EmergencyContact(position: index + 1, name: name, phone: phone));
      }
    }
    setState(() {});
    return ok ? contacts : null;
  }

  Future<void> _save() async {
    final contacts = _validated();
    final userId = ref.read(currentUserIdProvider);
    if (contacts == null || userId == null) return;
    final l10n = context.l10n;
    setState(() => _busy = true);
    try {
      await ref.read(emergencyContactRepositoryProvider).save(userId, contacts);
      await ref.read(emergencyContactCacheProvider).write(userId, contacts);
      ref.invalidate(myEmergencyContactsProvider);
      if (contacts.isNotEmpty && !await ref.read(emergencyPhoneProvider).canSendAutomatically()) {
        await ref.read(emergencyPhoneProvider).requestAccess();
        ref.invalidate(emergencyAutomaticProvider);
      }
      _snack(contacts.isEmpty ? l10n.emergencyCleared : l10n.emergencySaved);
    } on Exception catch (error) {
      debugPrint('Noodcontacten bewaren mislukt: $error');
      _snack(l10n.commonTryAgainSaveFailed);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final contacts = _validated();
    if (contacts == null) return;
    final plan = planFor(contacts);
    final l10n = context.l10n;
    if (plan.isEmpty) return _snack(l10n.emergencyFillFirst);
    final phone = ref.read(emergencyPhoneProvider);
    final sender = widget.senderName.trim();
    final text = l10n.emergencyTestSms(sender.isEmpty ? l10n.emergencyYourContact : sender);
    final results = <String, SmsResult>{
      for (final contact in plan.smsTo) contact.name: await phone.sendSms(dialablePhone(contact.phone), text),
    };
    ref.invalidate(emergencySimProvider);
    if (results.values.every((result) => result == SmsResult.notAllowed)) {
      return phone.openSms(dialablePhone(plan.smsTo.first.phone), text);
    }
    String names(SmsResult wanted) => l10n.joinNames([
      for (final MapEntry(:key, :value) in results.entries)
        if (value == wanted) key,
    ]);
    final sent = names(SmsResult.sent);
    final noService = names(SmsResult.noService);
    final failed = names(SmsResult.failed);
    _snack(
      [
        if (sent.isNotEmpty) l10n.emergencyTestSent(sent),
        if (noService.isNotEmpty) l10n.emergencyTestNoService(noService),
        if (failed.isNotEmpty) l10n.emergencyTestFailed(failed),
      ].join(' '),
    );
  }

  String? _problemText(AppLocalizations l10n, EmergencyContactProblem? problem) => switch (problem) {
    null => null,
    EmergencyContactProblem.missingName => l10n.emergencyErrorName,
    EmergencyContactProblem.missingPhone => l10n.emergencyErrorPhone,
    EmergencyContactProblem.invalidPhone => l10n.emergencyErrorInvalidPhone,
  };

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final l10n = context.l10n;
    final contacts = ref.watch(myEmergencyContactsProvider);
    if (contacts.hasValue) _fill(contacts.requireValue);

    return Scaffold(
      appBar: BrandedAppBar(title: l10n.emergencyTitle),
      body: SafeArea(
        child: !contacts.hasValue && contacts.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(tokens.spaceMd),
                children: [
                  Text(l10n.emergencyIntro, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
                  SizedBox(height: tokens.spaceMd),
                  EmergencyContactFields(
                    title: l10n.emergencyContactNumber(1),
                    role: l10n.emergencyRoleFirst,
                    name: _names[0],
                    phone: _phones[0],
                    error: _problemText(l10n, _errors[0]),
                  ),
                  SizedBox(height: tokens.spaceSm),
                  EmergencyContactFields(
                    title: l10n.emergencyContactNumber(2),
                    role: l10n.emergencyRoleSecond,
                    name: _names[1],
                    phone: _phones[1],
                    error: _problemText(l10n, _errors[1]),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  const EmergencyAccessTile(),
                  SizedBox(height: tokens.spaceMd),
                  FilledButton(onPressed: _busy ? null : _save, child: Text(l10n.emergencySave)),
                  SizedBox(height: tokens.spaceSm),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _test,
                    icon: const Icon(Icons.sms_outlined),
                    label: Text(l10n.emergencySendTest),
                  ),
                ],
              ),
      ),
    );
  }
}
