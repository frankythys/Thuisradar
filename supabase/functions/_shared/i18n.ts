/**
 * Teksten van de pushmeldingen in de taal van de ontvanger (docs/TALEN.md,
 * fase 4). De app bewaart haar taal in profiles.language (migratie 022).
 *
 * Geen taal bekend (oude app-versie, of migratie 022 nog niet gedraaid):
 * Nederlands, zoals vroeger. Een onbekende taal: Engels.
 */

export const LANGUAGES = ["nl", "en", "fr", "de", "es", "pt", "it", "tr"] as const;
export type Language = (typeof LANGUAGES)[number];

/** De taal waarin een ontvanger zijn meldingen krijgt. */
export function pushLanguage(stored: string | null | undefined): Language {
  if (stored == null || stored === "") return "nl";
  return (LANGUAGES as readonly string[]).includes(stored) ? (stored as Language) : "en";
}

const SOS: Record<Language, { body: (name: string) => string; someone: string }> = {
  nl: { body: (name) => `${name} heeft hulp nodig!`, someone: "Een gezinslid" },
  en: { body: (name) => `${name} needs help!`, someone: "A family member" },
  fr: { body: (name) => `${name} a besoin d'aide !`, someone: "Un membre de la famille" },
  de: { body: (name) => `${name} braucht Hilfe!`, someone: "Ein Familienmitglied" },
  es: { body: (name) => `¡${name} necesita ayuda!`, someone: "Un miembro de la familia" },
  pt: { body: (name) => `${name} precisa de ajuda!`, someone: "Um membro da família" },
  it: { body: (name) => `${name} ha bisogno di aiuto!`, someone: "Un familiare" },
  tr: { body: (name) => `${name} yardım istiyor!`, someone: "Bir aile üyesi" },
};

/** Titel en tekst van de SOS-push, en de gebruikte naam. Zonder naam:
 *  "een gezinslid" in die taal. */
export function sosText(language: Language, actorName: string | null | undefined) {
  const t = SOS[language];
  const name = actorName?.trim() || t.someone;
  return { title: "🚨 SOS", body: t.body(name), name };
}
