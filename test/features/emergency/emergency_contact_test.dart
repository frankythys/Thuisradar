import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/emergency/domain/emergency_contact.dart';

void main() {
  const oma = EmergencyContact(position: 1, name: 'Oma', phone: '0470 12 34 56');
  const buur = EmergencyContact(position: 2, name: 'Buurman Jan', phone: '+32 471 98 76 54');

  group('telefoonnummer', () {
    test('Belgische en internationale nummers zijn geldig', () {
      expect(isValidPhone('0470 12 34 56'), isTrue);
      expect(isValidPhone('+32 (0)471-98.76.54'), isFalse);
      expect(isValidPhone('+32 471-98 76 54'), isTrue);
      expect(isValidPhone('12'), isFalse);
      expect(isValidPhone('bel me'), isFalse);
    });

    test('enkel cijfers en een + vooraan blijven over', () {
      expect(dialablePhone(' 0470 12 34 56 '), '0470123456');
      expect(dialablePhone('+32 (471) 98-76-54'), '+32471987654');
    });
  });

  group('planFor', () {
    test('sms naar beide, contact 1 eerst en contact 1 wordt gebeld', () {
      final plan = planFor([buur, oma]);
      expect(plan.smsTo, [oma, buur]);
      expect(plan.callTo, oma);
    });

    test('enkel contact 2: dat wordt ook gebeld', () {
      final plan = planFor([buur]);
      expect(plan.smsTo, [buur]);
      expect(plan.callTo, buur);
    });

    test('ongeldige of halve contacten tellen niet', () {
      final plan = planFor([
        const EmergencyContact(position: 1, name: 'Oma', phone: 'onbekend'),
        const EmergencyContact(position: 2, name: ' ', phone: '0470123456'),
      ]);
      expect(plan.isEmpty, isTrue);
      expect(plan.callTo, isNull);
    });

    test('hetzelfde nummer twee keer: één sms', () {
      final plan = planFor([oma, const EmergencyContact(position: 2, name: 'Oma gsm', phone: '0470123456')]);
      expect(plan.smsTo, [oma]);
    });

    test('geen contacten: niets', () {
      expect(planFor(const []).isEmpty, isTrue);
    });
  });

  test('de sms bevat de naam en een kaartlink met de locatie', () {
    final text = sosSmsText(senderName: 'Papa', latitude: 51.054301234, longitude: 3.7174);
    expect(text, startsWith('SOS van Papa: ik heb hulp nodig.'));
    expect(text, contains('https://maps.google.com/?q=51.05430,3.71740'));
    expect(sosSmsText(senderName: ' ', latitude: 0, longitude: 0), startsWith('SOS van Iemand van je gezin'));
  });

  test('foutmeldingen bij het invullen', () {
    expect(emergencyContactError('', ''), isNull);
    expect(emergencyContactError('Oma', ''), 'Geef een telefoonnummer.');
    expect(emergencyContactError('', '0470123456'), 'Geef een naam.');
    expect(emergencyContactError('Oma', 'abc'), 'Dit telefoonnummer klopt niet.');
    expect(emergencyContactError('Oma', '0470 12 34 56'), isNull);
  });

  test('json heen en terug', () {
    final json = oma.toJson('u1');
    expect(json['user_id'], 'u1');
    expect(EmergencyContact.fromJson(json), oma);
  });
}
