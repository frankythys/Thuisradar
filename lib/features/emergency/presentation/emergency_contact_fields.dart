import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../l10n/l10n.dart';

/// Naam en telefoonnummer van één noodcontact, met uitleg wat die krijgt.
class EmergencyContactFields extends StatelessWidget {
  const EmergencyContactFields({
    super.key,
    required this.title,
    required this.role,
    required this.name,
    required this.phone,
    this.error,
  });

  /// "Contact 1" of "Contact 2".
  final String title;

  /// Wat dit contact bij een SOS krijgt.
  final String role;
  final TextEditingController name;
  final TextEditingController phone;
  final String? error;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(title, style: text.titleMedium),
          Text(role, style: text.bodySmall?.copyWith(color: AppColors.muted)),
          SizedBox(height: tokens.spaceSm),
          TextField(
            controller: name,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
            decoration: InputDecoration(
              labelText: context.l10n.commonName,
              hintText: context.l10n.emergencyNameHint,
            ),
          ),
          SizedBox(height: tokens.spaceSm),
          TextField(
            controller: phone,
            keyboardType: TextInputType.phone,
            decoration: InputDecoration(
              labelText: context.l10n.emergencyPhoneLabel,
              hintText: context.l10n.emergencyPhoneHint,
              errorText: error,
            ),
          ),
        ],
      ),
    );
  }
}
