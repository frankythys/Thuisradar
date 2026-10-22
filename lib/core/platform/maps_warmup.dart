import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:google_maps_flutter_android/google_maps_flutter_android.dart';
import 'package:google_maps_flutter_platform_interface/google_maps_flutter_platform_interface.dart';

import '../config/feature_flags.dart';

/// Start de Google Maps-motor al bij het opstarten, terwijl de app nog op
/// Supabase en het gezin wacht. Anders begint dat zware werk (module laden,
/// tekenmotor) pas als het kaartscherm de eerste kaart aanmaakt.
///
/// Mag maar één keer per proces: bij een hot restart in debug weigert Android
/// een tweede keer, en dat is dan geen probleem.
Future<void> warmUpGoogleMaps() async {
  if (!FeatureFlags.useGoogleMaps || defaultTargetPlatform != TargetPlatform.android) return;
  final platform = GoogleMapsFlutterPlatform.instance;
  if (platform is! GoogleMapsFlutterAndroid) return;
  try {
    await platform.initializeWithRenderer(AndroidMapRenderer.latest);
  } on PlatformException catch (error) {
    debugPrint('Google Maps was al opgewarmd: ${error.message}');
  }
}
