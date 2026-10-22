import { chatText, placeText, pushLanguage, sosText } from "./i18n.ts";

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

Deno.test("plaatsen-tekst per taal, met en zonder naam of plaats", () => {
  check(placeText("nl", "arrival", "Liam", "School").body === "Liam is aangekomen op School", "nl aankomst");
  check(placeText("nl", "departure", "Liam", "School").body === "Liam is vertrokken van School", "nl vertrek");
  check(placeText("de", "arrival", "Liam", "Schule").body === "Liam ist bei Schule angekommen", "de");
  check(placeText("tr", "departure", "Liam", "Okul").body === "Liam, Okul yerinden ayrıldı", "tr");
  check(placeText("en", "arrival", null, "Home").body === "A family member arrived at Home", "zonder naam");
  check(placeText("de", "departure", "Liam", null).body === "Liam hat einen Ort verlassen", "zonder plaats");
  check(placeText("fr", "arrival", "Liam", "  ").body === "Liam est arrivé à un lieu", "lege plaats");
  check(placeText("es", "arrival", "Liam", "Casa").title === "Lugares", "titel");
});

Deno.test("chat-tekst per taal, met en zonder naam", () => {
  check(chatText("nl", "Papa").body === "Nieuw bericht van Papa", "nl");
  check(chatText("nl", "Papa").title === "CircleBeacon · Chat", "titel nl");
  check(chatText("fr", "Papa").title === "CircleBeacon · Discussion", "titel fr");
  check(chatText("tr", "Papa").body === "Papa yeni bir mesaj gönderdi", "tr");
  check(chatText("nl", null).body === "Nieuw bericht van een gezinslid", "zonder naam");
  check(chatText("de", "  ").body === "Neue Nachricht von einem Familienmitglied", "lege naam de");
});
