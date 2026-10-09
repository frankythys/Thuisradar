import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/onboarding/data/onboarding_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('hasSeen is standaard false en wordt true na markSeen', () async {
    SharedPreferences.setMockInitialValues({});
    final store = OnboardingStore();

    expect(await store.hasSeen(), isFalse);
    await store.markSeen();
    expect(await store.hasSeen(), isTrue);
  });

  test('oude introstatus telt niet als afgeronde onboarding', () async {
    SharedPreferences.setMockInitialValues({'onboarding_intro_seen': true});
    final store = OnboardingStore();
    expect(await store.hasSeen(), isFalse);
    expect(await OnboardingStore().hasSeen(), isFalse);
  });

  test('reset zet de onboarding terug op niet gezien', () async {
    SharedPreferences.setMockInitialValues({'onboarding_seen': true});
    final store = OnboardingStore();
    await store.reset();
    expect(await store.hasSeen(), isFalse);
  });
}
