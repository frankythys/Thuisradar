import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../family/domain/family_member.dart';
import '../../../location/domain/member_location.dart';
import '../../../places/domain/confirmed_presence.dart';
import '../../../places/domain/place.dart';
import '../../../places/domain/place_presence.dart';
import '../../../places/presentation/place_row.dart';

/// Plaatsenblok in het kaartpaneel: dezelfde rijen als het Plaatsen-scherm
/// (icoon, naam, adres, meldingen, wie er is), plus "nieuwe cirkel" en
/// "beheer". Tik op een plaats om ze te bewerken.
class MemberSheetPlaces extends StatelessWidget {
  const MemberSheetPlaces({
    super.key,
    required this.places,
    required this.presence,
    required this.locations,
    required this.members,
    required this.now,
    required this.onEdit,
    this.onAddPlace,
    this.onManage,
  });

  final List<Place> places;
  final List<PlacePresence> presence;
  final List<MemberLocation> locations;
  final List<FamilyMember> members;
  final DateTime now;
  final ValueChanged<Place> onEdit;
  final VoidCallback? onAddPlace;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(child: Text('Plaatsen', style: text.titleLarge)),
            if (onManage != null) TextButton(onPressed: onManage, child: const Text('Beheer')),
          ],
        ),
        SizedBox(height: tokens.spaceSm),
        DecoratedBox(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            boxShadow: tokens.shadowLevel1,
          ),
          child: Material(
            type: MaterialType.transparency,
            clipBehavior: Clip.antiAlias,
            borderRadius: BorderRadius.circular(tokens.radiusCard),
            child: Column(
              children: [
                if (places.isEmpty)
                  Padding(
                    padding: EdgeInsets.all(tokens.spaceMd),
                    child: Text(
                      'Nog geen plaatsen. Voeg Thuis of School toe om te weten '
                      'wanneer iemand aankomt.',
                      style: text.bodySmall?.copyWith(color: AppColors.muted),
                    ),
                  ),
                for (final (index, place) in places.indexed) ...[
                  if (index > 0) const Divider(height: 1),
                  PlaceRow(
                    place: place,
                    present: placePeople(place, members, presentUserIdsAt(place, presence, locations, now)),
                    onEdit: () => onEdit(place),
                  ),
                ],
                if (onAddPlace != null) ...[
                  if (places.isNotEmpty) const Divider(height: 1),
                  _AddRow(onTap: onAddPlace!),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceSm + tokens.spaceXs),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: const Icon(Icons.add_location_alt_outlined, color: AppColors.primary),
            ),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Text('Plaats toevoegen', style: text.titleMedium?.copyWith(color: AppColors.primary)),
            ),
          ],
        ),
      ),
    );
  }
}
