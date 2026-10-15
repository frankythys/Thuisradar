import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/auth/application/auth_providers.dart';
import 'package:thuisradar/features/emergency/application/emergency_providers.dart';
import 'package:thuisradar/features/emergency/data/emergency_contact_cache.dart';
import 'package:thuisradar/features/emergency/data/emergency_contact_repository.dart';
import 'package:thuisradar/features/emergency/data/emergency_phone.dart';
import 'package:thuisradar/features/emergency/domain/emergency_contact.dart';
import 'package:thuisradar/features/emergency/presentation/emergency_contacts_screen.dart';
import 'package:thuisradar/features/sos/presentation/widgets/sos_emergency_line.dart';

class _MockRepository extends Mock implements EmergencyContactRepository {}

class _MockCache extends Mock implements EmergencyContactCache {}

class _MockPhone extends Mock implements EmergencyPhone {}

const _oma = EmergencyContact(position: 1, name: 'Oma', phone: '0470 12 34 56');
const _jan = EmergencyContact(position: 2, name: 'Jan', phone: '0471 98 76 54');

void main() {
  late _MockRepository repository;
  late _MockCache cache;
  late _MockPhone phone;

  setUp(() {
    repository = _MockRepository();
    cache = _MockCache();
    phone = _MockPhone();
    when(() => repository.save(any(), any())).thenAnswer((_) async {});
    when(() => cache.write(any(), any())).thenAnswer((_) async {});
    when(() => phone.canSendAutomatically()).thenAnswer((_) async => true);
  });

  List<Override> overrides(List<EmergencyContact> contacts, {bool automatic = true}) => [
    currentUserIdProvider.overrideWithValue('me'),
    myEmergencyContactsProvider.overrideWith((ref) async => contacts),
    emergencyAutomaticProvider.overrideWith((ref) async => automatic),
    emergencyContactRepositoryProvider.overrideWithValue(repository),
    emergencyContactCacheProvider.overrideWithValue(cache),
    emergencyPhoneProvider.overrideWithValue(phone),
  ];

  Future<void> pumpScreen(WidgetTester tester, List<EmergencyContact> contacts) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: overrides(contacts),
        child: MaterialApp(
          theme: AppTheme.light(),
          home: const EmergencyContactsScreen(senderName: 'Papa'),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  testWidgets('bestaande contacten staan ingevuld; een fout nummer wordt niet bewaard', (tester) async {
    await pumpScreen(tester, const [_oma]);
    expect(find.text('Oma'), findsOneWidget);
    expect(find.text('0470 12 34 56'), findsOneWidget);

    final fields = find.byType(TextField);
    await tester.enterText(fields.at(2), 'Jan');
    await tester.enterText(fields.at(3), 'geen nummer');
    await tester.scrollUntilVisible(find.text('Bewaren'), 200, scrollable: find.byType(Scrollable).first);
    await tester.tap(find.text('Bewaren'));
    await tester.pump();
    expect(find.text('Dit telefoonnummer klopt niet.'), findsOneWidget);
    verifyNever(() => repository.save(any(), any()));

    await tester.enterText(fields.at(3), '0471 98 76 54');
    await tester.tap(find.text('Bewaren'));
    await tester.pumpAndSettle();
    final saved = verify(() => repository.save('me', captureAny())).captured.single as List<EmergencyContact>;
    expect(saved, [_oma, _jan]);
    verify(() => cache.write('me', saved)).called(1);
    expect(find.text('Noodcontacten bewaard.'), findsOneWidget);
  });

  testWidgets('test-sms gaat naar elk ingevuld contact', (tester) async {
    when(() => phone.sendSms(any(), any())).thenAnswer((_) async => true);
    await pumpScreen(tester, const [_oma, _jan]);
    await tester.scrollUntilVisible(
      find.text('Stuur een test-sms'),
      200,
      scrollable: find.byType(Scrollable).first,
    );
    await tester.tap(find.text('Stuur een test-sms'));
    await tester.pumpAndSettle();
    verify(() => phone.sendSms('0470123456', any(that: startsWith('Test van Papa')))).called(1);
    verify(() => phone.sendSms('0471987654', any())).called(1);
    expect(find.text('Test-sms verstuurd naar Oma en Jan.'), findsOneWidget);
  });

  group('regel op het SOS-scherm', () {
    Future<void> pumpLine(
      WidgetTester tester,
      List<EmergencyContact> contacts, {
      bool automatic = true,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: overrides(contacts, automatic: automatic),
          child: MaterialApp(
            theme: AppTheme.light(),
            home: const Scaffold(body: SosEmergencyLine()),
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    testWidgets('met contacten: wie een sms krijgt en wie gebeld wordt', (tester) async {
      await pumpLine(tester, const [_oma, _jan]);
      expect(find.text('Ook een sms naar Oma en Jan · daarna bellen naar Oma'), findsOneWidget);
    });

    testWidgets('zonder toestemming: de sms staat klaar', (tester) async {
      await pumpLine(tester, const [_oma], automatic: false);
      expect(find.text('Noodcontact Oma: de sms staat klaar, zelf versturen'), findsOneWidget);
    });

    testWidgets('zonder contacten: waar je ze instelt', (tester) async {
      await pumpLine(tester, const []);
      expect(find.text('Nog geen noodcontacten · instellen via Profiel'), findsOneWidget);
    });
  });
}
