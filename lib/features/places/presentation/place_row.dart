import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_tokens.dart';
import '../../../shared/widgets/member_avatar.dart';
import '../../family/domain/family_member.dart';
import '../domain/place.dart';
import 'place_icons.dart';

/// Eén plaats als compacte rij: icoon, naam, adres, straal en welke meldingen
/// aan staan en wie er nu is. Tik om te bewerken; bewerken en verwijderen
/// staan ook in het ⋮-menu.
class PlaceRow extends StatelessWidget {
  const PlaceRow({
    super.key,
    required this.place,
    required this.present,
    required this.onEdit,
    required this.onDelete,
  });

  final Place place;

  /// Te tonen gezinsleden: wie er nu is (here = true) en wie aan deze plaats
  /// gekoppeld is maar er nu niet is (here = false, doorzichtig).
  final List<({FamilyMember member, bool here})> present;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final muted = text.bodySmall?.copyWith(color: AppColors.muted);
    final address =
        place.address ?? '${place.latitude.toStringAsFixed(4)}, ${place.longitude.toStringAsFixed(4)}';

    return InkWell(
      onTap: onEdit,
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          tokens.spaceMd,
          tokens.spaceSm + tokens.spaceXs,
          tokens.spaceXs,
          tokens.spaceSm + tokens.spaceXs,
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primarySoft,
                borderRadius: BorderRadius.circular(tokens.radiusMd),
              ),
              child: Icon(placeIcon(place.icon), color: AppColors.primary),
            ),
            SizedBox(width: tokens.spaceMd),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(place.name, style: text.titleMedium, maxLines: 1, overflow: TextOverflow.ellipsis),
                  Text(address, style: muted, maxLines: 1, overflow: TextOverflow.ellipsis),
                  SizedBox(height: tokens.spaceXs),
                  Row(
                    children: [
                      Icon(
                        place.notifyArrival || place.notifyDeparture
                            ? Icons.notifications_outlined
                            : Icons.notifications_off_outlined,
                        size: 14,
                        color: AppColors.muted,
                      ),
                      SizedBox(width: tokens.spaceXs),
                      Flexible(
                        child: Text(
                          '${place.radiusMeters} m · ${notificationSummary(place)}',
                          style: muted,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            SizedBox(width: tokens.spaceSm),
            if (present.isEmpty) Text('Leeg', style: muted) else _PresentStack(people: present),
            PopupMenuButton<String>(
              tooltip: 'Opties',
              icon: const Icon(Icons.more_vert, color: AppColors.muted),
              // Na het sluiten van het menu, zodat de bevestiging erbovenop komt.
              onSelected: (action) => action == 'edit' ? onEdit() : onDelete(),
              itemBuilder: (context) => [
                const PopupMenuItem<String>(
                  value: 'edit',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.edit_outlined, color: AppColors.primary),
                    title: Text('Bewerken'),
                  ),
                ),
                const PopupMenuItem<String>(
                  value: 'delete',
                  child: ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(Icons.delete_outline, color: AppColors.alert),
                    title: Text('Verwijderen'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// "Aankomst & vertrek", "Enkel aankomst", … plus voor wie, als dat beperkt is.
String notificationSummary(Place place) {
  final kind = switch ((place.notifyArrival, place.notifyDeparture)) {
    (true, true) => 'Aankomst & vertrek',
    (true, false) => 'Enkel aankomst',
    (false, true) => 'Enkel vertrek',
    (false, false) => 'Meldingen uit',
  };
  final watched = place.watchedMembers;
  if (watched == null || watched.isEmpty || kind == 'Meldingen uit') return kind;
  return '$kind · voor ${watched.length} ${watched.length == 1 ? 'lid' : 'leden'}';
}

/// Wie er bij een plaats getoond wordt (op de plek waar anders "Leeg" staat):
/// eerst wie er nu is, daarna de persoon van wie de plaats is (bv. Werk van
/// Franky) als die er nu niet is, doorzichtig.
List<({FamilyMember member, bool here})> placePeople(
  Place place,
  List<FamilyMember> members,
  Set<String> presentUserIds,
) {
  return [
    for (final member in members)
      if (presentUserIds.contains(member.userId)) (member: member, here: true),
    for (final member in members)
      if (member.userId == place.ownerUserId && !presentUserIds.contains(member.userId))
        (member: member, here: false),
  ];
}

class _PresentStack extends StatelessWidget {
  const _PresentStack({required this.people});

  final List<({FamilyMember member, bool here})> people;

  static const _size = 28.0;
  static const _step = 20.0;

  @override
  Widget build(BuildContext context) {
    final shown = people.take(3).toList();
    return SizedBox(
      width: _size + (shown.length - 1) * _step,
      height: _size,
      child: Stack(
        children: [
          for (final (index, person) in shown.indexed)
            Positioned(
              left: index * _step,
              // Dunne witte rand zonder kaartschaduw: dit is een lijst, geen kaart.
              child: Tooltip(
                message: person.here
                    ? '${person.member.displayName} is hier'
                    : '${person.member.displayName} is er nu niet',
                child: Opacity(
                  opacity: person.here ? 1 : 0.4,
                  child: DecoratedBox(
                    decoration: const BoxDecoration(shape: BoxShape.circle, color: Colors.white),
                    child: Padding(
                      padding: const EdgeInsets.all(2),
                      child: MemberAvatar(member: person.member, size: _size - 4),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
