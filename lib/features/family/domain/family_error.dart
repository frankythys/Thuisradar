/// Soorten fouten bij gezin maken/joinen. De server antwoordt in het
/// Nederlands (`raise exception` in de migraties); de app toont de tekst in
/// de eigen taal.
enum FamilyError { unknownCode, expiredCode, other }

FamilyError classifyFamilyError(String serverMessage) {
  final message = serverMessage.toLowerCase();
  if (message.contains('onbekende uitnodigingscode')) return FamilyError.unknownCode;
  if (message.contains('uitnodigingscode is verlopen')) return FamilyError.expiredCode;
  return FamilyError.other;
}
