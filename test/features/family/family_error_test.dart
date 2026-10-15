import 'package:flutter_test/flutter_test.dart';
import 'package:thuisradar/features/family/domain/family_error.dart';

void main() {
  test('herkent de serverfouten bij joinen', () {
    expect(classifyFamilyError('Onbekende uitnodigingscode'), FamilyError.unknownCode);
    expect(
      classifyFamilyError('Deze uitnodigingscode is verlopen. Vraag een nieuwe code.'),
      FamilyError.expiredCode,
    );
    expect(classifyFamilyError('Niet ingelogd'), FamilyError.other);
  });
}
