import '../../chat/presentation/chat_screen.dart';
import '../../family/application/family_providers.dart';
import '../../profile/presentation/profile_screen.dart';
import '../../../shared/widgets/contact_actions.dart';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../core/utils/clock.dart';
import '../../../core/utils/time_format.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../../shared/widgets/location_preview.dart';

import 'package:latlong2/latlong.dart';

import '../../family/domain/family_member.dart';
import '../../location/application/location_history_providers.dart';
import '../../location/application/location_providers.dart';
import '../../location/application/address_providers.dart';
import '../../location/domain/place_address.dart';
import '../../location/domain/member_location.dart';
import '../../location/domain/timeline.dart';
import '../../location/domain/trip_status.dart';
import '../../places/application/places_providers.dart';
import '../../places/domain/place_timeline.dart';

part 'member_detail_screen_header.dart';
part 'member_detail_screen_stats.dart';
part 'member_detail_screen_stat_card.dart';
part 'member_detail_screen_day_chips.dart';
part 'member_detail_screen_timeline.dart';
part 'member_detail_screen_timeline_row.dart';

/// Scherm 12: detail van één gezinslid met stats en de dagtijdlijn.
class MemberDetailScreen extends ConsumerStatefulWidget {
  const MemberDetailScreen({
    super.key,
    required this.member,
    required this.familyId,
    this.location,
  });

  final FamilyMember member;
  final String familyId;
  final MemberLocation? location;

  @override
  ConsumerState<MemberDetailScreen> createState() => _MemberDetailScreenState();
}

class _MemberDetailScreenState extends ConsumerState<MemberDetailScreen> {
  int _dayOffset = 0;

  static const _dayLabels = ['Vandaag', 'Gisteren', '30 dagen'];

  /// Lokale middernacht van de gekozen dag. Zonder tijdscomponent, zodat de
  /// provider-sleutel stabiel blijft tussen rebuilds (anders: oneindig laden).
  DateTime get _selectedDay {
    final now = ref.read(clockProvider).value ?? DateTime.now();
    return DateTime(
      now.year,
      now.month,
      now.day,
    ).subtract(Duration(days: _dayOffset));
  }

  /// De live locatie uit de realtime-stroom; valt terug op de meegegeven
  /// locatie zolang de stroom nog niet geladen is. Zo ververst het
  /// detailscherm mee met nieuwe updates.
  MemberLocation? _liveLocation(WidgetRef ref) {
    final locations = ref.watch(familyLocationsProvider(widget.familyId)).value;
    if (locations != null) {
      for (final location in locations) {
        if (location.userId == widget.member.userId) return location;
      }
    }
    return widget.location;
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final location = _liveLocation(ref);
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    final query = (userId: widget.member.userId, day: _selectedDay);
    final timeline = ref.watch(
      _dayOffset == 2
          ? recentTimelineProvider(widget.member.userId)
          : timelineProvider(query),
    );

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Gezinslid Detail'),
      body: SafeArea(
        child: ListView(
          padding: EdgeInsets.all(tokens.spaceLg),
          children: [
            _Header(member: widget.member, location: location),
            const SizedBox(height: 16),
            _Stats(
              location: location,
              timeline: timeline.value ?? const [],
              now: now,
            ),
            const SizedBox(height: 16),
            _DayChips(
              selected: _dayOffset,
              onSelected: (i) => setState(() => _dayOffset = i),
            ),
            const SizedBox(height: 16),
            if (location != null) ...[
              AppCard(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      children: [
                        const Icon(
                          Icons.route,
                          size: 20,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          'Actieve route',
                          style: Theme.of(context).textTheme.titleMedium,
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    LocationPreview(
                      latitude: location.latitude,
                      longitude: location.longitude,
                      initial: widget.member.initial,
                      height: 170,
                      route: [
                        for (final entry in timeline.value ?? <TimelineEntry>[])
                          LatLng(entry.latitude, entry.longitude),
                      ],
                    ),
                    const SizedBox(height: 10),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(
                          Icons.location_on_outlined,
                          size: 18,
                          color: AppColors.primary,
                        ),
                        const SizedBox(width: 6),
                        Expanded(
                          child: Text(
                            ref
                                .watch(
                                  placeAddressProvider(
                                    snapToAddressGrid(
                                      location.latitude,
                                      location.longitude,
                                    ),
                                  ),
                                )
                                .when(
                                  data: (address) =>
                                      address == null || address.isEmpty
                                      ? 'Adres niet beschikbaar'
                                      : address.label,
                                  loading: () => 'Adres ophalen…',
                                  error: (_, _) => 'Adres niet beschikbaar',
                                ),
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 20),
            ],
            Text(
              _dayOffset == 2
                  ? 'Locatiegeschiedenis · 30 dagen'
                  : 'Locatiegeschiedenis',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            SizedBox(height: tokens.spaceSm),
            timeline.when(
              data: (entries) => _Timeline(
                entries: attachPlaceNames(
                  entries,
                  ref.watch(familyPlacesProvider(widget.familyId)).value ??
                      const [],
                ),
              ),
              loading: () => const Padding(
                padding: EdgeInsets.all(32),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => ErrorView(
                message: 'Geschiedenis laden mislukt.\n$e',
                onRetry: () => ref.invalidate(timelineProvider(query)),
              ),
            ),
            if (location != null) ...[
              const SizedBox(height: 20),
              FilledButton.icon(
                onPressed: () => openDirections(
                  context,
                  location.latitude,
                  location.longitude,
                ),
                icon: const Icon(Icons.navigation_outlined, size: 20),
                label: Text(
                  'Routebeschrijving naar ${widget.member.displayName}',
                ),
              ),
            ],
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              alignment: WrapAlignment.center,
              children: [
                TextButton.icon(
                  onPressed: () async {
                    final family = await ref.read(myFamilyProvider.future);
                    if (family != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ChatScreen(family: family),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 16),
                  label: const Text('Stuur bericht'),
                ),
                TextButton.icon(
                  onPressed: () => callMember(context, widget.member),
                  icon: const Icon(Icons.call_outlined, size: 16),
                  label: const Text('Bellen'),
                ),
                TextButton.icon(
                  onPressed: () async {
                    final family = await ref.read(myFamilyProvider.future);
                    if (family != null && context.mounted) {
                      Navigator.push(
                        context,
                        MaterialPageRoute<void>(
                          builder: (_) => ProfileScreen(family: family),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.notifications_outlined, size: 16),
                  label: const Text('Meldingen'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
