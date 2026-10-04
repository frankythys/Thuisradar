import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/icon_filter_chips.dart';
import '../../../family/domain/family.dart';
import '../../../notifications/application/events_providers.dart';
import '../../../notifications/domain/family_event.dart';
import '../../../places/application/places_providers.dart';
import '../../../places/domain/place.dart';
import '../../../places/domain/place_presence.dart';
import '../../../places/domain/place_status.dart';
import '../../domain/member_on_map.dart';
import 'member_sheet_places.dart';
import 'member_tile.dart';
import 'member_places_prompt.dart';
import 'create_circle_card.dart';

/// Uitschuifbaar paneel onder de kaart: uitnodigingskaart, familienaam, een
/// keuzerij Personen/Plaatsen, de ledenkaart en het plaatsenblok.
class MemberListSheet extends ConsumerStatefulWidget {
  const MemberListSheet({
    super.key,
    required this.family,
    required this.members,
    required this.currentUserId,
    required this.now,
    required this.onSelect,
    this.selectedUserId,
    this.placeByUser = const {},
    this.controller,
    this.onInvite,
    this.onPlaces,
    this.onAddPlace,
    this.onCreateCircle,
  });

  final Family family;
  final List<MemberOnMap> members;
  final String? currentUserId;
  final String? selectedUserId;
  final Map<String, PlaceStatus> placeByUser;
  final DateTime now;

  /// Laat de ouder het paneel programmatisch in-/uitschuiven.
  final DraggableScrollableController? controller;

  /// Tik op een lid: beweeg de kaart ernaartoe.
  final ValueChanged<MemberOnMap> onSelect;

  /// Uitnodigingskaart: gezinsleden uitnodigen.
  final VoidCallback? onInvite;

  /// "Beheer plaatsen": opent het volledige plaatsenscherm.
  final VoidCallback? onPlaces;

  /// "Nieuwe cirkel plaatsen": nieuwe veilige zone toevoegen.
  final VoidCallback? onAddPlace;

  final VoidCallback? onCreateCircle;

  @override
  ConsumerState<MemberListSheet> createState() => _MemberListSheetState();
}

class _MemberListSheetState extends ConsumerState<MemberListSheet> {
  int _filter = 0;

  @override
  Widget build(BuildContext context) {
    final tokens = context.tokens;
    final familyId = widget.family.id;
    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const [];
    final presence =
        ref.watch(familyPresenceProvider(familyId)).value ??
        const <PlacePresence>[];
    final events = ref.watch(familyEventsProvider(familyId)).value ?? const [];

    return DraggableScrollableSheet(
      controller: widget.controller,
      initialChildSize: 0.48,
      minChildSize: 0.14,
      maxChildSize: 0.8,
      snap: true,
      // Ook de beginstand is een rustpunt: een kleine correctie bij het
      // loslaten mag het paneel niet helemaal naar de onderrand sturen.
      snapSizes: const [0.48],
      builder: (context, scrollController) => DecoratedBox(
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
          boxShadow: [
            BoxShadow(
              color: Color(0x1A121C1C),
              blurRadius: 24,
              offset: Offset(0, -6),
            ),
          ],
        ),
        child: ListView(
          controller: scrollController,
          padding: EdgeInsets.fromLTRB(
            tokens.spaceMd,
            tokens.spaceSm,
            tokens.spaceMd,
            tokens.spaceMd,
          ),
          children: [
            const _Handle(),
            SizedBox(height: tokens.spaceSm),
            if (widget.onInvite case final invite?)
              _InviteBanner(onTap: invite),
            if (widget.onInvite != null) SizedBox(height: tokens.spaceLg),
            Text(
              widget.family.name,
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            SizedBox(height: tokens.spaceMd),
            IconFilterChips(
              items: const [
                IconFilterItem(icon: Icons.people_alt, label: 'Personen'),
                IconFilterItem(icon: Icons.place_outlined, label: 'Plaatsen'),
              ],
              selectedIndex: _filter,
              onSelected: (index) => setState(() => _filter = index),
            ),
            SizedBox(height: tokens.spaceMd),
            if (_filter == 0)
              ..._membersCard(context)
            else
              ..._places(context, places, presence, events),
          ],
        ),
      ),
    );
  }

  List<Widget> _membersCard(BuildContext context) => [
    DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: const Color(0xFFB8B3C0), width: 1.25),
        boxShadow: context.tokens.shadowLevel1,
      ),
      child: Column(
        children: [
          for (final entry in widget.members)
            MemberTile(
              entry: entry,
              isMe: entry.member.userId == widget.currentUserId,
              now: widget.now,
              placeStatus: widget.placeByUser[entry.member.userId],
              onTap: () => widget.onSelect(entry),
            ),
          if (widget.onInvite case final invite?)
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
              child: SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: invite,
                  style: TextButton.styleFrom(
                    backgroundColor: const Color(0xFFEDEBEF),
                    foregroundColor: const Color(0xFF393342),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    textStyle: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  child: const Text('Voeg een persoon toe'),
                ),
              ),
            ),
          if (widget.onPlaces case final manage?) ...[
            const Divider(
              height: 1,
              indent: 16,
              endIndent: 16,
              color: Color(0xFFD7D3DD),
            ),
            MemberPlacesPrompt(onManage: manage),
          ],
        ],
      ),
    ),
    SizedBox(height: context.tokens.spaceLg),
    if (widget.onCreateCircle case final create?)
      CreateCircleCard(onCreate: create),
  ];

  List<Widget> _places(
    BuildContext context,
    List<Place> places,
    List<PlacePresence> presence,
    List<FamilyEvent> events,
  ) => [
    MemberSheetPlaces(
      places: places,
      presence: presence,
      events: events,
      now: widget.now,
      onAddPlace: widget.onAddPlace,
      onManage: widget.onPlaces,
    ),
  ];
}

/// Uitnodigingskaart bovenaan de ledenlijst.
class _InviteBanner extends StatelessWidget {
  const _InviteBanner({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(tokens.radiusCard),
        border: Border.all(color: AppColors.border),
      ),
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(tokens.radiusCard),
          child: Padding(
            padding: EdgeInsets.all(tokens.spaceMd),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(tokens.radiusMd),
                  ),
                  child: const Icon(
                    Icons.mark_email_unread_outlined,
                    color: AppColors.primary,
                  ),
                ),
                SizedBox(width: tokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Nodig anderen uit, blijf samen veiliger',
                        style: text.titleMedium,
                      ),
                      SizedBox(height: tokens.spaceXs),
                      Text(
                        'Dierbaren toevoegen',
                        style: text.labelLarge?.copyWith(
                          color: AppColors.secondary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Handle extends StatelessWidget {
  const _Handle();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: AppColors.border,
          borderRadius: BorderRadius.circular(2),
        ),
      ),
    );
  }
}
