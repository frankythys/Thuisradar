import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/application/family_providers.dart';
import '../../family/domain/family.dart';
import '../../family/domain/family_member.dart';
import '../../../core/utils/clock.dart';
import '../../location/application/location_providers.dart';
import '../../location/domain/member_location.dart';
import '../application/places_providers.dart';
import '../domain/confirmed_presence.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_row.dart';

/// Scherm 13: lijst van veilige zones met wie er nu is.
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  final _deletedIds = <String>{};
  Family get family => widget.family;

  void _add(BuildContext context) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => AddPlaceScreen(familyId: family.id)));
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Place place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plaats verwijderen?'),
        content: Text('"${place.name}" wordt verwijderd voor het hele gezin.'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Annuleren')),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.alert),
            child: const Text('Verwijderen'),
          ),
        ],
      ),
    );
    if (confirm != true) return;

    try {
      await ref.read(placesRepositoryProvider).delete(place.id);
      if (!mounted) return;
      setState(() => _deletedIds.add(place.id));
      // Niet op realtime wachten: meteen opnieuw ophalen zodat de plaats
      // verdwijnt, ook als REPLICA IDENTITY (migratie 008) nog niet gedraaid is.
      ref.invalidate(familyPlacesProvider(family.id));
      ref.invalidate(familyPresenceProvider(family.id));
    } on Object catch (error) {
      debugPrint('Plaats verwijderen mislukt: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Verwijderen mislukt. Probeer opnieuw.')));
      }
    }
  }

  /// "3 plaatsen".
  static String _summary(int places) => '$places ${places == 1 ? 'plaats' : 'plaatsen'}';

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final places = ref.watch(familyPlacesProvider(family.id));
    final text = Theme.of(context).textTheme;
    final members = ref.watch(familyMembersProvider(family.id)).value ?? const <FamilyMember>[];
    // Zelfde regel als de kaart: een achterlopende aanwezigheid telt niet als
    // de GPS duidelijk ergens anders is; wie volgens de GPS binnen staat,
    // telt meteen mee.
    final locations = ref.watch(familyLocationsProvider(family.id)).value ?? const <MemberLocation>[];
    final presence = confirmedPresence(
      ref.watch(familyPresenceProvider(family.id)).value ?? const [],
      places.value ?? const [],
      locations,
    );
    final now = ref.watch(clockProvider).value ?? DateTime.now();
    Set<String> presentIds(Place place) => presentUserIdsAt(place, presence, locations, now);

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Plaatsen'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        icon: const Icon(Icons.add_location_alt_outlined),
        label: const Text('Plaats toevoegen'),
      ),
      body: places.when(
        data: (rows) {
          final list = rows.where((p) => !_deletedIds.contains(p.id)).toList();
          return list.isEmpty
              ? const EmptyState(
                  icon: Icons.place_outlined,
                  title: 'Nog geen plaatsen',
                  message: 'Voeg veilige zones toe zoals Thuis of School om aankomst- en vertrekmeldingen te krijgen.',
                )
              : ListView(
                  padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceMd, 96),
                  children: [
                    Padding(
                      padding: EdgeInsets.fromLTRB(tokens.spaceXs, 0, tokens.spaceXs, tokens.spaceSm),
                      child: Text(
                        _summary(list.length),
                        style: text.bodyMedium?.copyWith(color: AppColors.muted),
                      ),
                    ),
                    AppCard(
                      padding: EdgeInsets.zero,
                      child: Column(
                        children: [
                          for (final (index, place) in list.indexed) ...[
                            if (index > 0) const Divider(height: 1),
                            PlaceRow(
                              place: place,
                              present: placePeople(place, members, presentIds(place)),
                              onEdit: () => Navigator.of(context).push(
                                MaterialPageRoute<void>(
                                  builder: (_) => AddPlaceScreen(familyId: family.id, place: place),
                                ),
                              ),
                              onDelete: () => _delete(context, ref, place),
                            ),
                          ],
                        ],
                      ),
                    ),
                    SizedBox(height: tokens.spaceMd),
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Icon(Icons.battery_saver_outlined, size: 18, color: AppColors.muted),
                        SizedBox(width: tokens.spaceSm),
                        Expanded(
                          child: Text(
                            'Meldingen enkel voor de plaatsen die jullie zelf instellen. Dat spaart batterij.',
                            style: text.bodySmall?.copyWith(color: AppColors.muted),
                          ),
                        ),
                      ],
                    ),
                  ],
                );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Plaatsen laden mislukt.\n$e',
          onRetry: () => ref.invalidate(familyPlacesProvider(family.id)),
        ),
      ),
    );
  }
}
