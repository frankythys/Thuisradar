import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import 'widgets/sos_hold_button.dart';
import 'widgets/sos_recipients.dart';

/// Rustig noodscherm: enkel een kruisje, één grote knop om in te houden,
/// wie gewaarschuwd wordt en een knop om 112 te bellen.
class SosScreen extends ConsumerWidget {
  const SosScreen({super.key, required this.familyId, required this.onActivate});
  final String familyId;
  final Future<void> Function() onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider(familyId)).value ?? const [];
    final myId = ref.watch(currentUserIdProvider);
    final others = [
      for (final m in members)
        if (m.userId != myId) m,
    ];
    final text = Theme.of(context).textTheme;
    final scheme = Theme.of(context).colorScheme;
    final tokens = context.tokens;

    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceXs, tokens.spaceLg, tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: 'Sluiten',
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text('Hulp nodig?', style: text.headlineMedium, textAlign: TextAlign.center),
              SizedBox(height: tokens.spaceXs),
              Text(
                'Houd de knop 3 seconden in. Je gezin krijgt meteen een alarm met je locatie.',
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final ring = math.min(280.0, math.min(box.maxWidth, box.maxHeight));
                    return Center(
                      child: SizedBox.square(
                        dimension: ring,
                        child: Stack(
                          alignment: Alignment.center,
                          children: [
                            for (final f in [1.0, .84, .7])
                              Container(
                                width: ring * f,
                                height: ring * f,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  color: scheme.errorContainer.withValues(alpha: .5),
                                ),
                              ),
                            SosHoldButton(onActivate: onActivate, size: ring * .57),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Text(
                'Vals alarm? Laat los voor de cirkel vol is.',
                style: text.bodySmall?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceMd),
              SosRecipients(members: others),
              SizedBox(height: tokens.spaceMd),
              OutlinedButton.icon(
                onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
                icon: const Icon(Icons.phone_outlined, size: 20),
                label: const Text('Bel 112'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: scheme.error,
                  side: BorderSide(color: scheme.error, width: 1.5),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
