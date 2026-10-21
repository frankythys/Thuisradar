import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/l10n/l10n.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/features/emergency/application/emergency_alerter.dart';
import 'package:thuisradar/features/emergency/data/emergency_phone.dart';
import 'package:thuisradar/features/emergency/domain/emergency_contact.dart';

class _MockPhone extends Mock implements EmergencyPhone {}

final _nl = lookupAppLocalizations(const Locale('nl'));

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
    when(() => phone.openSms(any(), any())).thenAnswer((call) async {
      log.add('open sms ${call.positionalArguments.first}');
    });
  });

  Future<EmergencyOutcome> alert(List<EmergencyContact> contacts) =>
      alerter.alert(l10n: _nl, contacts: contacts, senderName: 'Papa', latitude: 51.0543, longitude: 3.7174);

  test('de berichten-app opent met de sms klaar voor contact 1', () async {
    final outcome = await alert([jan, oma]);
    expect(log, ['open sms 0470123456']);
    expect(outcome.manual, oma);
    expect(outcome.summary(_nl), "Tik op versturen om Oma te sms'en.");
    final text = verify(() => phone.openSms('0470123456', captureAny())).captured.single as String;
    expect(text, contains('SOS van Papa'));
    expect(text, contains('51.05430,3.71740'));
  });

  test('zonder contact 1: de sms staat klaar voor het andere contact', () async {
    final outcome = await alert([jan]);
    expect(log, ['open sms +32471987654']);
    expect(outcome.manual, jan);
  });

  test('geen noodcontacten: niets', () async {
    final outcome = await alert(const []);
    expect(log, isEmpty);
    expect(outcome.summary(_nl), isNull);
  });
}
