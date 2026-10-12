import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/auth/data/biometric_login.dart';

class _Local extends Mock implements LocalAuthentication {}

class _Storage extends Mock implements FlutterSecureStorage {}

void main() {
  late _Local local;
  late _Storage storage;
  late BiometricLogin service;
  setUp(() {
    local = _Local();
    storage = _Storage();
    service = BiometricLogin(local: local, storage: storage);
    when(() => storage.delete(key: any(named: 'key'))).thenAnswer((_) async {});
    when(() => storage.read(key: any(named: 'key'))).thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
    when(() => local.getAvailableBiometrics()).thenAnswer((_) async => [BiometricType.fingerprint]);
    when(
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      ),
    ).thenAnswer((_) async => true);
  });
  test('Google-account schakelt biometrie in zonder wachtwoord, na scan', () async {
    expect(await service.enableFor('google-user'), isTrue);
    verifyInOrder([
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      ),
      () => storage.delete(key: 'thuisradar_biometric_login'),
      () => storage.write(key: 'circlebeacon_biometric_user', value: 'google-user'),
    ]);
  });
  test('annuleren schakelt biometrie niet in', () async {
    when(
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      ),
    ).thenAnswer((_) async => false);
    expect(await service.enableFor('user'), isFalse);
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });
  test('voorkeur geeft een ander account geen biometrische toegang', () async {
    when(() => storage.read(key: 'circlebeacon_biometric_user')).thenAnswer((_) async => 'user-a');
    expect(await service.enabledFor('user-a'), isTrue);
    expect(await service.enabledFor('user-b'), isFalse);
  });
  test('zonder geregistreerde biometrie geen toegang', () async {
    when(() => local.getAvailableBiometrics()).thenAnswer((_) async => []);
    await expectLater(service.authenticate(), throwsStateError);
    verifyNever(
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
        persistAcrossBackgrounding: true,
      ),
    );
  });
  test('onthouden bewaart enkel e-mail en verwijdert oude biometrische wachtwoorden', () async {
    await service.rememberSuccessfulLogin(email: 'a@example.com', password: 'secret', remember: true);
    verify(() => storage.delete(key: 'thuisradar_biometric_login')).called(1);
    verify(() => storage.write(key: 'thuisradar_remembered_login', value: '{"email":"a@example.com"}')).called(1);
    verifyNever(
      () => storage.write(
        key: 'thuisradar_biometric_login',
        value: any(named: 'value'),
      ),
    );
  });
  test('uitloggen verwijdert biometrische voorkeur en oude credentials', () async {
    await service.forgetOnSignOut();
    verify(() => storage.delete(key: 'circlebeacon_biometric_user')).called(1);
    verify(() => storage.delete(key: 'thuisradar_biometric_login')).called(1);
    verifyNever(() => storage.delete(key: 'thuisradar_remembered_login'));
  });
  test('oud onthouden wachtwoord wordt verwijderd', () async {
    when(() => storage.read(key: 'thuisradar_remembered_login'))
        .thenAnswer((_) async => '{"email":"a@example.com","password":"old"}');
    expect(await service.rememberedEmail(), 'a@example.com');
    verify(() => storage.write(key: 'thuisradar_remembered_login', value: '{"email":"a@example.com"}')).called(1);
  });
}
