import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'app.dart';
import 'core/config/env.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  Env.assertConfigured();

  await Supabase.initialize(url: Env.supabaseUrl, publishableKey: Env.supabaseKey);

  // Firebase is nodig voor push (SOS). Faalt dit, dan draait de app zonder push.
  try {
    await Firebase.initializeApp();
  } on Exception catch (e) {
    debugPrint('Firebase initialiseren mislukt: $e');
  }

  runApp(const ProviderScope(child: ThuisradarApp()));
}
