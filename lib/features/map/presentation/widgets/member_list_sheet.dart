import '../../../member/presentation/member_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
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
import 'member_sheet_dimensions.dart';
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
    this.onDeselect,
    this.placeByUser = const {},
    this.controller,
    this.onInvite,
    this.onPlaces,
    this.onAddPlace,
    this.onCreateCircle,
    this.onScrollControllerReady,
  });

  final Family family;
  final List<MemberOnMap> members;
  final String? currentUserId;
  final String? selectedUserId;
  final VoidCallback? onDeselect;
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
  final ValueChanged<ScrollController>? onScrollControllerReady;

  @override
  ConsumerState<MemberListSheet> createState() => _MemberListSheetState();
}

class _MemberListSheetState extends ConsumerState<MemberListSheet> {
  int _filter = 0;
  Drag? _headerDrag;

  @override
  void dispose() {
    _headerDrag?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.members
        .where((entry) => entry.member.userId == widget.selectedUserId)
        .firstOrNull;
    final tokens = context.tokens;
    final familyId = widget.family.id;
    final places = ref.watch(familyPlacesProvider(familyId)).value ?? const [];
    final presence = ref.watch(familyPresenceProvider(familyId)).value ?? const <PlacePresence>[];
    final events = ref.watch(familyEventsProvider(familyId)).value ?? const [];

    return LayoutBuilder(
      builder: (context, constraints) {
        final minimum = widget.onInvite == null
            ? 0.14
            : (MemberSheetDimensions.collapsedHeight(context, constraints.maxWidth) / constraints.maxHeight)
                  .clamp(0.0, 0.94);
        return DraggableScrollableSheet(
          controller: widget.controller,
          initialChildSize: minimum,
          minChildSize: minimum,
          maxChildSize: 0.94,
          // Geen snap-punten: het paneel volgt de vinger, zodat je het rustig naar
          // elke hoogte kunt slepen in plaats van terug te springen naar de helft.
          builder: (context, scrollController) {
            widget.onScrollControllerReady?.call(scrollController);
            return DecoratedBox(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                boxShadow: [BoxShadow(color: Color(0x1A121C1C), blurRadius: 24, offset: Offset(0, -6))],
              ),
              child: ClipRRect(
                borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
                // Bij een gekozen persoon vult het infoscherm het hele paneel,
                // zonder familienaam of keuzeknoppen erboven.
                child: selected != null
                    ? MemberDetailScreen(
                        key: ValueKey(selected.member.userId),
                        member: selected.member,
                        familyId: familyId,
                        location: selected.location,
                        scrollController: scrollController,
                        onBack: widget.onDeselect,
                      )
                    : LayoutBuilder(
                        builder: (context, constraints) => Column(
                          children: [
                            _headerArea(context, constraints, scrollController),
                            Expanded(
                              child: ListView(
                                controller: scrollController,
                                padding: EdgeInsets.fromLTRB(
                                  tokens.spaceMd,
                                  tokens.spaceMd,
                                  tokens.spaceMd,
                                  tokens.spaceMd,
                                ),
                                children: [
                                  if (_filter == 0)
                                    ..._membersCard(context)
                                  else
                                    ..._places(context, places, presence, events),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
              ),
            );
          },
        );
      },
    );
  }

  /// Vaste kop: greep, uitnodigingskaart, familienaam en de keuzeknoppen.
  /// Blijft staan tijdens het scrollen van de ledenlijst of de persoonsdetail.
  Widget _headerArea(BuildContext context, BoxConstraints constraints, ScrollController scrollController) {
    final tokens = context.tokens;
    return SizedBox(
      height: constraints.maxHeight.clamp(0.0, _headerHeight(context, constraints.maxWidth)),
      child: ClipRect(
        child: OverflowBox(
          alignment: Alignment.topCenter,
          minHeight: 0,
          maxHeight: double.infinity,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onVerticalDragStart: (details) {
              _headerDrag = scrollController.position.drag(details, () => _headerDrag = null);
            },
            onVerticalDragUpdate: (details) => _headerDrag?.update(details),
            onVerticalDragEnd: (details) => _headerDrag?.end(details),
            onVerticalDragCancel: () => _headerDrag?.cancel(),
            child: Padding(
              padding: EdgeInsets.fromLTRB(tokens.spaceMd, tokens.spaceSm, tokens.spaceMd, tokens.spaceSm),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const SizedBox(height: 16, child: Center(child: _Handle())),
                  if (widget.onInvite case final invite?) ...[
                    _InviteBanner(onTap: invite),
                    SizedBox(height: tokens.spaceLg),
                  ],
                  Text(widget.family.name, style: Theme.of(context).textTheme.headlineMedium),
                  SizedBox(height: tokens.spaceMd),
                  // De keuzeknoppen staan in de vaste kop zodat ze blijven
                  // staan tijdens het scrollen van de ledenlijst.
                  IconFilterChips(
                    items: const [
                      IconFilterItem(icon: Icons.people_alt, label: 'Personen'),
                      IconFilterItem(icon: Icons.place_outlined, label: 'Plaatsen'),
                    ],
                    selectedIndex: _filter,
                    onSelected: _selectFilter,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Een chip kiezen tijdens de persoonsdetail gaat terug naar de lijst.
  void _selectFilter(int index) {
    setState(() => _filter = index);
  }

  double _headerHeight(BuildContext context, double width) {
    final tokens = context.tokens;
    final text = Theme.of(context).textTheme;
    double height(String value, TextStyle? style, double availableWidth) {
      final painter = TextPainter(
        text: TextSpan(text: value, style: style),
        textDirection: Directionality.of(context),
        textScaler: MediaQuery.textScalerOf(context),
      )..layout(maxWidth: availableWidth.clamp(1.0, double.infinity));
      final result = painter.height;
      painter.dispose();
      return result;
    }

    final innerWidth = width - 2 * tokens.spaceMd;
    var result =
        2 * tokens.spaceSm +
        16 +
        tokens.spaceMd +
        height(widget.family.name, text.headlineMedium, innerWidth) +
        tokens.spaceMd +
        IconFilterChips.chipHeight;
    if (widget.onInvite != null) {
      result += MemberSheetDimensions.inviteHeight(context, width) + tokens.spaceLg;
    }
    return result.ceilToDouble();
  }

  List<Widget> _membersCard(BuildContext context) => [
    DecoratedBox(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(context.tokens.radiusCard),
        border: Border.all(color: AppColors.border, width: 1.25),
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
                    backgroundColor: AppColors.surfaceLow,
                    foregroundColor: AppColors.ink,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
                  ),
                  child: const Text('Voeg een persoon toe'),
                ),
              ),
            ),
        ],
      ),
    ),
    SizedBox(height: context.tokens.spaceLg),
    if (widget.onPlaces case final manage?) ...[
      DecoratedBox(
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(color: AppColors.border),
          boxShadow: const [BoxShadow(color: Color(0x16000000), blurRadius: 10, offset: Offset(0, 3))],
        ),
        child: MemberPlacesPrompt(onManage: manage),
      ),
      SizedBox(height: context.tokens.spaceLg),
    ],
    if (widget.onCreateCircle case final create?) CreateCircleCard(onCreate: create),
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
                  child: const Icon(Icons.mark_email_unread_outlined, color: AppColors.primary),
                ),
                SizedBox(width: tokens.spaceMd),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Nodig anderen uit, blijf samen veiliger', style: text.titleMedium),
                      SizedBox(height: tokens.spaceXs),
                      Text(
                        'Dierbaren toevoegen',
                        style: text.labelLarge?.copyWith(color: AppColors.secondary),
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
        decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)),
      ),
    );
  }
}
