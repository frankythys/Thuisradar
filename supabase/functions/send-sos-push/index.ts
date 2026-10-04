// Edge Function: stuurt een push-melding naar de gezinsleden wanneer er een
// nieuwe rij in sos_alerts komt (via een Supabase Database Webhook op INSERT).
//
// Beveiliging: alleen aanroepbaar met de juiste geheime header (SOS_WEBHOOK_SECRET).
// Deploy met `--no-verify-jwt`; de webhook authenticeert via deze header.
//
// Benodigde secrets (Edge Function):
//   FCM_SERVICE_ACCOUNT   De Firebase service-account JSON (zelf gezet).
//   SOS_WEBHOOK_SECRET    Een willekeurig geheim, ook als header in de webhook.
//   SUPABASE_URL / SUPABASE_SERVICE_ROLE_KEY  (standaard aanwezig).

import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5";
import { invalidFcmToken } from "../_shared/fcm_result.ts";

interface ServiceAccount {
  project_id: string;
  client_email: string;
  private_key: string;
}

// Google OAuth2-token halen voor de FCM HTTP v1 API.
async function getAccessToken(sa: ServiceAccount): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const key = await jose.importPKCS8(sa.private_key, "RS256");
  const assertion = await new jose.SignJWT({
    scope: "https://www.googleapis.com/auth/firebase.messaging",
  })
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
    body: new URLSearchParams({
      grant_type: "urn:ietf:params:oauth:grant-type:jwt-bearer",
      assertion,
    }),
  });
  const data = await res.json();
  if (!data.access_token) throw new Error("Kon geen FCM-token halen");
  return data.access_token as string;
}

// Eén push versturen; geeft 'invalid' terug als het token opgeruimd moet worden.
async function sendPush(
  projectId: string,
  accessToken: string,
  token: string,
  actorName: string,
  record: { family_id: string; lat: number; lng: number },
  notificationVersion: number,
): Promise<"ok" | "invalid" | "error"> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: "🚨 SOS", body: `${actorName} heeft hulp nodig!` },
        android: {
          priority: "high",
          notification: {
            channel_id: notificationVersion >= 2 ? "sos_alerts_v2" : "sos_alerts",
            sound: notificationVersion >= 2 ? "thuisradar_sos" : "default",
            notification_priority: "PRIORITY_MAX",
            visibility: "PUBLIC",
          },
        },
        data: {
          type: "sos",
          family_id: record.family_id,
          actor: actorName,
          lat: String(record.lat),
          lng: String(record.lng),
        },
      },
    }),
  });

  if (res.ok) return "ok";
  const err = await res.json().catch(() => null);
  if (invalidFcmToken(err)) return "invalid";
  return "error";
}

Deno.serve(async (req) => {
  // 1. Alleen de webhook met het juiste geheim mag binnen.
  const secret = Deno.env.get("SOS_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return new Response("unauthorized", { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const record = body?.record;
  if (!record?.family_id || !record?.user_id) {
    return new Response("geen geldige sos_alerts-rij", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // 2. Naam van de verzender + de andere gezinsleden.
  const { data: actor } = await supabase
    .from("profiles")
    .select("display_name")
    .eq("id", record.user_id)
    .single();
  const actorName = actor?.display_name ?? "Een gezinslid";

  const { data: members } = await supabase
    .from("family_members")
    .select("user_id")
    .eq("family_id", record.family_id)
    .neq("user_id", record.user_id);
  const userIds = (members ?? []).map((m) => m.user_id);
  if (userIds.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const { data: preferences, error: preferencesError } = await supabase
    .from("notification_preferences").select("user_id, arrival, departure, sos").in("user_id", userIds);
  if (preferencesError) return new Response("preferences unavailable", { status: 503 });
  const disabled = new Set((preferences ?? []).filter((p) => p["sos"] === false).map((p) => p.user_id));
  const recipients = userIds.filter((id) => !disabled.has(id));
  if (recipients.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token, notification_version")
    .in("user_id", recipients);
  const tokenList = tokens ?? [];
  if (tokenList.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  // 3. FCM-token + alle pushes versturen.
  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!) as ServiceAccount;
  const accessToken = await getAccessToken(sa);

  const invalid: string[] = [];
  let sent = 0;
  let failed = 0;
  await Promise.all(
    tokenList.map(async ({ token, notification_version }) => {
      const result = await sendPush(sa.project_id, accessToken, token, actorName, record, notification_version);
      if (result === "invalid") invalid.push(token);
      else if (result === "ok") sent++;
      else failed++;
    }),
  );

  // 4. Verlopen/ongeldige tokens opruimen.
  if (invalid.length > 0) {
    await supabase.from("device_tokens").delete().in("token", invalid);
  }

  return new Response(
    JSON.stringify({ sent, failed, cleaned: invalid.length }),
    { headers: { "Content-Type": "application/json" } },
  );
});
