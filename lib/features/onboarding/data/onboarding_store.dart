import 'package:shared_preferences/shared_preferences.dart';

/// Onthoudt of de onboarding al getoond is, zodat die enkel de eerste keer
/// verschijnt.
class OnboardingStore {
  static const _seenKey = 'onboarding_seen';

  Future<bool> hasSeen() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_seenKey) ?? false;
  }

  Future<void> markSeen() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_seenKey, true);
  }
}
