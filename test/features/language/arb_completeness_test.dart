import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/language/domain/app_language.dart';

Map<String, dynamic> _arb(String code) =>
    jsonDecode(File('lib/l10n/app_$code.arb').readAsStringSync()) as Map<String, dynamic>;

Iterable<String> _keys(Map<String, dynamic> arb) => arb.keys.where((key) => !key.startsWith('@'));

/// `{naam}`-placeholders, bv. `{count}` en `{code}`. Takken van een ICU-keuze
/// (`1{ma}`, `other{zo}`, `=1{…}`) tellen niet mee: daar staat een woord of `=`
/// vlak voor de accolade.
Set<String> _placeholders(String text) =>
    RegExp(r'(?<![\w=])\{(\w+)[},]').allMatches(text).map((m) => m[1]!).toSet();

void main() {
  final source = _arb('nl');

  test('elke sleutel in het Nederlands heeft een beschrijving', () {
    for (final key in _keys(source)) {
      expect(source['@$key'], isA<Map<String, dynamic>>(), reason: '@$key ontbreekt in app_nl.arb');
    }
  });

  for (final language in AppLanguage.values) {
    test('app_${language.code}.arb is volledig en houdt de placeholders', () {
      final arb = _arb(language.code);
      expect(arb['@@locale'], language.code);
      expect(_keys(arb).toSet(), _keys(source).toSet());
      for (final key in _keys(source)) {
        final text = arb[key] as String;
        expect(text.trim(), isNotEmpty, reason: '$key is leeg in ${language.code}');
        expect(
          _placeholders(text),
          _placeholders(source[key] as String),
          reason: '$key: andere placeholders in ${language.code}',
        );
      }
    });
  }
}
