import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';
import 'core/utils/startup_diagnostics.dart';
import 'features/language/application/language_providers.dart';
import 'features/language/data/language_store.dart';
import 'features/language/domain/app_language.dart';
import 'features/location/application/location_diagnostics.dart';
import 'features/location/data/diagnostics_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Eerst: zo staat elke (her)start van het proces in het locatielogboek.
  final locationDiagnostics = LocationDiagnostics(DiagnosticsStore())..start();
  final diagnostics = StartupDiagnostics();
  Env.assertConfigured();

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  diagnostics.checkpoint('Supabase gereed');

  // Firebase is nodig voor push (SOS). Faalt dit, dan draait de app zonder push.
  try {
    await Firebase.initializeApp();
  } on Exception catch (e) {
    debugPrint('Firebase initialiseren mislukt: $e');
  }
  diagnostics.checkpoint('Firebase gereed of overgeslagen');

  // Taalkeuze vóór de eerste frame, zodat de app meteen in die taal opent.
  final savedLanguage = await LanguageStore().read().then(AppLanguage.fromCode, onError: (_) => null);

  diagnostics.watchFirstFrame();
  runApp(
    ProviderScope(
      overrides: [
        locationDiagnosticsProvider.overrideWithValue(locationDiagnostics),
        savedLanguageProvider.overrideWithValue(savedLanguage),
      ],
      child: const ThuisradarApp(),
    ),
  );
}
