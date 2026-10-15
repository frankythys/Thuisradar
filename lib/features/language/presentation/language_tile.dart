import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../l10n/l10n.dart';
import '../../profile/presentation/profile_tile.dart';
import '../application/language_providers.dart';
import 'language_sheet.dart';

/// Rij in Profiel: toont de huidige taal en opent de taalkeuze.
class LanguageTile extends ConsumerWidget {
  const LanguageTile({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chosen = ref.watch(languageOverrideProvider);
    return ProfileTile(
      icon: Icons.translate,
      title: context.l10n.languageTitle,
      subtitle: chosen?.nativeName ?? context.l10n.languageDevice,
      onTap: () => showLanguageSheet(context),
    );
  }
}
