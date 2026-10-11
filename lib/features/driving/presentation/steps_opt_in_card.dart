import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../location/application/location_providers.dart';
import '../../permissions/application/permissions_providers.dart';

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
          content: const Text('Geen toegang tot de stappenteller. Zet "Fysieke activiteit" aan.'),
          action: SnackBarAction(
            label: 'Instellingen',
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
                  Text('Stappen tellen', style: text.titleMedium),
                  Text(
                    'Zie bij je wandelingen ook hoeveel stappen je zette.',
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            TextButton(onPressed: _busy ? null : _enable, child: const Text('Aanzetten')),
          ],
        ),
      ),
    );
  }
}
