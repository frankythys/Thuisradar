import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/data/pin_lock.dart';
import 'profile_tile.dart';

class PinSettingsTile extends ConsumerWidget {
  const PinSettingsTile({super.key, required this.userId});
  final String userId;
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(pinEnabledProvider(userId));
    return ProfileTile(
      icon: Icons.pin_outlined,
      title: 'Toegangscode',
      subtitle: enabled.value == true ? 'Aan · wijzigen of uitschakelen' : 'Stel een code van 6 cijfers in',
      onTap: enabled.isLoading
          ? null
          : () => showDialog<void>(
              context: context,
              builder: (_) => _PinSettings(userId: userId, enabled: enabled.value == true),
            ),
    );
  }
}

class _PinSettings extends ConsumerStatefulWidget {
  const _PinSettings({required this.userId, required this.enabled});
  final String userId;
  final bool enabled;
  @override
  ConsumerState<_PinSettings> createState() => _PinSettingsState();
}

class _PinSettingsState extends ConsumerState<_PinSettings> {
  final _pin = TextEditingController();
  final _confirm = TextEditingController();
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _pin.dispose();
    _confirm.dispose();
    super.dispose();
  }

  Future<void> _save({bool remove = false}) async {
    if (_busy) return;
    if (!remove && (_pin.text.length != 6 || _pin.text != _confirm.text)) {
      setState(() => _error = 'Vul twee keer dezelfde code van 6 cijfers in.');
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final service = ref.read(pinLockProvider);
      if (remove) {
        await service.disable(widget.userId);
      } else {
        await service.setPin(widget.userId, _pin.text);
      }
      ref.invalidate(pinEnabledProvider(widget.userId));
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) setState(() => _error = 'Opslaan is niet gelukt. Probeer opnieuw.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _field(TextEditingController controller, String label) => TextField(
    controller: controller,
    enabled: !_busy,
    obscureText: true,
    keyboardType: TextInputType.number,
    maxLength: 6,
    inputFormatters: [FilteringTextInputFormatter.digitsOnly],
    decoration: InputDecoration(labelText: label, counterText: ''),
  );
  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Toegangscode'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _field(_pin, 'Nieuwe code (6 cijfers)'),
        const SizedBox(height: 16),
        _field(_confirm, 'Herhaal de code'),
        if (_error != null) Text(_error!),
      ],
    ),
    actions: [
      if (widget.enabled)
        TextButton(onPressed: _busy ? null : () => _save(remove: true), child: const Text('Uitschakelen')),
      TextButton(onPressed: _busy ? null : () => Navigator.pop(context), child: const Text('Annuleren')),
      FilledButton(onPressed: _busy ? null : _save, child: Text(_busy ? 'Opslaan…' : 'Opslaan')),
    ],
  );
}
