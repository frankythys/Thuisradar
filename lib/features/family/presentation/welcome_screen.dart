import '../../location/application/location_providers.dart';
import '../../location/domain/member_location.dart';
import '../../../shared/widgets/battery_badge.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../auth/application/auth_providers.dart';
import '../../permissions/presentation/permissions_screen.dart';
import '../application/family_providers.dart';
import '../domain/family.dart';
import '../domain/family_member.dart';
import '../../../l10n/l10n.dart';

part 'welcome_screen_members_card.dart';
part 'welcome_screen_count_pill.dart';
part 'welcome_screen_welcome_hero.dart';

/// Scherm 9: na het joinen van een familie. Verwelkomt en toont de leden.
class WelcomeScreen extends ConsumerWidget {
  const WelcomeScreen({super.key, required this.family});

  final Family family;

  void _continue(BuildContext context) {
    Navigator.of(context).pushReplacement(MaterialPageRoute<void>(builder: (_) => const PermissionsScreen()));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final members = ref.watch(familyMembersProvider(family.id));
    final myId = ref.watch(currentUserIdProvider);

    return Scaffold(
      appBar: BrandedAppBar(title: context.l10n.welcomeTitle),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _WelcomeHero(),
              SizedBox(height: tokens.spaceLg),
              Text(
                context.l10n.welcomeHeadline(family.name),
                style: text.headlineLarge,
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceSm),
              Text(
                context.l10n.welcomeConnected,
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceLg),
              members.when(
                data: (list) => _MembersCard(
                  members: list,
                  myId: myId,
                  locations: ref.watch(familyLocationsProvider(family.id)).value ?? const [],
                ),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(message: '${context.l10n.welcomeMembersFailed}\n$e'),
              ),
              SizedBox(height: tokens.spaceLg),
              FilledButton(
                onPressed: () => _continue(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(context.l10n.welcomeToMap),
                    SizedBox(width: tokens.spaceSm),
                    const Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
