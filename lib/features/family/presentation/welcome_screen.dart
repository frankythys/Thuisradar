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
      appBar: const BrandedAppBar(title: 'Welkom'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const _WelcomeHero(),
              SizedBox(height: tokens.spaceLg),
              Text('Welkom bij ${family.name}!', style: text.headlineLarge, textAlign: TextAlign.center),
              SizedBox(height: tokens.spaceSm),
              Text(
                'Je bent nu verbonden met de veilige familiekring.',
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceLg),
              members.when(
                data: (list) => _MembersCard(members: list, myId: myId),
                loading: () => const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: CircularProgressIndicator()),
                ),
                error: (e, _) => ErrorView(message: 'Leden laden mislukt.\n$e'),
              ),
              SizedBox(height: tokens.spaceLg),
              FilledButton(
                onPressed: () => _continue(context),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Text('Naar de kaart'),
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

class _MembersCard extends StatelessWidget {
  const _MembersCard({required this.members, required this.myId});

  final List<FamilyMember> members;
  final String? myId;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Huidige gezinsleden', style: text.titleLarge),
              const Spacer(),
              _CountPill(count: members.length),
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          for (final member in members) ...[
            Padding(
              padding: EdgeInsets.symmetric(vertical: tokens.spaceSm),
              child: Row(
                children: [
                  MemberAvatar(member: member, size: 48),
                  SizedBox(width: tokens.spaceMd),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(member.displayName, style: text.titleMedium),
                        Text(
                          member.userId == myId ? 'Jij' : (member.isOwner ? 'Beheerder' : 'Gezinslid'),
                          style: text.bodySmall?.copyWith(color: AppColors.muted),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
          SizedBox(height: tokens.spaceSm),
          Container(
            padding: EdgeInsets.all(tokens.spaceMd),
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Row(
              children: [
                const Icon(Icons.lock_outline, size: 18, color: AppColors.muted),
                SizedBox(width: tokens.spaceMd),
                Expanded(
                  child: Text(
                    'Locaties worden enkel binnen deze kring gedeeld. Je gegevens blijven privé.',
                    style: text.bodyMedium?.copyWith(color: AppColors.muted),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _CountPill extends StatelessWidget {
  const _CountPill({required this.count});

  final int count;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: const ShapeDecoration(color: AppColors.primarySoft, shape: StadiumBorder()),
      child: Text(
        '$count ${count == 1 ? 'lid' : 'leden'}',
        style: Theme.of(context).textTheme.labelMedium?.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _WelcomeHero extends StatelessWidget {
  const _WelcomeHero();

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 160,
      height: 160,
      child: Stack(
        alignment: Alignment.center,
        children: [
          _ring(160, 0.2),
          _ring(118, 0.4),
          Container(
            width: 84,
            height: 84,
            decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
            child: const Icon(Icons.home_rounded, color: Colors.white, size: 40),
          ),
        ],
      ),
    );
  }

  Widget _ring(double size, double opacity) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Color.lerp(AppColors.ground, AppColors.primary, opacity),
      ),
    );
  }
}
