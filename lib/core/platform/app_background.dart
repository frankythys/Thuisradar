import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Stuurt de app naar de achtergrond in plaats van ze te sluiten, zodat het
/// delen van de locatie doorloopt (zoals de home-knop). Enkel Android heeft
/// een terug-knop; op andere platformen gebeurt er niets.
class AppBackground {
  const AppBackground([this._channel = const MethodChannel(channelName)]);

  /// Zelfde naam als in `MainActivity.kt`.
  static const channelName = 'be.thuisradar/app';

  final MethodChannel _channel;

  Future<void> moveToBackground() async {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.android) return;
    try {
      await _channel.invokeMethod<void>('moveToBackground');
    } on PlatformException catch (error) {
      debugPrint('Naar de achtergrond gaan mislukt: $error');
    } on MissingPluginException catch (error) {
      debugPrint('Naar de achtergrond gaan niet beschikbaar: $error');
    }
  }
}

final appBackgroundProvider = Provider<AppBackground>((ref) => const AppBackground());
