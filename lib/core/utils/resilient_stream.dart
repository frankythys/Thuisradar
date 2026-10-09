import 'dart:async';

/// Houdt een realtime-stroom (Supabase `.stream()`) levend.
///
/// Een Supabase-stroom kan op de achtergrond stilvallen: het kanaal sluit
/// (dan eindigt de stroom voorgoed) of geeft een fout (time-out, kanaalfout).
/// Zonder herstel blijft de app dan de laatst ontvangen locatie tonen tot ze
/// herstart wordt. Deze wrapper:
/// - opent de bronstroom opnieuw na een fout of als ze eindigt;
/// - houdt na een fout de laatste gegevens zichtbaar (geen foutscherm zolang
///   er al data is — enkel een fout vóór de eerste data wordt doorgegeven);
/// - opent de bron meteen opnieuw bij elk [resync]-signaal (app terug op de
///   voorgrond, Verversen), zodat er een verse momentopname van de server komt.
Stream<T> resilientStream<T>(
  Stream<T> Function() open, {
  Stream<void>? resync,
  Duration retryDelay = const Duration(seconds: 5),
  void Function(Object error)? onError,
}) {
  late final StreamController<T> controller;
  StreamSubscription<T>? source;
  StreamSubscription<void>? resyncSubscription;
  Timer? retry;
  var hasData = false;
  var closed = false;

  void connect() {
    if (closed) return;
    retry?.cancel();
    retry = null;
    final old = source;
    source = null;
    unawaited(old?.cancel());
    late final StreamSubscription<T> current;
    void scheduleRetry() {
      if (closed || retry != null || !identical(source, current)) return;
      retry = Timer(retryDelay, connect);
    }

    current = open().listen(
      (value) {
        if (!identical(source, current)) return;
        hasData = true;
        controller.add(value);
      },
      onError: (Object error, StackTrace stackTrace) {
        if (!identical(source, current)) return;
        onError?.call(error);
        if (!hasData) controller.addError(error, stackTrace);
        scheduleRetry();
      },
      onDone: scheduleRetry,
    );
    source = current;
  }

  controller = StreamController<T>(
    onListen: () {
      connect();
      resyncSubscription = resync?.listen((_) => connect());
    },
    onCancel: () async {
      closed = true;
      retry?.cancel();
      await resyncSubscription?.cancel();
      await source?.cancel();
    },
  );
  return controller.stream;
}
