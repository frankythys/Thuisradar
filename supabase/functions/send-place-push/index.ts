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
  body: string,
): Promise<"ok" | "invalid" | "error"> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: "Plaatsen", body },
        android: {
          priority: "normal",
          notification: { channel_id: "places", sound: "default" },
        },
        data: { type: "place" },
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
  if (req.headers.get("x-webhook-secret") !== Deno.env.get("SOS_WEBHOOK_SECRET")) {
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
  const actorName = actor?.display_name ?? "Een gezinslid";

  const { data: place } = await supabase
    .from("places").select("name").eq("id", record.place_id).single();
  const placeName = place?.name ?? "een plaats";

  const verb = record.type === "arrival" ? "is aangekomen op" : "is vertrokken van";
  const message = `${actorName} ${verb} ${placeName}`;

  const { data: members } = await supabase
    .from("family_members").select("user_id").eq("family_id", record.family_id).neq("user_id", record.actor_user_id);
  const userIds = (members ?? []).map((m) => m.user_id);
  if (userIds.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const { data: tokens } = await supabase
    .from("device_tokens").select("token").in("user_id", userIds);
  const tokenList = (tokens ?? []).map((t) => t.token as string);
  if (tokenList.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!) as ServiceAccount;
  const accessToken = await getAccessToken(sa);

  const invalid: string[] = [];
  await Promise.all(
    tokenList.map(async (token) => {
      if ((await sendPush(sa.project_id, accessToken, token, message)) === "invalid") invalid.push(token);
    }),
  );
  if (invalid.length > 0) await supabase.from("device_tokens").delete().in("token", invalid);

  return new Response(
    JSON.stringify({ sent: tokenList.length - invalid.length, cleaned: invalid.length }),
    { headers: { "Content-Type": "application/json" } },
  );
});
