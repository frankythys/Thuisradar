import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../location/application/location_providers.dart';
import '../../permissions/application/permissions_providers.dart';
import '../../../l10n/l10n.dart';

/// Vraagt om de stappenteller van dit toestel aan te zetten, zolang dat nog
/// niet is gebeurd. Verdwijnt zodra er toestemming is.
class StepsOptInCard extends ConsumerStatefulWidget {
  const StepsOptInCard({super.key});

  @override
  ConsumerState<StepsOptInCard> createState() => _StepsOptInCardState();
}

class _StepsOptInCardState extends ConsumerState<StepsOptInCard> {
  bool _busy = false;

  Future<void> _enable() async {
    setState(() => _busy = true);
    final granted = await ref.read(locationTrackerProvider.notifier).enableSteps();
    if (!mounted) return;
    setState(() => _busy = false);
    ref.invalidate(stepAccessProvider);
    if (!granted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.drivingStepsDenied),
          action: SnackBarAction(
            label: context.l10n.commonSettings,
            onPressed: () => ref.read(permissionServiceProvider).openSettings(),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (ref.watch(stepAccessProvider).value ?? true) return const SizedBox.shrink();
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    return Padding(
      padding: EdgeInsets.only(bottom: tokens.spaceMd),
      child: AppCard(
        child: Row(
          children: [
            const Icon(Icons.directions_walk, color: AppColors.primary),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(context.l10n.permSteps, style: text.titleMedium),
                  Text(
                    context.l10n.drivingStepsHint,
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            TextButton(onPressed: _busy ? null : _enable, child: Text(context.l10n.drivingTurnOn)),
          ],
        ),
      ),
    );
  }
}
