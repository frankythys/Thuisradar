import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/presentation/widgets/widget_bitmap.dart';

void main() {
  testWidgets('een rondje wordt een scherpe PNG van de juiste grootte', (tester) async {
    late Widget Function(Widget) wrap;
    await tester.pumpWidget(
      MaterialApp(
        home: Builder(
          builder: (context) {
            wrap = wrapForBitmap(context);
            return const SizedBox();
          },
        ),
      ),
    );

    final png = await tester.runAsync(
      () => renderWidgetToPng(
        wrap(
          Container(
            decoration: const BoxDecoration(color: Colors.orange, shape: BoxShape.circle),
            child: const Center(child: Text('F')),
          ),
        ),
        size: const Size(48, 48),
        pixelRatio: 2.5,
      ),
    );

    final codec = await tester.runAsync(() => ui.instantiateImageCodec(png!));
    final frame = await tester.runAsync(() => codec!.getNextFrame());
    expect(frame!.image.width, 120);
    expect(frame.image.height, 120);
  });
}
