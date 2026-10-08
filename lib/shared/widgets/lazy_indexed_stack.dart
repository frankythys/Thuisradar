import 'package:flutter/widgets.dart';

/// Bouwt een tab pas bij het eerste bezoek en behoudt daarna zijn toestand.
class LazyIndexedStack extends StatefulWidget {
  const LazyIndexedStack({
    super.key,
    required this.index,
    required this.builders,
  });
  final int index;
  final List<WidgetBuilder> builders;

  @override
  State<LazyIndexedStack> createState() => _LazyIndexedStackState();
}

class _LazyIndexedStackState extends State<LazyIndexedStack> {
  final _visited = <int>{};

  @override
  Widget build(BuildContext context) {
    _visited.add(widget.index);
    return IndexedStack(
      index: widget.index,
      children: [
        for (var i = 0; i < widget.builders.length; i++)
          TickerMode(
            enabled: i == widget.index,
            child: _visited.contains(i)
                ? widget.builders[i](context)
                : const SizedBox.shrink(),
          ),
      ],
    );
  }
}
