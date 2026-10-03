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
            channel_id: "sos_alerts",
            sound: "default",
            default_sound: true,
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
  const status = err?.error?.status;
  if (res.status === 404 || status === "NOT_FOUND" || status === "UNREGISTERED" || status === "INVALID_ARGUMENT") {
    return "invalid";
  }
  return "error";
}

Deno.serve(async (req) => {
  // 1. Alleen de webhook met het juiste geheim mag binnen.
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("SOS_WEBHOOK_SECRET")) {
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

  const { data: tokens } = await supabase
    .from("device_tokens")
    .select("token")
    .in("user_id", userIds);
  const tokenList = (tokens ?? []).map((t) => t.token as string);
  if (tokenList.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  // 3. FCM-token + alle pushes versturen.
  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!) as ServiceAccount;
  const accessToken = await getAccessToken(sa);

  const invalid: string[] = [];
  await Promise.all(
    tokenList.map(async (token) => {
      const result = await sendPush(sa.project_id, accessToken, token, actorName, record);
      if (result === "invalid") invalid.push(token);
    }),
  );

  // 4. Verlopen/ongeldige tokens opruimen.
  if (invalid.length > 0) {
    await supabase.from("device_tokens").delete().in("token", invalid);
  }

  return new Response(
    JSON.stringify({ sent: tokenList.length - invalid.length, cleaned: invalid.length }),
    { headers: { "Content-Type": "application/json" } },
  );
});
