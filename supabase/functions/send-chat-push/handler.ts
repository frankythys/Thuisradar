// Chat push via the authenticated database trigger. No message contents on the lock screen.
import { createClient } from "npm:@supabase/supabase-js@2";
import * as jose from "npm:jose@5";
import { invalidFcmToken } from "../_shared/fcm_result.ts";

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
  notificationVersion: number,
): Promise<"ok" | "invalid" | "error"> {
  const res = await fetch(`https://fcm.googleapis.com/v1/projects/${projectId}/messages:send`, {
    method: "POST",
    headers: { Authorization: `Bearer ${accessToken}`, "Content-Type": "application/json" },
    body: JSON.stringify({
      message: {
        token,
        notification: { title: "Thuisradar · Chat", body },
        android: {
          priority: "high",
          notification: {
            channel_id: notificationVersion >= 2 ? "chat_messages" : "places",
            sound: notificationVersion >= 2 ? "thuisradar_message" : "default",
          },
        },
        data: { type: "chat" },
      },
    }),
  });
  if (res.ok) return "ok";
  const err = await res.json().catch(() => null);
  if (invalidFcmToken(err)) return "invalid";
  return "error";
}

export async function handleRequest(req: Request): Promise<Response> {
  const secret = Deno.env.get("SOS_WEBHOOK_SECRET");
  if (!secret || req.headers.get("x-webhook-secret") !== secret) {
    return new Response("unauthorized", { status: 401 });
  }

  const body = await req.json().catch(() => null);
  const record = body?.record;
  if (!record?.id || !record?.family_id || !record?.user_id) {
    return new Response("invalid message", { status: 400 });
  }

  const supabase = createClient(
    Deno.env.get("SUPABASE_URL")!,
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")!,
  );

  // Re-read the stored row before selecting recipients.
  const { data: stored, error: messageError } = await supabase
    .from("messages").select("id, family_id, user_id").eq("id", record.id).maybeSingle();
  if (messageError) return new Response("message unavailable", { status: 503 });
  if (!stored || stored.family_id !== record.family_id || stored.user_id !== record.user_id) {
    return new Response("message not found", { status: 404 });
  }
  const { data: actor } = await supabase
    .from("profiles").select("display_name").eq("id", stored.user_id).single();
  const message = `Nieuw bericht van ${actor?.display_name ?? "een gezinslid"}`;

  const { data: members, error: membersError } = await supabase
    .from("family_members").select("user_id").eq("family_id", stored.family_id).neq("user_id", stored.user_id);
  if (membersError) return new Response("members unavailable", { status: 503 });
  const userIds = (members ?? []).map((m) => m.user_id);
  if (userIds.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const { data: tokens, error: tokensError } = await supabase
    .from("device_tokens").select("token, notification_version").in("user_id", userIds);
  if (tokensError) return new Response("tokens unavailable", { status: 503 });
  const tokenList = tokens ?? [];
  if (tokenList.length === 0) return new Response(JSON.stringify({ sent: 0 }), { status: 200 });

  const sa = JSON.parse(Deno.env.get("FCM_SERVICE_ACCOUNT")!) as ServiceAccount;
  const accessToken = await getAccessToken(sa);

  const invalid: string[] = [];
  let sent = 0;
  let failed = 0;
  await Promise.all(
    tokenList.map(async ({ token, notification_version }) => {
      const result = await sendPush(sa.project_id, accessToken, token, message, notification_version);
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
}

