import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

/// Verduistert de kaart naarmate het paneel verder open staat.
///
/// Luistert zelf naar de [controller] in plaats van een ListenableBuilder: het
/// paneel meldt een nieuwe hoogte soms midden in een build (bv. wanneer de
/// ingeklapte hoogte wijzigt doordat de gezinsleden geladen zijn). Dan wacht
/// de verduistering tot na dat frame.
class SheetScrim extends StatefulWidget {
  const SheetScrim({super.key, required this.controller, required this.minimum});

  final DraggableScrollableController controller;

  /// Ingeklapte hoogte als fractie: daar is de kaart nog helemaal helder.
  final double minimum;

  static const _maximum = 0.94;
  static const _maxOpacity = 0.68;

  @override
  State<SheetScrim> createState() => _SheetScrimState();
}

class _SheetScrimState extends State<SheetScrim> {
  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onChanged);
  }

  @override
  void didUpdateWidget(SheetScrim oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onChanged);
      widget.controller.addListener(_onChanged);
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onChanged);
    super.dispose();
  }

  void _onChanged() {
    if (SchedulerBinding.instance.schedulerPhase == SchedulerPhase.persistentCallbacks) {
      SchedulerBinding.instance.addPostFrameCallback((_) {
        if (mounted) setState(() {});
      });
    } else {
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    final minimum = widget.minimum;
    final extent = widget.controller.isAttached ? widget.controller.size : minimum;
    final range = (SheetScrim._maximum - minimum).clamp(0.001, 1.0);
    final opacity = ((extent - minimum) / range).clamp(0.0, 1.0) * SheetScrim._maxOpacity;
    return ColoredBox(color: Theme.of(context).colorScheme.scrim.withValues(alpha: opacity));
  }
}
