import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/auth/data/pin_lock.dart';

class _Storage extends Mock implements FlutterSecureStorage {}

void main() {
  late _Storage storage;
  late Map<String, String> values;
  late DateTime now;
  late PinLock service;
  setUp(() {
    storage = _Storage();
    values = {};
    now = DateTime(2026, 10, 12);
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((call) async => values[call.namedArguments[#key]]);
    when(() => storage.containsKey(key: any(named: 'key')))
        .thenAnswer((call) async => values.containsKey(call.namedArguments[#key]));
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((call) async {
      values[call.namedArguments[#key] as String] = call.namedArguments[#value] as String;
    });
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((call) async {
      values.remove(call.namedArguments[#key]);
    });
    service = PinLock(storage: storage, now: () => now);
  });
  test('PBKDF2 komt overeen met een onafhankelijk berekende referentiewaarde', () {
    expect(
      derivePin(('123456', base64Encode(List.generate(16, (i) => i)))),
      'Pj0kIvAPLMHRutBFgZv7g2ARfVnFiANcQpTzQDrAl6U=',
    );
  });
  test('code wordt gehasht opgeslagen en werkt uitsluitend voor het ingestelde account', () async {
    await service.setPin('a', '123456');
    final data = jsonDecode(values.values.single) as Map<String, dynamic>;
    expect(data.containsKey('pin'), isFalse);
    expect(data['digest'], isNot('123456'));
    expect(await service.enabledFor('b'), isFalse);
    expect(await service.verify('a', '123456'), isTrue);
    expect(await service.verify('a', '654321'), isFalse);
    await expectLater(service.verify('b', '123456'), throwsStateError);
  });
  test('vijf fouten blokkeren ook na herstart; juiste code werkt na wachttijd', () async {
    await service.setPin('a', '123456');
    for (var i = 0; i < 5; i++) {
      expect(await service.verify('a', '000000'), isFalse);
    }
    service = PinLock(storage: storage, now: () => now);
    await expectLater(service.verify('a', '123456'), throwsStateError);
    now = now.add(const Duration(seconds: 31));
    expect(await service.verify('a', '123456'), isTrue);
    expect((jsonDecode(values.values.single) as Map)['failures'], 0);
  });
  test('wijzigen en uitschakelen verwijderen toegang via de oude code', () async {
    await service.setPin('a', '123456');
    await service.setPin('a', '654321');
    expect(await service.verify('a', '123456'), isFalse);
    expect(await service.verify('a', '654321'), isTrue);
    await service.disable('a');
    expect(await service.enabledFor('a'), isFalse);
  });
  test('alleen zes cijfers worden geaccepteerd', () async {
    for (final value in ['12', 'abcdef', '1234567']) {
      await expectLater(service.setPin('a', value), throwsStateError);
    }
    expect(values, isEmpty);
  });
}
