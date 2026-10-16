import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../../../l10n/generated/app_localizations.dart';

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

/// Neemt thema, taal, tekstrichting en schermgegevens van [context] mee naar
/// een widget die buiten de boom getekend wordt. Zonder de taal zouden de
/// ballonnen op Google Maps altijd Nederlands tonen (terugval van l10n).
Widget Function(Widget child) wrapForBitmap(BuildContext context) {
  final media = MediaQuery.of(context);
  final direction = Directionality.of(context);
  final locale = Localizations.maybeLocaleOf(context);
  final delegates = <LocalizationsDelegate<Object?>>[
    if (AppLocalizations.of(context) case final l10n?) _Loaded<AppLocalizations>(l10n),
    if (Localizations.of<MaterialLocalizations>(context, MaterialLocalizations) case final material?)
      _Loaded<MaterialLocalizations>(material),
    if (Localizations.of<WidgetsLocalizations>(context, WidgetsLocalizations) case final widgets?)
      _Loaded<WidgetsLocalizations>(widgets),
  ];
  return (child) {
    Widget content = Material(type: MaterialType.transparency, child: child);
    if (locale != null && delegates.isNotEmpty) {
      content = Localizations(locale: locale, delegates: delegates, child: content);
    }
    return InheritedTheme.captureAll(
      context,
      MediaQuery(
        data: media,
        child: Directionality(textDirection: direction, child: content),
      ),
    );
  };
}

/// Geeft een al geladen vertaling meteen (synchroon) terug, zodat de
/// afbeelding in één keer met de juiste taal getekend wordt.
class _Loaded<T> extends LocalizationsDelegate<T> {
  const _Loaded(this.value);

  final T value;

  @override
  bool isSupported(Locale locale) => true;

  @override
  Future<T> load(Locale locale) => SynchronousFuture<T>(value);

  @override
  bool shouldReload(_Loaded<T> old) => !identical(old.value, value);

  @override
  Type get type => T;
}
