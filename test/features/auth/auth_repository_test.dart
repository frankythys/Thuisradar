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
}
