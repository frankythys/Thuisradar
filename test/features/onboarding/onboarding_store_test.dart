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
}
