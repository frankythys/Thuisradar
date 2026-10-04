import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Huidige tijd, elke 5 seconden ververst, zodat "x min geleden" klopt.
final clockProvider = StreamProvider<DateTime>((ref) async* {
  yield DateTime.now();
  yield* Stream.periodic(const Duration(seconds: 5), (_) => DateTime.now());
});
