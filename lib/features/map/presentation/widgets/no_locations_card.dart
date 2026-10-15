import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../shared/widgets/app_card.dart';
import '../../../../shared/widgets/radar_logo.dart';
import '../../../family/domain/family.dart';
import '../../../family/presentation/invite_screen.dart';
import '../../../../l10n/l10n.dart';

class NoLocationsCard extends StatelessWidget {
  const NoLocationsCard({super.key, required this.family, required this.onSettings});
  final Family family;
  final VoidCallback onSettings;
  @override
  Widget build(BuildContext context) => AppCard(
    child: Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: const BoxDecoration(shape: BoxShape.circle, color: AppColors.surfaceLow),
          child: const RadarLogo(size: 40),
        ),
        const SizedBox(height: 16),
        Text(
          context.l10n.mapNoActiveTitle,
          style: Theme.of(context).textTheme.headlineMedium,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 8),
        Text(
          context.l10n.mapNoActiveBody(family.name),
          style: Theme.of(context).textTheme.bodySmall,
          textAlign: TextAlign.center,
        ),
        const SizedBox(height: 16),
        FilledButton.icon(
          onPressed: () =>
              Navigator.of(context)
                  .push(MaterialPageRoute<void>(builder: (_) => InviteScreen(family: family))),
          icon: const Icon(Icons.group_add_outlined, size: 18),
          label: Text(context.l10n.mapInviteMember),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          onPressed: onSettings,
          icon: const Icon(Icons.gps_fixed, size: 18),
          label: Text(context.l10n.mapCheckGps),
        ),
        const SizedBox(height: 10),
        Text(context.l10n.mapFamilyCode(family.inviteCode), style: Theme.of(context).textTheme.bodySmall),
      ],
    ),
  );
}
