import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../domain/sos_alert.dart';

/// Scherm 18: volledig-scherm alarm bij de andere gezinsleden wanneer iemand SOS stuurt.
class SosReceivedOverlay extends ConsumerWidget {
  const SosReceivedOverlay({
    super.key,
    required this.alert,
    required this.name,
    required this.onShowOnMap,
    required this.onDismiss,
  });

  final SosAlert alert;
  final String name;
  final VoidCallback onShowOnMap;
  final VoidCallback onDismiss;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final now = ref.watch(clockProvider).value ?? DateTime.now();

    return Material(
      color: AppColors.alert,
      child: SafeArea(
        child: Padding(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Icon(Icons.warning_amber_rounded, color: Colors.white, size: 72),
              SizedBox(height: tokens.spaceLg),
              Text(
                '$name heeft SOS gestuurd!',
                style: text.headlineLarge?.copyWith(color: Colors.white),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceSm),
              Text(
                'Verstuurd ${formatRelative(alert.createdAt, now: now)} · met live-locatie.',
                style: text.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceXl),
              FilledButton.icon(
                onPressed: onShowOnMap,
                icon: const Icon(Icons.map_outlined),
                label: const Text('Toon op kaart'),
                style: FilledButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppColors.alert,
                ),
              ),
              SizedBox(height: tokens.spaceSm),
              TextButton(
                onPressed: onDismiss,
                child: const Text('Sluiten', style: TextStyle(color: Colors.white)),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
