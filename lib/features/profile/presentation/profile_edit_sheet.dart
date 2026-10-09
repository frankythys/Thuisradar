import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';

/// Resultaat van het bewerk-venster.
typedef ProfileEdit = ({String name, String phone, int colorIndex});

/// Onderblad om naam, telefoonnummer en kaartkleur aan te passen.
Future<ProfileEdit?> showProfileEditSheet(
  BuildContext context, {
  required String name,
  required String phone,
  required int colorIndex,
}) {
  return showModalBottomSheet<ProfileEdit>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _EditSheet(name: name, phone: phone, colorIndex: colorIndex),
  );
}

class _EditSheet extends StatefulWidget {
  const _EditSheet({required this.name, required this.phone, required this.colorIndex});

  final String name;
  final String phone;
  final int colorIndex;

  @override
  State<_EditSheet> createState() => _EditSheetState();
}

class _EditSheetState extends State<_EditSheet> {
  late final _name = TextEditingController(text: widget.name);
  late final _phone = TextEditingController(text: widget.phone);
  late int _color = widget.colorIndex;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  void _save() {
    final name = _name.text.trim();
    final phone = _phone.text.trim();
    if (name.isEmpty) return setState(() => _error = 'Vul je naam in.');
    if (phone.isNotEmpty && !RegExp(r'^\+?[0-9 ()-]{6,24}$').hasMatch(phone)) {
      return setState(() => _error = 'Dat telefoonnummer klopt niet.');
    }
    Navigator.pop<ProfileEdit>(context, (name: name, phone: phone, colorIndex: _color));
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return Padding(
      padding: EdgeInsets.fromLTRB(
        tokens.spaceLg,
        0,
        tokens.spaceLg,
        tokens.spaceLg + MediaQuery.viewInsetsOf(context).bottom,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('Profiel bewerken', style: text.titleLarge),
          SizedBox(height: tokens.spaceMd),
          TextField(
            controller: _name,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Naam'),
          ),
          SizedBox(height: tokens.spaceSm),
          TextField(
            controller: _phone,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Telefoonnummer voor je gezin', hintText: '+32 …'),
          ),
          SizedBox(height: tokens.spaceMd),
          Text('Kaartkleur', style: text.titleSmall),
          SizedBox(height: tokens.spaceSm),
          Wrap(
            spacing: tokens.spaceSm,
            children: [
              for (var i = 0; i < tokens.memberColors.length; i++)
                Semantics(
                  label: 'Kaartkleur ${i + 1}',
                  selected: _color == i,
                  child: InkWell(
                    onTap: () => setState(() => _color = i),
                    customBorder: const CircleBorder(),
                    child: CircleAvatar(
                      radius: 18,
                      backgroundColor: tokens.memberColor(i),
                      child: _color == i
                          ? Icon(Icons.check, color: Theme.of(context).colorScheme.onPrimary, size: 18)
                          : null,
                    ),
                  ),
                ),
            ],
          ),
          if (_error != null) ...[
            SizedBox(height: tokens.spaceSm),
            Text(_error!, style: text.bodySmall?.copyWith(color: AppColors.alert)),
          ],
          SizedBox(height: tokens.spaceLg),
          FilledButton(onPressed: _save, child: const Text('Opslaan')),
        ],
      ),
    );
  }
}
