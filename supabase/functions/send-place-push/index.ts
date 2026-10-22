// Edge Function: stuurt een gewone push-melding (kanaal "places", geen
// alarmgeluid) wanneer er een aankomst/vertrek-gebeurtenis in family_events komt.
// Via een Database Webhook op family_events INSERT. Niet naar de verzender zelf.
//
// Beveiliging: zelfde geheime header als de SOS-functie (SOS_WEBHOOK_SECRET).
// Deploy met `--no-verify-jwt`.
//
// Secrets: FCM_SERVICE_ACCOUNT, SOS_WEBHOOK_SECRET, SUPABASE_URL,
// SUPABASE_SERVICE_ROLE_KEY (laatste twee standaard aanwezig).

import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5";
import { invalidFcmToken } from "../_shared/fcm_result.ts";
import { hasValidWebhookSecret } from "../_shared/webhook_secret.ts";
import { type Language, placeText, pushLanguage } from "../_shared/i18n.ts";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const key = await jose.importPKCS8(sa.private_key, "RS256");
  const assertion = await new jose.SignJWT({ scope: "https://www.googleapis.com/auth/firebase.messaging" })
    .setProtectedHeader({ alg: "RS256", typ: "JWT" })
    .setIssuer(sa.client_email)
    .setSubject(sa.client_email)
    .setAudience("https://oauth2.googleapis.com/token")
    .setIssuedAt(now)
    .setExpirationTime(now + 3600)
    .sign(key);

  const res = await fetch("https://oauth2.googleapis.com/token", {
    method: "POST",
    headers: { "Content-Type": "application/x-www-form-urlencoded" },
    body: new URLSearchParams({ grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer", assertion }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("Kon geen FCM-token halen");
  return data.access_token as string;
}

async function sendPush(
  projectId: string,
  accessToken: string,
  token: string,
  text: { title: string; body: string },
): Promise<"ok" | "invalid" | "error"> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: text.title, body: text.body },
        android: {
          priority: "high",
          notification: { channel_id: "places_v2", sound: "thuisradar_arrival" },
        },
        data: { type: "place" },
      },
    }),
  });
  if (res.ok) return "ok";
  const err = await res.json().catch(() => null);
  if (invalidFcmToken(err)) return "invalid";
  return "error";
}

Deno.serve(async (req) => {
  if (!hasValidWebhookSecret(req, Deno.env.get("SOS_WEBHOOK_SECRET"))) {
    return new Response("unauthorized", { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const record = body?.record;
  // Enkel aankomst/vertrek; SOS heeft zijn eigen functie.
  if (record?.type !== "arrival" && record?.type !== "departure") {
    return new Response(JSON.stringify({ skipped: true }), { status: 200 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  const { data: actor } = await supabase
    .from("profiles").select("display_name").eq("id", record.actor_user_id).single();
  const actorName: string | null = actor?.display_name ?? null;

  const { data: place } = await supabase
    .from("places").select("name").eq("id", record.place_id).single();
  const placeName: string | null = place?.name ?? null;

  const { data: members } = await supabase
    .from("family_members").select("user_id").eq("family_id", record.family_id).neq("user_id", record.actor_user_id);
  const userIds = (members ?? []).map((m) => m.user_id);
  if (userIds.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const { data: preferences, error: preferencesError } = await supabase
    .from("notification_preferences").select("user_id, arrival, departure, sos").in("user_id", userIds);
  if (preferencesError) return new Response("preferences unavailable", { status: 503 });
  const eventType: "arrival" | "departure" = record.type;
  const disabled = new Set((preferences ?? []).filter((p) => p[eventType] === false).map((p) => p.user_id));
  const recipients = userIds.filter((id) => !disabled.has(id));
  if (recipients.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  // Taal per ontvanger (migratie 022). Ontbreekt de kolom nog, dan Nederlands.
  const { data: profiles, error: languageError } = await supabase
    .from("profiles").select("id, language").in("id", recipients);
  if (languageError) console.warn("Taal van ontvangers onbekend:", languageError.message);
  const languageOf = new Map<string, Language>(
    (profiles ?? []).map((p) => [p.id as string, pushLanguage(p.language as string | null)]),
  );

  const { data: tokens } = await supabase
    .from("device_tokens").select("token, user_id").in("user_id", recipients);
  const tokenList = tokens ?? [];
  if (tokenList.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!) as ServiceAccount;
  const accessToken = await getAccessToken(sa);

  const invalid: string[] = [];
  let sent = 0;
  let failed = 0;
  await Promise.all(
    tokenList.map(async ({ token, user_id }) => {
      const language = languageOf.get(user_id) ?? pushLanguage(null);
      const text = placeText(language, eventType, actorName, placeName);
      const result = await sendPush(sa.project_id, accessToken, token, text);
      if (result === "invalid") invalid.push(token);
      else if (result === "ok") sent++;
      else failed++;
    }),
  );
  if (invalid.length > 0) await supabase.from("device_tokens").delete().in("token", invalid);

  return new Response(
    JSON.stringify({ sent, failed, cleaned: invalid.length }),
    { headers: { "Content-Type": "application/json" } },
  );
});
