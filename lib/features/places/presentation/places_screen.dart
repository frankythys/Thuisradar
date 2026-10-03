import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/app_card.dart';
import '../../../shared/widgets/branded_app_bar.dart';
import '../../../shared/widgets/empty_state.dart';
import '../../../shared/widgets/error_view.dart';
import '../../family/domain/family.dart';
import '../application/places_providers.dart';
import '../domain/place.dart';
import 'add_place_screen.dart';
import 'place_icons.dart';

/// Scherm 13: lijst van veilige zones met wie er nu is.
class PlacesScreen extends ConsumerWidget {
  const PlacesScreen({super.key, required this.family});

  final Family family;

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
    } on Object catch (error) {
      debugPrint('Plaats verwijderen mislukt: $error');
      if (context.mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Verwijderen mislukt. Probeer opnieuw.')));
      }
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = context.tokens;
    final places = ref.watch(familyPlacesProvider(family.id));
    final presence = ref.watch(familyPresenceProvider(family.id)).value ?? const [];

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
        data: (list) => list.isEmpty
            ? const EmptyState(
                icon: Icons.place_outlined,
                title: 'Nog geen plaatsen',
                message: 'Voeg veilige zones toe zoals Thuis of School om aankomst- en vertrekmeldingen te krijgen.',
              )
            : ListView(
                padding: EdgeInsets.fromLTRB(tokens.spaceLg, tokens.spaceLg, tokens.spaceLg, 96),
                children: [
                  for (final place in list)
                    Padding(
                      padding: EdgeInsets.only(bottom: tokens.spaceMd),
                      child: _PlaceCard(
                        place: place,
                        presentCount: presence.where((p) => p.placeId == place.id).length,
                        onDelete: () => _delete(context, ref, place),
                      ),
                    ),
                ],
              ),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => ErrorView(
          message: 'Plaatsen laden mislukt.\n$e',
          onRetry: () => ref.invalidate(familyPlacesProvider(family.id)),
        ),
      ),
    );
  }
}

class _PlaceCard extends StatelessWidget {
  const _PlaceCard({required this.place, required this.presentCount, required this.onDelete});

  final Place place;
  final int presentCount;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return AppCard(
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(tokens.radiusInput),
            ),
            child: Icon(placeIcon(place.icon), color: AppColors.primary),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(place.name, style: text.titleMedium),
                SizedBox(height: tokens.spaceXs),
                Text(
                  presentCount == 0
                      ? 'Straal ${place.radiusMeters} m · niemand aanwezig'
                      : 'Straal ${place.radiusMeters} m · ${presentCount == 1 ? '1 aanwezig' : '$presentCount aanwezig'}',
                  style: text.bodySmall?.copyWith(color: AppColors.muted),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: onDelete,
            tooltip: 'Verwijderen',
            icon: const Icon(Icons.delete_outline, color: AppColors.muted),
          ),
        ],
      ),
    );
  }
}
