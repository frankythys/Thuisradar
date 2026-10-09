import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/sos/presentation/widgets/sos_app_bar_button.dart';
import 'package:thuisradar/shared/widgets/branded_app_bar.dart';
import 'package:thuisradar/shared/widgets/profile_action.dart';

void main() {
  testWidgets('SOS staat in de bovenbalk vlak voor de avatar en opent het noodscherm', (tester) async {
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    var opened = 0;
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            appBar: BrandedAppBar(
              title: 'Kaart',
              actions: [
                SosAppBarButton(onPressed: () => opened++),
                const ProfileAction(),
              ],
            ),
          ),
        ),
      ),
    );

    final sos = tester.getCenter(find.text('SOS'));
    final avatar = tester.getCenter(find.byTooltip('Profiel'));
    expect(sos.dx, lessThan(avatar.dx));
    expect((sos.dy - avatar.dy).abs(), lessThan(1));

    await tester.tap(find.text('SOS'));
    expect(opened, 1);
    expect(tester.takeException(), isNull);
  });
}
