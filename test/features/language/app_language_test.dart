import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/language/domain/app_language.dart';

void main() {
  group('AppLanguage.fromCode', () {
    test('herkent een kale code en een code met regio', () {
      expect(AppLanguage.fromCode('nl'), AppLanguage.nl);
      expect(AppLanguage.fromCode('nl-BE'), AppLanguage.nl);
      expect(AppLanguage.fromCode('pt_BR'), AppLanguage.pt);
      expect(AppLanguage.fromCode('TR'), AppLanguage.tr);
    });

    test('onbekend of leeg geeft null', () {
      expect(AppLanguage.fromCode('ja'), isNull);
      expect(AppLanguage.fromCode(''), isNull);
      expect(AppLanguage.fromCode(null), isNull);
    });
  });

  group('resolveAppLanguage', () {
    test('eigen keuze wint van de toesteltaal', () {
      expect(resolveAppLanguage(override: 'fr', deviceLanguages: ['nl']), AppLanguage.fr);
    });

    test('zonder keuze: de toesteltaal', () {
      expect(resolveAppLanguage(deviceLanguages: ['de']), AppLanguage.de);
    });

    test('eerste ondersteunde taal uit de voorkeurslijst van het toestel', () {
      expect(resolveAppLanguage(deviceLanguages: ['ar', 'fr', 'en']), AppLanguage.fr);
    });

    test('niet ondersteund of geen talen: Engels', () {
      expect(resolveAppLanguage(deviceLanguages: ['ja', 'zh']), AppLanguage.en);
      expect(resolveAppLanguage(deviceLanguages: const []), AppLanguage.en);
    });

    test('een onbekende bewaarde keuze valt terug op de toesteltaal', () {
      expect(resolveAppLanguage(override: 'xx', deviceLanguages: ['it']), AppLanguage.it);
    });
  });
}
