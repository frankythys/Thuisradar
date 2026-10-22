import 'dart:async';

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
import 'features/map/data/map_view_store.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Eerst: zo staat elke (her)start van het proces in het locatielogboek.
  final locationDiagnostics = LocationDiagnostics(DiagnosticsStore())..start();
  final diagnostics = StartupDiagnostics();
  Env.assertConfigured();

  // Supabase en Firebase tegelijk: ze hangen niet van elkaar af. Firebase is
  // nodig voor push (SOS); faalt het, dan draait de app zonder push.
  final firebase = Firebase.initializeApp().then<void>(
    (_) => diagnostics.checkpoint('Firebase gereed'),
    onError: (Object e) => debugPrint('Firebase initialiseren mislukt: $e'),
  );
  // Taalkeuze en laatste kaartpositie vóór de eerste frame: de app opent
  // meteen in die taal en de kaart meteen op de juiste plek.
  final savedLanguage = LanguageStore().read().then(AppLanguage.fromCode, onError: (_) => null);
  final savedMapView = MapViewStore().read().then((view) => view, onError: (_) => null);

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);
  diagnostics.checkpoint('Supabase gereed');
  await firebase;

  diagnostics.watchFirstFrame();
  runApp(
    ProviderScope(
      overrides: [
        locationDiagnosticsProvider.overrideWithValue(locationDiagnostics),
        savedLanguageProvider.overrideWithValue(await savedLanguage),
        savedMapViewProvider.overrideWithValue(await savedMapView),
        startupDiagnosticsProvider.overrideWithValue(diagnostics),
      ],
      child: const ThuisradarApp(),
    ),
  );
}
