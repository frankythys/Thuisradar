import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/map/presentation/widgets/member_sheet_dimensions.dart';

void main() {
  test('uitnodigingskaart enkel als je alleen in het gezin zit', () {
    expect(MemberSheetDimensions.showsInvite(canInvite: true, memberCount: 1), isTrue);
    expect(MemberSheetDimensions.showsInvite(canInvite: true, memberCount: 2), isFalse);
    expect(MemberSheetDimensions.showsInvite(canInvite: true, memberCount: 4), isFalse);
    // Lege lijst = nog aan het laden: niet heen en weer springen.
    expect(MemberSheetDimensions.showsInvite(canInvite: true, memberCount: 0), isFalse);
    expect(MemberSheetDimensions.showsInvite(canInvite: false, memberCount: 1), isFalse);
  });
}
