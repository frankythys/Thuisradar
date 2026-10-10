import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Tekent een widget buiten beeld naar een PNG, scherp op [pixelRatio].
///
/// Voor markers in Google Maps: die zijn afbeeldingen, geen widgets. Wikkel
/// [widget] vooraf in thema, tekstrichting en MediaQuery (zie
/// [wrapForBitmap]), want buiten de widgetboom is er geen context.
Future<Uint8List> renderWidgetToPng(Widget widget, {required Size size, required double pixelRatio}) async {
  final boundary = RenderRepaintBoundary();
  final view = WidgetsBinding.instance.platformDispatcher.implicitView!;
  final renderView = RenderView(
    view: view,
    child: RenderPositionedBox(child: boundary),
    configuration: ViewConfiguration(
      logicalConstraints: BoxConstraints.tight(size),
      physicalConstraints: BoxConstraints.tight(size * pixelRatio),
      devicePixelRatio: pixelRatio,
    ),
  );
  final pipelineOwner = PipelineOwner()..rootNode = renderView;
  renderView.prepareInitialFrame();
  final focusManager = FocusManager();
  final buildOwner = BuildOwner(focusManager: focusManager);
  final root = RenderObjectToWidgetAdapter<RenderBox>(
    container: boundary,
    child: SizedBox.fromSize(size: size, child: widget),
  ).attachToRenderTree(buildOwner);
  try {
    buildOwner
      ..buildScope(root)
      ..finalizeTree();
    pipelineOwner
      ..flushLayout()
      ..flushCompositingBits()
      ..flushPaint();
    final image = await boundary.toImage(pixelRatio: pixelRatio);
    try {
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      return Uint8List.view(data!.buffer);
    } finally {
      image.dispose();
    }
  } finally {
    RenderObjectToWidgetAdapter<RenderBox>(container: boundary).attachToRenderTree(buildOwner, root);
    buildOwner.finalizeTree();
    focusManager.dispose();
    pipelineOwner
      ..rootNode = null
      ..dispose();
  }
}

/// Neemt thema, tekstrichting en schermgegevens van [context] mee naar een
/// widget die buiten de boom getekend wordt.
Widget Function(Widget child) wrapForBitmap(BuildContext context) {
  final media = MediaQuery.of(context);
  final direction = Directionality.of(context);
  return (child) => InheritedTheme.captureAll(
    context,
    MediaQuery(
      data: media,
      child: Directionality(
        textDirection: direction,
        child: Material(type: MaterialType.transparency, child: child),
      ),
    ),
  );
}
