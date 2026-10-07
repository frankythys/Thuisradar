import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_tokens.dart';
import '../../../../core/utils/time_format.dart';
import '../../../location/domain/place_overview.dart';
import '../../../notifications/domain/family_event.dart';
import '../../../places/domain/place.dart';
import '../../../places/domain/place_presence.dart';
import '../../../places/presentation/place_icons.dart';

/// Plaatsenblok onderaan de ledenlijst: de belangrijkste zones met wie er is
/// of wanneer iemand aankwam, plus "nieuwe cirkel" en "beheer plaatsen".
class MemberSheetPlaces extends StatelessWidget {
  const MemberSheetPlaces({
    super.key,
    required this.places,
    required this.presence,
    required this.events,
    required this.now,
    this.onAddPlace,
    this.onManage,
  });

  final List<Place> places;
  final List<PlacePresence> presence;
  final List<FamilyEvent> events;
  final DateTime now;
  final VoidCallback? onAddPlace;
  final VoidCallback? onManage;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;
    final top = placeOverviews(places, presence, events, limit: 3);

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
          child: Column(
            children: [
              if (top.isEmpty)
                Padding(
                  padding: EdgeInsets.all(tokens.spaceMd),
                  child: Text(
                    'Nog geen plaatsen. Voeg Thuis of School toe om te weten '
                    'wanneer iemand aankomt.',
                    style: text.bodySmall?.copyWith(color: AppColors.muted),
                  ),
                ),
              for (final (index, item) in top.indexed) ...[
                if (index > 0)
                  Divider(
                    height: 1,
                    indent: tokens.spaceMd,
                    endIndent: tokens.spaceMd,
                    color: AppColors.border.withValues(alpha: 0.4),
                  ),
                _PlaceRow(item: item, now: now),
              ],
              if (onAddPlace != null) ...[
                Divider(
                  height: 1,
                  indent: tokens.spaceMd,
                  endIndent: tokens.spaceMd,
                  color: AppColors.border.withValues(alpha: 0.4),
                ),
                _AddRow(onTap: onAddPlace!),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _PlaceRow extends StatelessWidget {
  const _PlaceRow({required this.item, required this.now});

  final PlaceOverview item;
  final DateTime now;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Padding(
      padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceMd),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(tokens.radiusMd),
            ),
            child: Icon(placeIcon(item.place.icon), color: AppColors.primary),
          ),
          SizedBox(width: tokens.spaceMd),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.place.name, style: text.titleMedium),
                SizedBox(height: tokens.spaceXs),
                Text(_subtitle(), style: text.bodySmall?.copyWith(color: AppColors.muted)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _subtitle() {
    if (item.hasPeople) {
      final who = item.presentCount == 1 ? '1 gezinslid hier' : '${item.presentCount} gezinsleden hier';
      return item.since == null ? who : '$who · sinds ${formatClock(item.since!)}';
    }
    final last = item.lastArrival;
    return last == null ? 'Nog niemand geweest' : 'Laatste aankomst ${formatRelative(last, now: now)}';
  }
}

class _AddRow extends StatelessWidget {
  const _AddRow({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final tokens = context.tokens;

    return Material(
      type: MaterialType.transparency,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(tokens.radiusCard)),
        child: Padding(
          padding: EdgeInsets.symmetric(horizontal: tokens.spaceMd, vertical: tokens.spaceMd),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.primarySoft,
                  borderRadius: BorderRadius.circular(tokens.radiusMd),
                ),
                child: const Icon(Icons.add, color: AppColors.primary),
              ),
              SizedBox(width: tokens.spaceMd),
              Expanded(child: Text('Nieuwe cirkel plaatsen', style: text.titleMedium)),
            ],
          ),
        ),
      ),
    );
  }
}
