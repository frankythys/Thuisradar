import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Huidige tijd, elke 30 seconden ververst, zodat "x min geleden" klopt.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 30), (_) => DateTime.now());
});
