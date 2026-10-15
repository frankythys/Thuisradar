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
  final _errors = <String?>[null, null];
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
    setState(() => _busy = true);
    try {
      await ref.read(emergencyContactRepositoryProvider).save(userId, contacts);
      await ref.read(emergencyContactCacheProvider).write(userId, contacts);
      ref.invalidate(myEmergencyContactsProvider);
      if (contacts.isNotEmpty && !await ref.read(emergencyPhoneProvider).canSendAutomatically()) {
        await ref.read(emergencyPhoneProvider).requestAccess();
        ref.invalidate(emergencyAutomaticProvider);
      }
      _snack(contacts.isEmpty ? 'Noodcontacten gewist.' : 'Noodcontacten bewaard.');
    } on Exception catch (error) {
      debugPrint('Noodcontacten bewaren mislukt: $error');
      _snack('Bewaren is niet gelukt. Probeer opnieuw.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _test() async {
    final contacts = _validated();
    if (contacts == null) return;
    final plan = planFor(contacts);
    if (plan.isEmpty) return _snack('Vul eerst een noodcontact in.');
    final phone = ref.read(emergencyPhoneProvider);
    final text = testSmsText(widget.senderName);
    final results = <String, SmsResult>{
      for (final contact in plan.smsTo) contact.name: await phone.sendSms(dialablePhone(contact.phone), text),
    };
    ref.invalidate(emergencySimProvider);
    if (results.values.every((result) => result == SmsResult.notAllowed)) {
      return phone.openSms(dialablePhone(plan.smsTo.first.phone), text);
    }
    String names(SmsResult wanted) => [
      for (final MapEntry(:key, :value) in results.entries)
        if (value == wanted) key,
    ].join(' en ');
    final sent = names(SmsResult.sent);
    final noService = names(SmsResult.noService);
    final failed = names(SmsResult.failed);
    _snack(
      [
        if (sent.isNotEmpty) 'Test-sms verstuurd naar $sent.',
        if (noService.isNotEmpty) 'Niet verstuurd naar $noService: geen gsm-netwerk of simkaart.',
        if (failed.isNotEmpty) 'Test-sms naar $failed mislukt.',
      ].join(' '),
    );
  }

  void _snack(String message) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    final contacts = ref.watch(myEmergencyContactsProvider);
    if (contacts.hasValue) _fill(contacts.requireValue);

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Noodcontacten'),
      body: SafeArea(
        child: !contacts.hasValue && contacts.isLoading
            ? const Center(child: CircularProgressIndicator())
            : ListView(
                padding: EdgeInsets.all(tokens.spaceMd),
                children: [
                  Text(
                    'Bij een SOS krijgen je noodcontacten automatisch een sms met je locatie, ook als ze '
                    'de app niet hebben. Contact 1 wordt daarna ook gebeld. De sms gaat van je eigen gsm '
                    'en werkt ook zonder internet.',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                  SizedBox(height: tokens.spaceMd),
                  EmergencyContactFields(
                    title: 'Contact 1',
                    role: 'Krijgt een sms en wordt gebeld',
                    name: _names[0],
                    phone: _phones[0],
                    error: _errors[0],
                  ),
                  SizedBox(height: tokens.spaceSm),
                  EmergencyContactFields(
                    title: 'Contact 2',
                    role: 'Krijgt een sms',
                    name: _names[1],
                    phone: _phones[1],
                    error: _errors[1],
                  ),
                  SizedBox(height: tokens.spaceMd),
                  const EmergencyAccessTile(),
                  SizedBox(height: tokens.spaceMd),
                  FilledButton(onPressed: _busy ? null : _save, child: const Text('Bewaren')),
                  SizedBox(height: tokens.spaceSm),
                  OutlinedButton.icon(
                    onPressed: _busy ? null : _test,
                    icon: const Icon(Icons.sms_outlined),
                    label: const Text('Stuur een test-sms'),
                  ),
                ],
              ),
      ),
    );
  }
}
