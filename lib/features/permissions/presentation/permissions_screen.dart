import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../application/permissions_providers.dart';

/// Scherm 10: vraagt locatie (vereist), meldingen en batterij-uitzondering.
/// Weigeren mag: de app gaat gewoon door en legt uit hoe je het later aanzet.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _wantNotifications = true;
  bool _wantBattery = true;
  bool _busy = false;

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _requestAll() async {
    if (_busy) return;
    setState(() => _busy = true);

    final service = ref.read(permissionServiceProvider);
    final locationGranted = await service.requestLocation();
    if (_wantNotifications) await service.requestNotifications();
    if (_wantBattery) await service.requestBatteryExemption();

    if (!mounted) return;
    if (!locationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Locatie staat nog uit. Je kunt dit later aanzetten via Instellingen.'),
          action: SnackBarAction(label: 'Instellingen', onPressed: service.openSettings),
        ),
      );
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Toestemmingen'),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.all(tokens.spaceLg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 72,
                  height: 72,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, size: 34, color: AppColors.primary),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              Text('Toestemmingen voor gemoedsrust', style: text.headlineLarge, textAlign: TextAlign.center),
              SizedBox(height: tokens.spaceSm),
              Text(
                'Thuisradar heeft enkele rechten nodig om stil en betrouwbaar op de '
                'achtergrond voor je gezin te zorgen.',
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              SizedBox(height: tokens.spaceLg),
              _PermissionCard(
                icon: Icons.location_on_outlined,
                title: 'Locatie',
                subtitle: 'Om je locatie met je familie te delen',
                note: 'Kies straks voor "Altijd toestaan" voor betrouwbare aankomstmeldingen.',
                trailing: const _RequiredBadge(),
              ),
              SizedBox(height: tokens.spaceMd),
              _PermissionCard(
                icon: Icons.notifications_outlined,
                title: 'Meldingen',
                subtitle: 'Voor aankomst, vertrek en SOS',
                note: 'Zodat je weet wanneer je zoon veilig op school aankomt.',
                trailing: Switch(
                  value: _wantNotifications,
                  onChanged: _busy ? null : (v) => setState(() => _wantNotifications = v),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              _PermissionCard(
                icon: Icons.battery_charging_full_outlined,
                title: 'Batterij-optimalisatie uitzetten',
                subtitle: 'Zodat delen op de achtergrond blijft werken',
                note: 'Voorkomt dat Android de app onbedoeld uitschakelt.',
                trailing: Switch(
                  value: _wantBattery,
                  onChanged: _busy ? null : (v) => setState(() => _wantBattery = v),
                ),
              ),
              SizedBox(height: tokens.spaceLg),
              Container(
                padding: EdgeInsets.all(tokens.spaceMd),
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(tokens.radiusCard),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.shield_outlined, color: AppColors.primary),
                    SizedBox(width: tokens.spaceMd),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Privacy-belofte', style: text.titleMedium),
                          SizedBox(height: tokens.spaceXs),
                          Text(
                            'Geen trackers, geen advertenties. Je data verlaat nooit je gezinskring.',
                            style: text.bodyMedium?.copyWith(color: AppColors.muted),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              SizedBox(height: tokens.spaceLg),
              FilledButton(
                onPressed: _busy ? null : _requestAll,
                child: _busy
                    ? const SizedBox.square(
                        dimension: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text('Toestaan'),
                          SizedBox(width: tokens.spaceSm),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
              TextButton(onPressed: _busy ? null : _finish, child: const Text('Later instellen')),
            ],
          ),
        ),
      ),
    );
  }
}

class _PermissionCard extends StatelessWidget {
  const _PermissionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.note,
    required this.trailing,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final String note;
  final Widget trailing;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: const BoxDecoration(color: AppColors.primary, shape: BoxShape.circle),
                child: Icon(icon, color: Colors.white, size: 22),
              ),
              SizedBox(width: tokens.spaceMd),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: text.titleMedium),
                    SizedBox(height: tokens.spaceXs),
                    Text(subtitle, style: text.bodyMedium?.copyWith(color: AppColors.muted)),
                  ],
                ),
              ),
              SizedBox(width: tokens.spaceSm),
              trailing,
            ],
          ),
          SizedBox(height: tokens.spaceMd),
          Container(
            padding: EdgeInsets.all(tokens.spaceSm + tokens.spaceXs),
            decoration: BoxDecoration(
              color: AppColors.ground,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.info_outline, size: 16, color: AppColors.muted),
                SizedBox(width: tokens.spaceSm),
                Expanded(
                  child: Text(note, style: text.bodySmall?.copyWith(color: AppColors.muted)),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _RequiredBadge extends StatelessWidget {
  const _RequiredBadge();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: const ShapeDecoration(color: AppColors.primarySoft, shape: StadiumBorder()),
      child: Text(
        'VEREIST',
        style: Theme.of(context).textTheme.labelSmall?.copyWith(color: AppColors.primary),
      ),
    );
  }
}
