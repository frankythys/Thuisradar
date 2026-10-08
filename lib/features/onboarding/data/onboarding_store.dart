import 'package:shared_preferences/shared_preferences.dart';

/// Alleen een volledig afgeronde onboarding wordt blijvend onthouden.
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
