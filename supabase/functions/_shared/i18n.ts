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

type PlaceEvent = "arrival" | "departure";

// Zinnen zoals in de app (notificationsArrival/Departure in lib/l10n). Zonder
// plaatsnaam een eigen zin: "een plaats" past niet in elke taal in dezelfde zin.
const PLACE: Record<Language, {
  title: string;
  arrival: (name: string, place: string | null) => string;
  departure: (name: string, place: string | null) => string;
}> = {
  nl: {
    title: "Plaatsen",
    arrival: (n, p) => `${n} is aangekomen op ${p ?? "een plaats"}`,
    departure: (n, p) => `${n} is vertrokken van ${p ?? "een plaats"}`,
  },
  en: {
    title: "Places",
    arrival: (n, p) => `${n} arrived at ${p ?? "a place"}`,
    departure: (n, p) => `${n} left ${p ?? "a place"}`,
  },
  fr: {
    title: "Lieux",
    arrival: (n, p) => `${n} est arrivé à ${p ?? "un lieu"}`,
    departure: (n, p) => `${n} a quitté ${p ?? "un lieu"}`,
  },
  de: {
    title: "Orte",
    arrival: (n, p) => (p ? `${n} ist bei ${p} angekommen` : `${n} ist an einem Ort angekommen`),
    departure: (n, p) => (p ? `${n} hat ${p} verlassen` : `${n} hat einen Ort verlassen`),
  },
  es: {
    title: "Lugares",
    arrival: (n, p) => `${n} ha llegado a ${p ?? "un lugar"}`,
    departure: (n, p) => `${n} ha salido de ${p ?? "un lugar"}`,
  },
  pt: {
    title: "Locais",
    arrival: (n, p) => `${n} chegou a ${p ?? "um local"}`,
    departure: (n, p) => `${n} saiu de ${p ?? "um local"}`,
  },
  it: {
    title: "Luoghi",
    arrival: (n, p) => `${n} è arrivato a ${p ?? "un luogo"}`,
    departure: (n, p) => `${n} ha lasciato ${p ?? "un luogo"}`,
  },
  tr: {
    title: "Yerler",
    arrival: (n, p) => (p ? `${n}, ${p} yerine vardı` : `${n} bir yere vardı`),
    departure: (n, p) => (p ? `${n}, ${p} yerinden ayrıldı` : `${n} bir yerden ayrıldı`),
  },
};

/** Titel en tekst van de aankomst/vertrek-push. Zonder naam: "een gezinslid"
 *  in die taal; zonder plaatsnaam (plaats intussen gewist): "een plaats". */
export function placeText(
  language: Language,
  event: PlaceEvent,
  actorName: string | null | undefined,
  placeName: string | null | undefined,
) {
  const t = PLACE[language];
  const name = actorName?.trim() || SOS[language].someone;
  const place = placeName?.trim() || null;
  return { title: t.title, body: t[event](name, place) };
}
