import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import 'biometric_login.dart';

@visibleForTesting
String derivePin((String, String) input) {
  final hmac = Hmac(sha256, utf8.encode(input.$1));
  var block = hmac.convert([...base64Decode(input.$2), 0, 0, 0, 1]).bytes;
  final result = List<int>.from(block);
  for (var i = 1; i < 100000; i++) {
    block = hmac.convert(block).bytes;
    for (var j = 0; j < result.length; j++) {
      result[j] ^= block[j];
    }
  }
  return base64Encode(result);
}

class PinLock {
  PinLock({FlutterSecureStorage? storage, DateTime Function()? now})
    : _storage = storage ?? const FlutterSecureStorage(),
      _now = now ?? DateTime.now;
  final FlutterSecureStorage _storage;
  final DateTime Function() _now;
  bool _checking = false;
  String _key(String id) => 'circlebeacon_pin_$id';
  Future<bool> enabledFor(String id) => _storage.containsKey(key: _key(id));
  Future<void> disable(String id) => _storage.delete(key: _key(id));

  Future<void> setPin(String id, String pin) async {
    if (!RegExp(r'^\d{6}$').hasMatch(pin)) throw StateError('Gebruik precies 6 cijfers.');
    final random = Random.secure();
    final salt = base64Encode(List.generate(16, (_) => random.nextInt(256)));
    final digest = await compute(derivePin, (pin, salt));
    await _storage.write(key: _key(id), value: jsonEncode({'salt': salt, 'digest': digest, 'failures': 0, 'until': 0}));
  }

  Future<bool> verify(String id, String pin) async {
    if (_checking) throw StateError('Een controle is al bezig.');
    _checking = true;
    try {
      final stored = await _storage.read(key: _key(id));
      if (stored == null) throw StateError('Stel eerst een toegangscode in via je profiel.');
      final data = jsonDecode(stored) as Map<String, dynamic>;
      final now = _now().millisecondsSinceEpoch;
      final until = data['until'] as int;
      if (until > now) throw StateError('Te veel pogingen. Wacht ${((until - now) / 1000).ceil()} seconden.');
      final digest = RegExp(r'^\d{6}$').hasMatch(pin) ? await compute(derivePin, (pin, data['salt'] as String)) : '';
      final expected = data['digest'] as String;
      var difference = digest.length ^ expected.length;
      for (var i = 0; i < min(digest.length, expected.length); i++) {
        difference |= digest.codeUnitAt(i) ^ expected.codeUnitAt(i);
      }
      final accepted = difference == 0;
      final failures = accepted ? 0 : (data['failures'] as int) + 1;
      data['failures'] = failures;
      data['until'] = !accepted && failures >= 5 ? now + min(900, 30 * (1 << min(failures - 5, 5))) * 1000 : 0;
      await _storage.write(key: _key(id), value: jsonEncode(data));
      return accepted;
    } finally {
      _checking = false;
    }
  }
}

final pinLockProvider = Provider((ref) => PinLock());
final pinEnabledProvider = FutureProvider.family<bool, String>((ref, id) => ref.watch(pinLockProvider).enabledFor(id));
final appLockEnabledProvider = FutureProvider.family<bool, String>((ref, id) async {
  final enrolled = await ref.watch(biometricLoginProvider).completeEnrollmentFor(id);
  if (enrolled) ref.invalidate(biometricEnabledProvider(id));
  final biometric = await ref.watch(biometricEnabledProvider(id).future);
  final pin = await ref.watch(pinEnabledProvider(id).future);
  return biometric || pin;
});
