import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_repository.dart';

final biometricLoginProvider = Provider((ref) => BiometricLogin());

/// "Onthouden" bewaart enkel het e-mailadres. Het wachtwoord staat alleen op
/// het toestel zolang de vingerafdruk-login aan staat én je ingelogd bent:
/// uitloggen wist het ([forgetOnSignOut]). Versleuteld door het toestel, nooit
/// in gewone voorkeuren.
class BiometricLogin {
  BiometricLogin({LocalAuthentication? local, FlutterSecureStorage? storage})
    : _local = local ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();
  final LocalAuthentication _local;
  final FlutterSecureStorage _storage;
  static const _key = 'thuisradar_biometric_login';
  static const _rememberKey = 'thuisradar_remembered_login';

  /// Het onthouden e-mailadres. Een wachtwoord dat een oudere versie hier
  /// bewaarde, wordt meteen gewist.
  Future<String?> rememberedEmail() async {
    final stored = await _storage.read(key: _rememberKey);
    if (stored == null) return null;
    final data = jsonDecode(stored) as Map<String, dynamic>;
    final email = data['email'] as String;
    if (data.containsKey('password')) {
      await _storage.write(key: _rememberKey, value: jsonEncode({'email': email}));
    }
    return email;
  }

  /// Bij uitloggen: geen wachtwoord meer op het toestel. Het e-mailadres
  /// blijft (als "Onthouden" aan stond).
  Future<void> forgetOnSignOut() => disable();

  Future<void> forgetRememberedLogin() => _storage.delete(key: _rememberKey);

  /// Call only after the server has accepted these credentials.
  Future<void> rememberSuccessfulLogin({
    required String email,
    required String password,
    required bool remember,
  }) async {
    final value = jsonEncode({'email': email, 'password': password});
    final biometric = await _storage.read(key: _key);
    if (biometric != null) {
      final saved = jsonDecode(biometric) as Map<String, dynamic>;
      if ((saved['email'] as String).toLowerCase() == email.toLowerCase()) {
        await _storage.write(key: _key, value: value);
      } else {
        // Switching accounts must not retain biometric access to the old one.
        await disable();
      }
    }
    if (remember) {
      await _storage.write(key: _rememberKey, value: jsonEncode({'email': email}));
    } else {
      await forgetRememberedLogin();
    }
  }

  Future<bool> get enabled => _storage.containsKey(key: _key);
  Future<void> disable() => _storage.delete(key: _key);

  Future<bool> signIn(AuthRepository auth, {String? email, String? password, bool? remember}) async {
    if ((await _local.getAvailableBiometrics()).isEmpty) {
      throw StateError('Stel eerst een vingerafdruk of gezichtsherkenning in op je toestel.');
    }
    final accepted = await _local.authenticate(
      localizedReason: 'Bevestig dat jij inlogt bij CircleBeacon',
      biometricOnly: true,
    );
    if (!accepted) return false;
    final stored = await _storage.read(key: _key);
    final credentials = stored == null ? null : jsonDecode(stored) as Map<String, dynamic>;
    final loginEmail = credentials?['email'] as String? ?? email;
    final loginPassword = credentials?['password'] as String? ?? password;
    if (loginEmail == null || loginPassword == null) {
      throw StateError('Vul eerst je e-mailadres en wachtwoord in.');
    }
    await auth.signIn(email: loginEmail, password: loginPassword);
    if (stored == null) {
      await _storage.write(key: _key, value: jsonEncode({'email': loginEmail, 'password': loginPassword}));
    }
    if (remember != null) {
      await rememberSuccessfulLogin(email: loginEmail, password: loginPassword, remember: remember);
    }
    return true;
  }
}
