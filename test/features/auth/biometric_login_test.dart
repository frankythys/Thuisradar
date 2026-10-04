import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/auth/data/auth_repository.dart';
import 'package:thuisradar/features/auth/data/biometric_login.dart';

class _Local extends Mock implements LocalAuthentication {}

class _Storage extends Mock implements FlutterSecureStorage {}

class _Auth extends Mock implements AuthRepository {}

void main() {
  late _Local local;
  late _Storage storage;
  late _Auth auth;
  late BiometricLogin service;
  setUp(() {
    local = _Local();
    storage = _Storage();
    auth = _Auth();
    service = BiometricLogin(local: local, storage: storage);
    when(() => local.getAvailableBiometrics())
        .thenAnswer((_) async => [BiometricType.fingerprint]);
    when(
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
      ),
    ).thenAnswer((_) async => true);
    when(() => storage.read(key: any(named: 'key')))
        .thenAnswer((_) async => null);
    when(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    ).thenAnswer((_) async {});
  });
  test('annuleren leest geen credentials en logt niet in', () async {
    when(
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
      ),
    ).thenAnswer((_) async => false);
    expect(await service.signIn(auth), isFalse);
    verifyNever(() => storage.read(key: any(named: 'key')));
    verifyNever(
      () => auth.signIn(
        email: any(named: 'email'),
        password: any(named: 'password'),
      ),
    );
  });
  test('mislukte aanmelding slaat geen wachtwoord op', () async {
    when(() => auth.signIn(email: 'test@example.com', password: 'invalid'))
        .thenThrow(Exception('invalid'));
    await expectLater(
      service.signIn(auth, email: 'test@example.com', password: 'invalid'),
      throwsException,
    );
    verifyNever(
      () => storage.write(
        key: any(named: 'key'),
        value: any(named: 'value'),
      ),
    );
  });
  test('opgeslagen login wordt alleen na biometrie gebruikt', () async {
    when(() => storage.read(key: any(named: 'key'))).thenAnswer(
      (_) async => '{"email":"test@example.com","password":"test-only"}',
    );
    when(() => auth.signIn(email: 'test@example.com', password: 'test-only'))
        .thenAnswer((_) async {});
    expect(await service.signIn(auth), isTrue);
    verifyInOrder([
      () => local.authenticate(
        localizedReason: any(named: 'localizedReason'),
        biometricOnly: true,
      ),
      () => storage.read(key: any(named: 'key')),
      () => auth.signIn(email: 'test@example.com', password: 'test-only'),
    ]);
  });
}
