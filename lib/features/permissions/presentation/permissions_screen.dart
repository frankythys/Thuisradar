import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../application/permissions_providers.dart';

part 'permissions_screen_permission_card.dart';
part 'permissions_screen_required_badge.dart';

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
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 56,
                  height: 56,
                  decoration: const BoxDecoration(color: AppColors.primarySoft, shape: BoxShape.circle),
                  child: const Icon(Icons.verified_user_rounded, size: 28, color: AppColors.primary),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              Text('Toestemmingen voor gemoedsrust', style: text.headlineLarge, textAlign: TextAlign.center),
              SizedBox(height: tokens.spaceSm),
              Text(
                'CircleBeacon heeft enkele rechten nodig om stil en betrouwbaar op de '
                'achtergrond voor je gezin te zorgen.',
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
              const SizedBox(height: 20),
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
