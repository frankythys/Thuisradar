import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/bubble_layout.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/domain/walking_cycle.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_history_bubble.dart';
import 'package:thuisradar/features/map/presentation/widgets/walking_gif_frames.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('de wandelcyclus wordt één keer naar beelden getekend', (tester) async {
    final frames = (await tester.runAsync(walkingGifFrames))!;
    // Eén volledige, naadloze cyclus op een vast tempo.
    expect(frames, hasLength(kWalkingLoopFrames));
    expect({for (final frame in frames) frame.image}, hasLength(kWalkingLoopFrames));
    expect(frames.every((f) => f.duration == kWalkFrameDuration), isTrue);
    expect(frames.first.image.width, kWalkingFrameWidth);
    expect(frames.first.image.height, kWalkingFrameHeight);
    // Tweede keer uit het geheugen, niet opnieuw getekend.
    expect(identical(await tester.runAsync(walkingGifFrames), frames), isTrue);
  });

  test('de sneaker komt uit de marker-assets', () {
    expect(walkingSneakerAsset, 'assets/markers/sneaker.webp');
  });

  testWidgets('Google: de ballon heeft een vak, precies waar de sneakers erboven komen', (tester) async {
    final now = DateTime(2026, 10, 12, 15);
    final walking = MemberOnMap(
      member: const FamilyMember(userId: 'p', displayName: 'Papa', isOwner: true, colorIndex: 0),
      location: MemberLocation(
        userId: 'p',
        familyId: 'f',
        latitude: 51,
        longitude: 4,
        updatedAt: now,
        speedMps: 1.3,
      ),
    );
    expect(MemberHistoryBubble.isWalking(walking, now), isTrue);
    for (final tailLeft in [true, false]) {
      await tester.pumpWidget(
        MaterialApp(
          theme: AppTheme.light(),
          home: Center(
            child: SizedBox(
              key: const Key('ballon'),
              width: kBubbleWidth,
              height: kBubbleHeight,
              child: MemberHistoryBubble(
                entry: walking,
                now: now,
                onTap: () {},
                tailLeft: tailLeft,
                walker: WalkerDisplay.slot,
              ),
            ),
          ),
        ),
      );
      // Vaste ballon: tekst zichtbaar; zonder stilstaand beeld blijft het vak leeg.
      expect(find.byType(RawImage), findsNothing);
      expect(find.text('5 km/u'), findsOneWidget);
      final slot = find.byWidgetPredicate(
        (widget) =>
            widget is SizedBox &&
            widget.width == MemberHistoryBubble.walkerSlot.width &&
            widget.height == MemberHistoryBubble.walkerSlot.height,
      );
      final origin = tester.getTopLeft(find.byKey(const Key('ballon')));
      expect(tester.getRect(slot).shift(-origin), MemberHistoryBubble.walkerSlot);
    }
  });

  testWidgets('Google: met een stilstaand beeld staan de schoenen in het vak', (tester) async {
    final frames = (await tester.runAsync(walkingGifFrames))!;
    final now = DateTime(2026, 10, 12, 15);
    final walking = MemberOnMap(
      member: const FamilyMember(userId: 'p', displayName: 'Papa', isOwner: true, colorIndex: 0),
      location: MemberLocation(
        userId: 'p',
        familyId: 'f',
        latitude: 51,
        longitude: 4,
        updatedAt: now,
        speedMps: 1.3,
      ),
    );
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: SizedBox(
            key: const Key('ballon'),
            width: kBubbleWidth,
            height: kBubbleHeight,
            child: MemberHistoryBubble(
              entry: walking,
              now: now,
              onTap: () {},
              walker: WalkerDisplay.slot,
              walkerStill: frames.first.image,
            ),
          ),
        ),
      ),
    );
    final still = find.byType(RawImage);
    expect(still, findsOneWidget);
    expect(tester.widget<RawImage>(still).image, same(frames.first.image));
    final origin = tester.getTopLeft(find.byKey(const Key('ballon')));
    expect(tester.getRect(still).shift(-origin), MemberHistoryBubble.walkerSlot);
  });
}
