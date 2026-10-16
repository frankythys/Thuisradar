import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/language/application/app_locale.dart';
import 'package:thuisradar/features/map/presentation/widgets/widget_bitmap.dart';
import 'package:thuisradar/l10n/l10n.dart';

void main() {
  testWidgets('Google-ballonnen buiten beeld krijgen de app-taal mee, niet het Nederlands', (tester) async {
    late Widget Function(Widget) wrap;
    await tester.pumpWidget(
      MaterialApp(
        locale: const Locale('en'),
        localizationsDelegates: AppLocale.delegates,
        supportedLocales: AppLocale.supported,
        home: Builder(
          builder: (context) {
            wrap = wrapForBitmap(context);
            return const SizedBox();
          },
        ),
      ),
    );

    // Zoals renderWidgetToPng: een losse boom zonder MaterialApp erboven.
    String? text;
    await tester.pumpWidget(
      wrap(
        Builder(
          builder: (context) {
            text = context.l10n.commonMember;
            return const SizedBox();
          },
        ),
      ),
    );
    expect(text, 'Family member');
  });
}
