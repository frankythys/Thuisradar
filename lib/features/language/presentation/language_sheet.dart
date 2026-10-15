import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../l10n/l10n.dart';
import '../application/language_providers.dart';
import '../domain/app_language.dart';

/// Onderblad met "Toesteltaal" en elke taal in haar eigen naam. Een keuze
/// geldt meteen: de hele app schakelt om zonder herstart.
Future<void> showLanguageSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => const _LanguageSheet(),
  );
}

class _LanguageSheet extends ConsumerWidget {
  const _LanguageSheet();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final l10n = context.l10n;
    final chosen = ref.watch(languageOverrideProvider);

    Widget option(AppLanguage? language, String title, {String? subtitle}) => ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: subtitle == null ? null : Text(subtitle),
      trailing: chosen == language ? const Icon(Icons.check, color: AppColors.primary) : null,
      selected: chosen == language,
      onTap: () {
        Navigator.pop(context);
        unawaited(ref.read(languageOverrideProvider.notifier).choose(language));
      },
    );

    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(tokens.spaceLg, 0, tokens.spaceLg, tokens.spaceLg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(l10n.languageTitle, style: Theme.of(context).textTheme.titleLarge),
            SizedBox(height: tokens.spaceSm),
            option(null, l10n.languageDevice, subtitle: l10n.languageDeviceSubtitle),
            const Divider(height: 1),
            for (final language in AppLanguage.values) option(language, language.nativeName),
          ],
        ),
      ),
    );
  }
}
