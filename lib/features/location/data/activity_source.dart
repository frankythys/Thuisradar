import 'package:activity_recognition_flutter/activity_recognition_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:permission_handler/permission_handler.dart';

import '../domain/motion_activity.dart';

/// De activiteitsherkenning van het toestel. Android: Google Play Services
/// Activity Recognition (Sampling API, een melding elke ±5 s), dezelfde
/// toestemming "Fysieke activiteit" als de stappenteller. iPhone: CoreMotion,
/// dat zelf om "Beweging en fitness" vraagt.
class ActivitySource {
  Future<bool> hasAccess() async {
    // Op iPhone niet via permission_handler: CoreMotion vraagt het zelf, en
    // het package waarschuwt dat de app anders crasht.
    if (defaultTargetPlatform == TargetPlatform.iOS) return true;
    try {
      return await Permission.activityRecognition.isGranted;
    } catch (error) {
      // Geen plugin (tests, ander platform): dan gewoon geen herkenning.
      debugPrint('Toestemming activiteitsherkenning onbekend: $error');
      return false;
    }
  }

  /// Elke herkenning van het toestel. Zonder eigen voorgronddienst: de
  /// locatiedienst houdt de app al wakker, een tweede vaste melding is
  /// overbodig.
  Stream<ActivityReading> readings() => ActivityRecognition()
      .activityStream(runForegroundService: false)
      .map((event) => ActivityReading(motionActivityOf(event.type), event.confidence, event.timeStamp));
}

/// Zet het type van het package om naar ons eigen model.
MotionActivity? motionActivityOf(ActivityType type) => switch (type) {
  ActivityType.IN_VEHICLE => MotionActivity.vehicle,
  ActivityType.ON_BICYCLE => MotionActivity.bicycle,
  ActivityType.ON_FOOT || ActivityType.WALKING || ActivityType.RUNNING => MotionActivity.foot,
  ActivityType.STILL => MotionActivity.still,
  ActivityType.TILTING || ActivityType.UNKNOWN => null,
};
