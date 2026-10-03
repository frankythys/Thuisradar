import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/features/notifications/data/notifications_store.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('clearedAt is standaard null en onthoudt het wis-tijdstip per familie', () async {
    SharedPreferences.setMockInitialValues({});
    final store = NotificationsStore();

    expect(await store.clearedAt('fam'), isNull);

    final moment = DateTime(2026, 1, 2, 17, 42);
    await store.clear('fam', moment);

    expect(await store.clearedAt('fam'), moment);
    // Andere familie blijft ongewijzigd.
    expect(await store.clearedAt('andere'), isNull);
  });
}
