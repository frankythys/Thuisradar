import { pushLanguage, sosText } from "./i18n.ts";

function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

Deno.test("taal van de ontvanger: bekend, leeg (oude app) of onbekend", () => {
  check(pushLanguage("fr") === "fr", "bekende taal blijft");
  check(pushLanguage(null) === "nl", "geen taal: Nederlands zoals vroeger");
  check(pushLanguage("") === "nl", "lege taal: Nederlands");
  check(pushLanguage("ja") === "en", "onbekende taal: Engels");
});

Deno.test("SOS-tekst per taal, met en zonder naam", () => {
  check(sosText("nl", "Papa").body === "Papa heeft hulp nodig!", "nl");
  check(sosText("fr", "Papa").body === "Papa a besoin d'aide !", "fr");
  check(sosText("es", "Papa").body === "¡Papa necesita ayuda!", "es");
  check(sosText("de", null).body === "Ein Familienmitglied braucht Hilfe!", "zonder naam");
  check(sosText("en", "  ").name === "A family member", "lege naam");
  check(sosText("tr", "Liam").title === "🚨 SOS", "titel");
});
