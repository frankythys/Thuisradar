import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../location/application/location_providers.dart';
import '../application/permissions_providers.dart';
import 'location_disclosure_dialog.dart';
import '../../../l10n/l10n.dart';

part 'permissions_screen_permission_card.dart';
part 'permissions_screen_required_badge.dart';

/// Scherm 10: vraagt locatie (vereist), meldingen, batterij-uitzondering en
/// de stappenteller. Vóór de Android-vraag om locatie komt de uitleg van
/// [showLocationDisclosure]; de batterij-uitzondering staat standaard uit en
/// kiest de gebruiker zelf.
/// Weigeren mag: de app gaat gewoon door en legt uit hoe je het later aanzet.
class PermissionsScreen extends ConsumerStatefulWidget {
  const PermissionsScreen({super.key});

  @override
  ConsumerState<PermissionsScreen> createState() => _PermissionsScreenState();
}

class _PermissionsScreenState extends ConsumerState<PermissionsScreen> {
  bool _wantNotifications = true;
  bool _wantBattery = false;
  bool _wantSteps = true;
  bool _busy = false;

  void _finish() {
    Navigator.of(context).popUntil((route) => route.isFirst);
  }

  Future<void> _requestAll() async {
    if (_busy) return;
    setState(() => _busy = true);

    final service = ref.read(permissionServiceProvider);
    final disclosed = await showLocationDisclosure(context);
    final locationGranted = disclosed && await service.requestLocation();
    if (locationGranted) await ref.read(locationTrackerProvider.notifier).retryStart();
    if (_wantNotifications) await service.requestNotifications();
    if (_wantBattery) await service.requestBatteryExemption();
    if (_wantSteps) await service.requestSteps();

    if (!mounted) return;
    if (!locationGranted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(context.l10n.permLocationOff),
          action: SnackBarAction(label: context.l10n.commonSettings, onPressed: service.openSettings),
        ),
      );
    }
    _finish();
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final l10n = context.l10n;

    return Scaffold(
      appBar: BrandedAppBar(title: l10n.permTitle),
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
              Text(l10n.permHeadline, style: text.headlineLarge, textAlign: TextAlign.center),
              SizedBox(height: tokens.spaceSm),
              Text(
                l10n.permIntro,
                style: text.bodyLarge?.copyWith(color: AppColors.muted),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              _PermissionCard(
                icon: Icons.location_on_outlined,
                title: l10n.permLocation,
                subtitle: l10n.permLocationSubtitle,
                note: l10n.permLocationNote,
                trailing: const _RequiredBadge(),
              ),
              SizedBox(height: tokens.spaceMd),
              _PermissionCard(
                icon: Icons.notifications_outlined,
                title: l10n.profileNotifications,
                subtitle: l10n.permNotificationsSubtitle,
                note: l10n.permNotificationsNote,
                trailing: Switch(
                  value: _wantNotifications,
                  onChanged: _busy ? null : (v) => setState(() => _wantNotifications = v),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              _PermissionCard(
                icon: Icons.battery_charging_full_outlined,
                title: l10n.permBattery,
                subtitle: l10n.permBatterySubtitle,
                note: l10n.permBatteryNote,
                trailing: Switch(
                  value: _wantBattery,
                  onChanged: _busy ? null : (v) => setState(() => _wantBattery = v),
                ),
              ),
              SizedBox(height: tokens.spaceMd),
              _PermissionCard(
                icon: Icons.directions_walk,
                title: l10n.permSteps,
                subtitle: l10n.permStepsSubtitle,
                note: l10n.permStepsNote,
                trailing: Switch(
                  value: _wantSteps,
                  onChanged: _busy ? null : (v) => setState(() => _wantSteps = v),
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
                          Text(l10n.permPrivacyPromise, style: text.titleMedium),
                          SizedBox(height: tokens.spaceXs),
                          Text(
                            l10n.permPrivacyPromiseText,
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
                          Text(l10n.commonAllow),
                          SizedBox(width: tokens.spaceSm),
                          const Icon(Icons.arrow_forward, size: 20),
                        ],
                      ),
              ),
              TextButton(onPressed: _busy ? null : _finish, child: Text(l10n.permLater)),
            ],
          ),
        ),
      ),
    );
  }
}
