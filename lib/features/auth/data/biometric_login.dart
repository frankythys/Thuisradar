import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';

final biometricLoginProvider = Provider((ref) => BiometricLogin());

/// Biometrie ontgrendelt een bestaande sessie; bewaart nooit wachtwoorden.
class BiometricLogin {
  BiometricLogin({LocalAuthentication? local, FlutterSecureStorage? storage})
    : _local = local ?? LocalAuthentication(),
      _storage = storage ?? const FlutterSecureStorage();
  final LocalAuthentication _local;
  final FlutterSecureStorage _storage;
  static const _key = 'thuisradar_biometric_login';
  static const _userKey = 'circlebeacon_biometric_user';
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
    await _storage.delete(key: _key); // Verwijder oude opgeslagen wachtwoorden.
    if (remember) {
      await _storage.write(key: _rememberKey, value: jsonEncode({'email': email}));
    } else {
      await forgetRememberedLogin();
    }
  }

  Future<bool> enabledFor(String userId) async => await _storage.read(key: _userKey) == userId;

  Future<void> disable() async {
    await _storage.delete(key: _key);
    await _storage.delete(key: _userKey);
  }

  Future<bool> enableFor(String userId) async {
    if (!await authenticate()) return false;
    await _storage.delete(key: _key);
    await _storage.write(key: _userKey, value: userId);
    return true;
  }

  Future<bool> authenticate() async {
    if ((await _local.getAvailableBiometrics()).isEmpty) {
      throw StateError('Stel eerst een vingerafdruk of gezichtsherkenning in op je toestel.');
    }
    return _local.authenticate(
      localizedReason: 'Ontgrendel CircleBeacon',
      biometricOnly: true,
      persistAcrossBackgrounding: true,
    );
  }
}

final biometricEnabledProvider = FutureProvider.family<bool, String>(
  (ref, userId) => ref.watch(biometricLoginProvider).enabledFor(userId),
);

/// Een expliciete vergrendeling vanuit het profiel, zonder de sessie te beëindigen.
class BiometricLockRequest extends Notifier<int> {
  @override
  int build() => 0;

  void lock() => state++;
}

final biometricLockRequestProvider = NotifierProvider<BiometricLockRequest, int>(BiometricLockRequest.new);
