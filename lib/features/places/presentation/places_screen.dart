import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/privacy_note.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/domain/family.dart';
import '../application/places_providers.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_card.dart';

/// Scherm 13: lijst van veilige zones met wie er nu is.
class PlacesScreen extends ConsumerStatefulWidget {
  const PlacesScreen({super.key, required this.family});

  final Family family;

  @override
  ConsumerState<PlacesScreen> createState() => _PlacesScreenState();
}

class _PlacesScreenState extends ConsumerState<PlacesScreen> {
  bool _activeOnly = false;
  final _deletedIds = <String>{};
  Family get family => widget.family;

  void _add(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => AddPlaceScreen(familyId: family.id),
      ),
    );
  }

  Future<void> _delete(BuildContext context, WidgetRef ref, Place place) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Plaats verwijderen?'),
        content: Text('"${place.name}" wordt verwijderd voor het hele gezin.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Annuleren'),
          ),
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
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Verwijderen mislukt. Probeer opnieuw.'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final places = ref.watch(familyPlacesProvider(family.id));
    final presence =
        ref.watch(familyPresenceProvider(family.id)).value ?? const [];

    return Scaffold(
      appBar: const BrandedAppBar(title: 'Plaatsen'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
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
                  padding: EdgeInsets.fromLTRB(
                    tokens.spaceLg,
                    tokens.spaceLg,
                    tokens.spaceLg,
                    96,
                  ),
                  children: [
                    Text(
                      'Plaatsen',
                      style: Theme.of(context).textTheme.headlineLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Geregistreerde veilige zones voor je gezin (${list.length} plaatsen)',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                    const SizedBox(height: 16),
                    Wrap(
                      spacing: 8,
                      children: [
                        ChoiceChip(
                          label: Text('Alle zones (${list.length})'),
                          selected: !_activeOnly,
                          onSelected: (_) =>
                              setState(() => _activeOnly = false),
                        ),
                        ChoiceChip(
                          label: Text(
                            '${presence.map((p) => p.placeId).toSet().length} Actief bezocht',
                          ),
                          selected: _activeOnly,
                          onSelected: (_) => setState(() => _activeOnly = true),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    for (final place in list.where(
                      (p) =>
                          !_activeOnly ||
                          presence.any((v) => v.placeId == p.id),
                    ))
                      Padding(
                        padding: EdgeInsets.only(bottom: tokens.spaceMd),
                        child: PlaceCard(
                          place: place,
                          presentCount: presence
                              .where((p) => p.placeId == place.id)
                              .length,
                          onDelete: () => _delete(context, ref, place),
                        ),
                      ),
                    const PrivacyNote(
                      title: 'Zuinig voor batterijen',
                      body: 'Je gezin ontvangt alleen meldingen voor de veilige zones die jullie zelf instellen.',
                      icon: Icons.battery_saver_outlined,
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
