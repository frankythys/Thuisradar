import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/language/application/app_locale.dart';
import 'package:thuisradar/features/language/application/language_providers.dart';
import 'package:thuisradar/features/language/presentation/language_tile.dart';
import 'package:thuisradar/shared/widgets/app_bottom_nav.dart';

/// Dezelfde taalinstellingen als app.dart, met de navigatiebalk en de taalrij.
class _App extends ConsumerWidget {
  const _App();

  @override
  Widget build(BuildContext context, WidgetRef ref) => MaterialApp(
    theme: AppTheme.light(),
    locale: AppLocale.of(ref.watch(languageOverrideProvider)),
    supportedLocales: AppLocale.supported,
    localizationsDelegates: AppLocale.delegates,
    localeListResolutionCallback: AppLocale.resolve,
    home: Scaffold(
      body: const Material(child: LanguageTile()),
      bottomNavigationBar: AppBottomNav(current: AppTab.kaart, onSelected: (_) {}),
    ),
  );
}

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  testWidgets('volgt de toesteltaal', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('fr', 'BE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: _App()));

    expect(find.text('Carte'), findsOneWidget);
    expect(find.text('Lieux'), findsOneWidget);
  });

  testWidgets('niet-ondersteunde toesteltaal valt terug op Engels', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('ja')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: _App()));

    expect(find.text('Map'), findsOneWidget);
    expect(find.text('On the move'), findsOneWidget);
  });

  testWidgets('taal kiezen in het blad schakelt meteen om, en terug naar toesteltaal', (tester) async {
    tester.platformDispatcher.localesTestValue = const [Locale('nl', 'BE')];
    addTearDown(tester.platformDispatcher.clearLocalesTestValue);
    await tester.pumpWidget(const ProviderScope(child: _App()));
    expect(find.text('Kaart'), findsOneWidget);
    expect(find.text('Toesteltaal'), findsOneWidget);

    await tester.tap(find.text('Taal'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Türkçe'));
    await tester.pumpAndSettle();

    expect(find.text('Harita'), findsOneWidget);
    expect(find.text('Türkçe'), findsOneWidget); // ondertitel van de taalrij

    await tester.tap(find.text('Dil'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cihaz dili'));
    await tester.pumpAndSettle();

    expect(find.text('Kaart'), findsOneWidget);
  });
}
