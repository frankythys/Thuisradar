import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/emergency/application/emergency_alerter.dart';
import 'package:thuisradar/features/emergency/data/emergency_phone.dart';
import 'package:thuisradar/features/emergency/domain/emergency_contact.dart';

class _MockPhone extends Mock implements EmergencyPhone {}

void main() {
  const oma = EmergencyContact(position: 1, name: 'Oma', phone: '0470 12 34 56');
  const jan = EmergencyContact(position: 2, name: 'Jan', phone: '+32 471 98 76 54');
  late _MockPhone phone;
  late EmergencyAlerter alerter;
  late List<String> log;

  setUp(() {
    phone = _MockPhone();
    alerter = EmergencyAlerter(phone);
    log = [];
    when(() => phone.sendSms(any(), any())).thenAnswer((call) async {
      log.add('sms ${call.positionalArguments.first}');
      return true;
    });
    when(() => phone.call(any())).thenAnswer((call) async {
      log.add('bel ${call.positionalArguments.first}');
      return true;
    });
    when(() => phone.openSms(any(), any())).thenAnswer((call) async {
      log.add('open sms ${call.positionalArguments.first}');
    });
  });

  Future<EmergencyOutcome> alert(List<EmergencyContact> contacts) =>
      alerter.alert(contacts: contacts, senderName: 'Papa', latitude: 51.0543, longitude: 3.7174);

  test('automatisch: eerst sms naar allebei, daarna contact 1 bellen', () async {
    final outcome = await alert([jan, oma]);
    expect(log, ['sms 0470123456', 'sms +32471987654', 'bel 0470123456']);
    expect(outcome.summary, 'Sms naar Oma en Jan, nu bellen naar Oma.');
    final text = verify(() => phone.sendSms('0470123456', captureAny())).captured.single as String;
    expect(text, contains('SOS van Papa'));
    expect(text, contains('51.05430,3.71740'));
  });

  test('zonder toestemming: de berichten-app opent voor contact 1, niet bellen', () async {
    when(() => phone.sendSms(any(), any())).thenAnswer((_) async => false);
    final outcome = await alert([oma, jan]);
    expect(log, ['open sms 0470123456']);
    verifyNever(() => phone.call(any()));
    expect(outcome.manual, oma);
    expect(outcome.summary, "Tik op versturen om Oma te sms'en.");
  });

  test('bellen lukt niet: de sms is wel vertrokken', () async {
    when(() => phone.call(any())).thenAnswer((_) async => false);
    final outcome = await alert([oma]);
    expect(outcome.texted, [oma]);
    expect(outcome.called, isNull);
    expect(outcome.summary, 'Sms naar Oma.');
  });

  test('geen noodcontacten: niets', () async {
    final outcome = await alert(const []);
    expect(log, isEmpty);
    expect(outcome.summary, isNull);
  });
}
