import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/shared/widgets/lazy_indexed_stack.dart';

void main() {
  testWidgets(
    'onbezochte tabs starten niet; bezochte tabs behouden hun toestand',
    (tester) async {
      final started = <int>[];
      Widget shell(int index) => MaterialApp(
        home: LazyIndexedStack(
          index: index,
          builders: [
            for (var i = 0; i < 3; i++)
              (_) => _CounterTab(id: i, onStart: started.add),
          ],
        ),
      );
      await tester.pumpWidget(shell(0));
      expect(started, [0]);
      await tester.tap(find.text('0:0'));
      await tester.pump();
      expect(find.text('0:1'), findsOneWidget);
      await tester.pumpWidget(shell(1));
      expect(started, [0, 1]);
      final hiddenContext = tester.element(
        find.text('0:1', skipOffstage: false),
      );
      expect(TickerMode.valuesOf(hiddenContext).enabled, isFalse);
      await tester.pumpWidget(shell(0));
      expect(started, [0, 1]);
      expect(find.text('0:1'), findsOneWidget);
      expect(
        TickerMode.valuesOf(tester.element(find.text('0:1'))).enabled,
        isTrue,
      );
    },
  );
}

class _CounterTab extends StatefulWidget {
  const _CounterTab({required this.id, required this.onStart});
  final int id;
  final ValueChanged<int> onStart;
  @override
  State<_CounterTab> createState() => _CounterTabState();
}

class _CounterTabState extends State<_CounterTab> {
  var count = 0;
  @override
  void initState() {
    super.initState();
    widget.onStart(widget.id);
  }

  @override
  Widget build(BuildContext context) => TextButton(
    onPressed: () => setState(() => count++),
    child: Text('${widget.id}:$count'),
  );
}
