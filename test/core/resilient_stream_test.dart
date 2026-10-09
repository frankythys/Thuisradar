import 'dart:async';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/utils/resilient_stream.dart';

void main() {
  test('een gesloten realtime-stroom wordt opnieuw geopend en levert verder', () {
    fakeAsync((async) {
      final sources = <StreamController<int>>[];
      final received = <int>[];
      final stream = resilientStream(() {
        final c = StreamController<int>();
        sources.add(c);
        return c.stream;
      });
      final sub = stream.listen(received.add);
      async.flushMicrotasks();
      sources.last.add(1);
      async.flushMicrotasks();

      unawaited(sources.last.close());
      async.elapse(const Duration(seconds: 6));
      expect(sources, hasLength(2));

      sources.last.add(2);
      async.flushMicrotasks();
      expect(received, [1, 2]);
      unawaited(sub.cancel());
    });
  });

  test('een fout na data houdt de laatste data en herverbindt', () {
    fakeAsync((async) {
      final sources = <StreamController<int>>[];
      final received = <int>[];
      final errors = <Object>[];
      final stream = resilientStream(() {
        final c = StreamController<int>();
        sources.add(c);
        return c.stream;
      });
      final sub = stream.listen(received.add, onError: errors.add);
      async.flushMicrotasks();
      sources.last.add(1);
      sources.last.addError(Exception('timedOut'));
      async.flushMicrotasks();
      expect(errors, isEmpty);

      async.elapse(const Duration(seconds: 6));
      expect(sources, hasLength(2));
      unawaited(sub.cancel());
    });
  });

  test('een fout vóór de eerste data wordt doorgegeven', () {
    fakeAsync((async) {
      final source = StreamController<int>();
      final errors = <Object>[];
      final sub = resilientStream(() => source.stream).listen((_) {}, onError: errors.add);
      async.flushMicrotasks();
      source.addError(Exception('geen netwerk'));
      async.flushMicrotasks();
      expect(errors, hasLength(1));
      unawaited(sub.cancel());
    });
  });

  test('een resync-signaal opent de bron meteen opnieuw; oude events tellen niet', () {
    fakeAsync((async) {
      final sources = <StreamController<int>>[];
      final resync = StreamController<void>.broadcast();
      final received = <int>[];
      final sub = resilientStream(() {
        final c = StreamController<int>(onCancel: () {});
        sources.add(c);
        return c.stream;
      }, resync: resync.stream).listen(received.add);
      async.flushMicrotasks();

      resync.add(null);
      async.flushMicrotasks();
      expect(sources, hasLength(2));
      sources.last.add(7);
      async.flushMicrotasks();
      expect(received, [7]);
      unawaited(sub.cancel());
    });
  });

  test('na opzeggen wordt niets meer heropend', () {
    fakeAsync((async) {
      var opened = 0;
      final source = StreamController<int>();
      final sub = resilientStream(() {
        opened++;
        return source.stream;
      }).listen((_) {});
      async.flushMicrotasks();
      unawaited(sub.cancel());
      async.flushMicrotasks();
      async.elapse(const Duration(seconds: 30));
      expect(opened, 1);
    });
  });
}
