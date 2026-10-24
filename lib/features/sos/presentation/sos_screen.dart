import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import '../domain/sos_alert.dart';
import 'widgets/sos_countdown.dart';
import 'widgets/sos_emergency_line.dart';
import 'widgets/sos_hold_button.dart';
import 'widgets/sos_recipients.dart';
import '../../../l10n/l10n.dart';

/// Rustig noodscherm: enkel een kruisje, één grote knop om in te houden en
/// wie gewaarschuwd wordt. Na het vasthouden telt het [kSosCancelDuration]
/// af met een grote knop Annuleren; pas daarna vertrekt het alarm. Geen knop
/// "Bel 112": per ongeluk tikken op een noodnummer is te gevaarlijk.
class SosScreen extends ConsumerStatefulWidget {
  const SosScreen({
    super.key,
    required this.familyId,
    required this.onActivate,
  });
  final String familyId;
  final Future<void> Function() onActivate;

  @override
  ConsumerState<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends ConsumerState<SosScreen> {
  bool _counting = false;

  void _startCountdown() => setState(() => _counting = true);

  void _cancel() => setState(() => _counting = false);

  void _send() {
    HapticFeedback.heavyImpact();
    // Het aftellen is voorbij: ga terug naar de kaart terwijl GPS, gezin en
    // noodcontacten worden afgehandeld. Anders blijft dit scherm bovenop de
    // kaart staan en verdwijnt de verzendmelding erachter.
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      setState(() => _counting = false);
    }
    // Niet wachten: de kaart blijft bruikbaar terwijl de SOS wordt verstuurd.
    unawaited(widget.onActivate());
  }

  @override
  Widget build(BuildContext context) {
    final familyId = widget.familyId;
    final members =
        ref.watch(familyMembersProvider(familyId)).value ?? const [];
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
          padding: EdgeInsets.fromLTRB(
            tokens.spaceLg,
            tokens.spaceXs,
            tokens.spaceLg,
            tokens.spaceLg,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Align(
                alignment: Alignment.centerLeft,
                child: IconButton(
                  tooltip: context.l10n.commonClose,
                  onPressed: () => Navigator.maybePop(context),
                  icon: const Icon(Icons.close),
                ),
              ),
              Text(
                context.l10n.sosNeedHelp,
                style: text.headlineMedium,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceXs),
              Text(
                _counting
                    ? context.l10n.sosCountingHint
                    : context.l10n.sosHoldHint,
                style: text.bodyMedium?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, box) {
                    final ring = math.min(
                      280.0,
                      math.min(box.maxWidth, box.maxHeight),
                    );
                    if (_counting) {
                      return Center(
                        child: SosCountdown(
                          duration: kSosCancelDuration,
                          onDone: _send,
                          onCancel: _cancel,
                          size: ring * .57,
                        ),
                      );
                    }
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
                                  color: scheme.errorContainer.withValues(
                                    alpha: .5,
                                  ),
                                ),
                              ),
                            SosHoldButton(
                              onActivate: () async => _startCountdown(),
                              size: ring * .57,
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              Text(
                _counting
                    ? context.l10n.sosCloseCancels
                    : context.l10n.sosFalseAlarm,
                style: text.bodySmall?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceMd),
              SosRecipients(members: others),
              SizedBox(height: tokens.spaceSm),
              const SosEmergencyLine(),
            ],
          ),
        ),
      ),
    );
  }
}
