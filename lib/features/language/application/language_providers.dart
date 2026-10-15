import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/language_store.dart';
import '../domain/app_language.dart';

final languageStoreProvider = Provider((ref) => LanguageStore());

/// De bij het opstarten gelezen keuze; `main.dart` vult die in, zodat de app
/// meteen in de juiste taal opent (geen flits in de toesteltaal).
final savedLanguageProvider = Provider<AppLanguage?>((ref) => null);

/// De eigen taalkeuze uit Profiel; `null` = de toesteltaal volgen.
final languageOverrideProvider = NotifierProvider<LanguageController, AppLanguage?>(LanguageController.new);

class LanguageController extends Notifier<AppLanguage?> {
  @override
  AppLanguage? build() => ref.watch(savedLanguageProvider);

  Future<void> choose(AppLanguage? language) async {
    state = language;
    try {
      await ref.read(languageStoreProvider).write(language?.code);
    } on Exception catch (error) {
      // De keuze geldt nu al; enkel na een herstart valt ze terug.
      debugPrint('Taalkeuze bewaren mislukt: $error');
    }
  }
}
