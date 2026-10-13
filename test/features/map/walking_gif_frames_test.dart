import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/core/theme/app_theme.dart';
import 'package:thuisradar/features/family/domain/family_member.dart';
import 'package:thuisradar/features/location/domain/member_location.dart';
import 'package:thuisradar/features/map/domain/member_on_map.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_history_bubble.dart';
import 'package:thuisradar/features/map/presentation/widgets/walking_gif_frames.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('enkel vooruit: één volledige pas, nooit terug', () {
    final frames = List.generate(30, (i) => i);
    final loop = walkingLoop(frames);
    expect(loop, List.generate(kWalkingLoopFrames, (i) => i));
    for (var i = 1; i < loop.length; i++) {
      expect(loop[i], greaterThan(loop[i - 1]), reason: 'nooit een beeld terug');
    }
    expect(walkingLoop([1, 2]), [1, 2]);
    expect(walkingLoop(<int>[]), isEmpty);
  });

  testWidgets('de transparante wandel-GIF wordt beeld per beeld gedecodeerd', (tester) async {
    final frames = (await tester.runAsync(walkingGifFrames))!;
    // Eén volledige pas, enkel vooruit.
    expect(frames, hasLength(kWalkingLoopFrames));
    expect({for (final frame in frames) frame.image}, hasLength(kWalkingLoopFrames));
    expect(frames.every((f) => f.duration == const Duration(milliseconds: 100)), isTrue);
    expect(frames.first.image.width, 144);
    expect(frames.first.image.height, 96);
    // Tweede keer uit het geheugen, niet opnieuw gedecodeerd.
    expect(identical(await tester.runAsync(walkingGifFrames), frames), isTrue);
  });

  test('de ballon gebruikt de transparante GIF', () {
    expect(walkingGifAsset, 'assets/gif/wandelen_transparant.gif');
  });

  testWidgets('Google: de ballon heeft een lege plek, de animatie toont enkel de sneakers', (tester) async {
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
    expect(MemberHistoryBubble.isWalking(walking, now), isTrue);
    Future<void> pump(WalkerDisplay walker) => tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Center(
          child: SizedBox(
            width: 142,
            height: 48,
            child: MemberHistoryBubble(
              entry: walking,
              now: now,
              onTap: () {},
              walker: walker,
              walkerFrame: frames.first.image,
            ),
          ),
        ),
      ),
    );

    // Vaste ballon: tekst zichtbaar, geen GIF (die tekent Google er bovenop).
    await pump(WalkerDisplay.slot);
    expect(find.byType(Image), findsNothing);
    expect(find.byType(RawImage), findsNothing);
    expect(tester.widget<Visibility>(find.byType(Visibility)).visible, isTrue);

    // Animatiebeeld: enkel de sneakers, op dezelfde plek; tekst en wit vlak weg.
    await pump(WalkerDisplay.frame);
    expect(tester.widget<RawImage>(find.byType(RawImage)).image, same(frames.first.image));
    expect(tester.widget<Visibility>(find.byType(Visibility)).visible, isFalse);
    expect(tester.widget<Material>(find.byType(Material).last).color, Colors.transparent);
  });
}
