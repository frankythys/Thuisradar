import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:thuisradar/features/auth/data/auth_repository.dart';

class _Client extends Mock implements SupabaseClient {}

class _Auth extends Mock implements GoTrueClient {}

void main() {
  test('een netwerkfout bij het verversen van het token is geen fout in de sessiestroom', () async {
    final client = _Client();
    final auth = _Auth();
    final changes = StreamController<AuthState>();
    addTearDown(changes.close);
    when(() => client.auth).thenReturn(auth);
    when(() => auth.currentSession).thenReturn(null);
    when(() => auth.onAuthStateChange).thenAnswer((_) => changes.stream);

    final events = <Session?>[];
    final errors = <Object>[];
    final subscription = AuthRepository(client).watchSession().listen(events.add, onError: errors.add);
    addTearDown(subscription.cancel);

    changes.addError(AuthRetryableFetchException(message: 'geen bereik'));
    changes.add(const AuthState(AuthChangeEvent.signedOut, null));
    await pumpEventQueue();

    expect(errors, isEmpty);
    expect(events, [null, null]);
  });

  test('registreren: de bevestigingsmail leidt naar de pagina /bevestigd', () async {
    final client = _Client();
    final auth = _Auth();
    when(() => client.auth).thenReturn(auth);
    when(
      () => auth.signUp(
        email: any(named: 'email'),
        password: any(named: 'password'),
        data: any(named: 'data'),
        emailRedirectTo: any(named: 'emailRedirectTo'),
      ),
    ).thenAnswer((_) async => AuthResponse());

    final signedIn = await AuthRepository(client)
        .signUp(email: 'oma@example.com', password: 'Geheim-123', displayName: 'Oma');

    expect(signedIn, isFalse);
    verify(
      () => auth.signUp(
        email: 'oma@example.com',
        password: 'Geheim-123',
        data: {'display_name': 'Oma'},
        emailRedirectTo: 'https://circlebeacon.frankythys.workers.dev/bevestigd',
      ),
    ).called(1);
  });

  test('wachtwoord vergeten: de herstellink opent de app', () async {
    final client = _Client();
    final auth = _Auth();
    when(() => client.auth).thenReturn(auth);
    when(() => auth.resetPasswordForEmail(any(), redirectTo: any(named: 'redirectTo')))
        .thenAnswer((_) async {});

    await AuthRepository(client).resetPassword('oma@example.com');

    verify(
      () =>
          auth.resetPasswordForEmail('oma@example.com', redirectTo: 'com.circlebeacon.app://login-callback/'),
    ).called(1);
  });

  test('herstelcode: gecontroleerd als type recovery bij het juiste adres', () async {
    final client = _Client();
    final auth = _Auth();
    when(() => client.auth).thenReturn(auth);
    when(
      () => auth.verifyOTP(
        type: OtpType.recovery,
        email: any(named: 'email'),
        token: any(named: 'token'),
      ),
    ).thenAnswer((_) async => AuthResponse());

    await AuthRepository(client).verifyRecoveryCode(email: 'oma@example.com', code: '123456');

    verify(() => auth.verifyOTP(type: OtpType.recovery, email: 'oma@example.com', token: '123456')).called(1);
  });
}
