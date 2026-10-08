import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/theme/app_colors.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../family/application/family_providers.dart';
import 'widgets/sos_hold_button.dart';

class SosScreen extends ConsumerWidget {
  const SosScreen({super.key, required this.familyId, required this.onActivate});
  final String familyId;
  final Future<void> Function() onActivate;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final members = ref.watch(familyMembersProvider(familyId)).value ?? const [];
    final myId = ref.watch(currentUserIdProvider);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: const BrandedAppBar(title: 'SOS Noodbericht'),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Row(
              children: [
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
                const Spacer(),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
                  decoration: const ShapeDecoration(color: AppColors.alertSoft, shape: StadiumBorder()),
                  child: const Text('◉ NOODMODUS', style: TextStyle(color: AppColors.alert, fontSize: 11)),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text('Hulp nodig?', style: text.headlineLarge, textAlign: TextAlign.center),
            const SizedBox(height: 8),
            Text(
              'Houd de knop 3 seconden ingedrukt om direct een noodsignaal met je actuele live-locatie naar je hele gezin te sturen.',
              style: text.bodyMedium,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            Center(
              child: SizedBox(
                width: 280,
                height: 280,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    for (final size in [280.0, 242.0, 204.0])
                      Container(
                        width: size,
                        height: size,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: AppColors.alertSoft.withValues(alpha: .5),
                        ),
                      ),
                    SosHoldButton(onActivate: onActivate, large: true),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'Vals alarm? Laat de knop los vóór de cirkel vol is.',
              style: text.bodySmall,
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            AppCard(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Wordt direct gewaarschuwd', style: text.titleLarge),
                  Text('Ontvangen je exacte coördinaten en melding', style: text.bodySmall),
                  const SizedBox(height: 16),
                  for (final member in members.where((m) => m.userId != myId))
                    Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLow,
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        children: [
                          MemberAvatar(member: member, size: 40),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(member.displayName, style: text.titleMedium),
                                Text('Ontvangt luid alarm & route', style: text.bodySmall),
                              ],
                            ),
                          ),
                          const Icon(Icons.volume_up_outlined, color: AppColors.primary, size: 20),
                        ],
                      ),
                    ),
                  Text(
                    'De bezorging hangt af van de verbinding en meldingsinstellingen van het toestel.',
                    style: text.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: () => launchUrl(Uri(scheme: 'tel', path: '112')),
              icon: const Icon(Icons.phone_outlined),
              label: const Text('Bel direct de hulpdiensten (112)'),
              style: TextButton.styleFrom(
                foregroundColor: AppColors.alert,
                backgroundColor: AppColors.primarySoft,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
