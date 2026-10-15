import 'dart:async';

import '../../../member/presentation/member_detail_screen.dart';

import 'package:flutter/material.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../shared/widgets/icon_filter_chips.dart';
import '../../../../shared/widgets/sheet_handle.dart';
import '../../../family/domain/family.dart';
import '../../../location/application/location_providers.dart';
import '../../../location/domain/member_location.dart';
import '../../../places/application/places_providers.dart';
import '../../../places/domain/place.dart';
import '../../../places/domain/place_presence.dart';
import '../../../places/domain/place_status.dart';
import '../../../places/presentation/add_place_screen.dart';
import '../../domain/member_on_map.dart';
import '../../domain/sheet_snap.dart';
import 'member_sheet_places.dart';
import 'member_sheet_dimensions.dart';
import 'member_tile.dart';
import 'member_places_prompt.dart';
import 'create_circle_card.dart';
import '../../../../l10n/l10n.dart';

/// Uitschuifbaar paneel onder de kaart: familienaam, een keuzerij
/// Personen/Plaatsen, de ledenkaart en het plaatsenblok. De uitnodigingskaart
/// staat bovenaan zolang je nog alleen in het gezin zit.
class MemberListSheet extends ConsumerStatefulWidget {
  const MemberListSheet({
    super.key,
    required this.family,
    required this.members,
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
  DraggableScrollableController? _ownController;

  /// De huidige beweging begon boven de gewone stand (zie [sheetSnapTarget]).
  bool _startedAbove = false;

  /// De huidige beweging begon onder de gewone stand: omhoog stopt dan ook
  /// eerst op de gewone stand.
  bool _startedBelow = false;

  DraggableScrollableController get _controller =>
      widget.controller ?? (_ownController ??= DraggableScrollableController());

  @override
  void dispose() {
    _headerDrag?.cancel();
    _ownController?.dispose();
    super.dispose();
  }

  /// Zet het paneel vast op de gewone stand en beëindigt de beweging.
  void _stopAtRest(double rest) {
    final controller = _controller;
    if (!mounted || !controller.isAttached) return;
    _startedAbove = false;
    _startedBelow = false;
    controller.jumpTo(rest);
  }

  /// Na loslaten onder de gewone stand: naar de gewone stand of helemaal laag,
  /// nooit half (zie [sheetSnapTarget]).
  void _settle(double peek, double rest) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final controller = _controller;
      if (!mounted || !controller.isAttached) return;
      final target = sheetSnapTarget(controller.size, peek: peek, rest: rest, startedAbove: _startedAbove);
      _startedAbove = false;
      if (target == null) return;
      unawaited(
        controller.animateTo(target, duration: const Duration(milliseconds: 220), curve: Curves.easeOut),
      );
    });
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
    final locations = ref.watch(familyLocationsProvider(familyId)).value ?? const <MemberLocation>[];
    final showInvite = MemberSheetDimensions.showsInvite(
      canInvite: widget.onInvite != null,
      memberCount: widget.members.length,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final collapsed = MemberSheetDimensions.collapsedHeight(
          context,
          constraints.maxWidth,
          familyName: widget.family.name,
          showInvite: showInvite,
        );
        final minimum = (collapsed / constraints.maxHeight).clamp(0.0, 0.94);
        // Nog lager kan ook: dan blijft enkel de greep zichtbaar (meer kaart).
        final peekHeight = MemberSheetDimensions.peekHeight(context);
        final peek = (peekHeight / constraints.maxHeight).clamp(0.0, minimum);
        return NotificationListener<ScrollNotification>(
          onNotification: (notification) {
            final controller = _controller;
            if (notification is ScrollStartNotification && controller.isAttached) {
              _startedAbove = sheetAboveRest(controller.size, minimum);
              _startedBelow = controller.size < minimum - 0.002;
            } else if (notification is ScrollEndNotification) {
              _settle(peek, minimum);
            }
            return false;
          },
          child: NotificationListener<DraggableScrollableNotification>(
            // Stand per stand: van boven naar beneden én van onder naar boven
            // stopt het paneel eerst op de gewone stand, al tijdens het slepen.
            // Pas een nieuwe beweging gaat verder.
            onNotification: (notification) {
              if (_startedAbove && notification.extent < minimum) _stopAtRest(minimum);
              if (_startedBelow && notification.extent > minimum) _stopAtRest(minimum);
              return false;
            },
            child: DraggableScrollableSheet(
              controller: _controller,
              initialChildSize: minimum,
              minChildSize: peek,
              maxChildSize: 0.94,
              // Geen snap-punten boven de gewone stand: het paneel volgt de vinger,
              // zodat je het rustig naar elke hoogte kunt slepen. Eronder klikt het
              // naar de gewone of de laagste stand (zie [_settle]).
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
                                _headerArea(context, constraints, scrollController, showInvite: showInvite),
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
                                        ..._places(context, places, presence, locations),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                  ),
                );
              },
            ),
          ),
        );
      },
    );
  }

  /// Vaste kop: greep, uitnodigingskaart, familienaam en de keuzeknoppen.
  /// Blijft staan tijdens het scrollen van de ledenlijst of de persoonsdetail.
  Widget _headerArea(
    BuildContext context,
    BoxConstraints constraints,
    ScrollController scrollController, {
    required bool showInvite,
  }) {
    final tokens = context.tokens;
    final height = MemberSheetDimensions.headerHeight(
      context,
      constraints.maxWidth,
      familyName: widget.family.name,
      showInvite: showInvite,
    );
    return SizedBox(
      height: constraints.maxHeight.clamp(0.0, height),
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
                  // Tekst en knoppen iets lager: in de laagste stand verborgen.
                  const SheetHandle(),
                  if (widget.onInvite case final invite? when showInvite) ...[
                    _InviteBanner(onTap: invite),
                    SizedBox(height: tokens.spaceLg),
                  ],
                  Text(widget.family.name, style: Theme.of(context).textTheme.headlineMedium),
                  SizedBox(height: tokens.spaceMd),
                  // De keuzeknoppen staan in de vaste kop zodat ze blijven
                  // staan tijdens het scrollen van de ledenlijst.
                  IconFilterChips(
                    items: [
                      IconFilterItem(icon: Icons.people_alt, label: context.l10n.mapPeople),
                      IconFilterItem(icon: Icons.place_outlined, label: context.l10n.navPlaces),
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
                  child: Text(context.l10n.mapAddPerson),
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
    List<MemberLocation> locations,
  ) => [
    MemberSheetPlaces(
      places: places,
      presence: presence,
      locations: locations,
      members: [for (final entry in widget.members) entry.member],
      now: widget.now,
      onEdit: (place) => Navigator.of(context).push(
        MaterialPageRoute<void>(
          builder: (_) => AddPlaceScreen(familyId: widget.family.id, place: place),
        ),
      ),
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
                      Text(context.l10n.mapInviteOthers, style: text.titleMedium),
                      SizedBox(height: tokens.spaceXs),
                      Text(
                        context.l10n.mapAddLovedOnes,
                        style: text.labelLarge?.copyWith(color: AppColors.primary),
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
