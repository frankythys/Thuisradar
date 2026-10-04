import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

import 'auth_repository.dart';

final biometricLoginProvider = Provider((ref) => BiometricLogin());

/// Opt-in credentials, encrypted by the device; never stored in preferences.
class BiometricLogin {
  BiometricLogin({LocalAuthentication? local, FlutterSecureStorage? storage})
    : _local = local ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();
  final LocalAuthentication _local;
  final FlutterSecureStorage _storage;
  static const _key = 'thuisradar_biometric_login';

  Future<bool> get enabled => _storage.containsKey(key: _key);
  Future<void> disable() => _storage.delete(key: _key);

  Future<bool> signIn(
    AuthRepository auth, {
    String? email,
    String? password,
  }) async {
    if ((await _local.getAvailableBiometrics()).isEmpty) {
      throw StateError(
        'Stel eerst een vingerafdruk of gezichtsherkenning in op je toestel.',
      );
    }
    final accepted = await _local.authenticate(
      localizedReason: 'Bevestig dat jij inlogt bij Thuisradar',
      biometricOnly: true,
    );
    if (!accepted) return false;
    final stored = await _storage.read(key: _key);
    final credentials = stored == null
        ? null
        : jsonDecode(stored) as Map<String, dynamic>;
    final loginEmail = credentials?['email'] as String? ?? email;
    final loginPassword = credentials?['password'] as String? ?? password;
    if (loginEmail == null || loginPassword == null) {
      throw StateError('Vul eerst je e-mailadres en wachtwoord in.');
    }
    await auth.signIn(email: loginEmail, password: loginPassword);
    if (stored == null) {
      await _storage.write(
        key: _key,
        value: jsonEncode({'email': loginEmail, 'password': loginPassword}),
      );
    }
    return true;
  }
}
