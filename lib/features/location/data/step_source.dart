import 'package:flutter/foundation.dart';
import 'package:pedometer/pedometer.dart';
import 'package:permission_handler/permission_handler.dart';

/// De stappenteller van het toestel. Android: de hardwareteller (totaal sinds
/// de laatste herstart), vraagt "Fysieke activiteit". iPhone: CMPedometer
/// (totaal sinds de app luistert), vraagt "Beweging en fitness".
class StepSource {
  Permission get _permission =>
      defaultTargetPlatform == TargetPlatform.iOS ? Permission.sensors : Permission.activityRecognition;

  Future<bool> hasAccess() async {
    try {
      return await _permission.isGranted;
    } catch (error) {
      // Geen plugin (tests, ander platform): dan gewoon geen stappen.
      debugPrint('Stappenteller-toestemming onbekend: $error');
      return false;
    }
  }

  Future<bool> requestAccess() async {
    try {
      return (await _permission.request()).isGranted;
    } catch (error) {
      debugPrint('Stappenteller-toestemming vragen mislukt: $error');
      return false;
    }
  }

  /// De stand van de teller, telkens hij verandert. Een toestel zonder
  /// stappenteller geeft een fout op deze stroom.
  Stream<int> counts() => Pedometer.stepCountStream.map((count) => count.steps);
}
