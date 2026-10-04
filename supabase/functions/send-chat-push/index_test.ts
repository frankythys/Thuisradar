import { handleRequest } from "./handler.ts";
import { invalidFcmToken } from "../_shared/fcm_result.ts";
import { exportPKCS8, generateKeyPair } from "npm:jose@5";

function check(value: unknown, message: string): asserts value {
  if (!value) throw new Error(message);
}

Deno.test("FCM payload errors never delete a valid token", () => {
  check(!invalidFcmToken({ error: { status: "INVALID_ARGUMENT" } }), "invalid payload");
  check(!invalidFcmToken({ error: { status: "NOT_FOUND" } }), "project missing");
  check(invalidFcmToken({ error: { details: [{ errorCode: "UNREGISTERED" }] } }), "expired token");
});

Deno.test("chat push validates secret, stored message and excludes the author", async () => {
  const previousFetch = globalThis.fetch;
  const keys = ["SOS_WEBHOOK_SECRET", "SUPABASE_URL", "SUPABASE_SERVICE_ROLE_KEY", "FCM_SERVICE_ACCOUNT"];
  const old = keys.map((key) => Deno.env.get(key));
  const { privateKey } = await generateKeyPair("RS256", { extractable: true });
  const calls: string[] = [];
  const payloads: Record<string, any>[] = [];
  let tokenQuery = "";
  let memberQuery = "";
  let exists = true;
  let fcmError = false;
  let membersError = false;
  let hasRecipients = true;
  let notificationVersion = 2;
  try {
    Deno.env.set("SOS_WEBHOOK_SECRET", "test-secret");
    Deno.env.set("SUPABASE_URL", "https://test.invalid");
    Deno.env.set("SUPABASE_SERVICE_ROLE_KEY", "test-key");
    Deno.env.set("FCM_SERVICE_ACCOUNT", JSON.stringify({
      project_id: "test", client_email: "test@example.com", private_key: await exportPKCS8(privateKey),
    }));
    globalThis.fetch = async (input, init) => {
      const url = new URL(typeof input === "string" ? input : input instanceof URL ? input.href : input.url);
      calls.push(url.pathname);
      if (url.hostname === "oauth2.googleapis.com") return Response.json({ access_token: "fake" });
      if (url.hostname === "fcm.googleapis.com") {
        payloads.push(JSON.parse(init!.body as string));
        return fcmError
          ? Response.json({ error: { status: "INVALID_ARGUMENT" } }, { status: 400 })
          : Response.json({ name: "fake-message" });
      }
      if (url.pathname.endsWith("/messages")) return Response.json(exists ? { id: 7, family_id: "family", user_id: "author" } : null);
      if (url.pathname.endsWith("/profiles")) return Response.json({ display_name: "Papa" });
      if (url.pathname.endsWith("/family_members")) {
        memberQuery = url.search;
        if (membersError) return Response.json({ message: "unavailable" }, { status: 503 });
        return Response.json(hasRecipients ? [{ user_id: "recipient" }] : []);
      }
      if (url.pathname.endsWith("/device_tokens")) {
        check(init?.method !== "DELETE", "must not delete tokens for bad payloads");
        tokenQuery = url.search;
        return Response.json([{ token: "recipient-token", notification_version: notificationVersion }]);
      }
      throw new Error(`Unexpected request: ${url}`);
    };
    const request = (secret = "test-secret") => new Request("https://edge.invalid", {
      method: "POST", headers: { "x-webhook-secret": secret },
      body: JSON.stringify({ record: { id: 7, family_id: "family", user_id: "author", body: "private text" } }),
    });
    check((await handleRequest(request("wrong"))).status === 401, "secret required");
    check(calls.length === 0, "unauthorized request touched backend");
    const result = await (await handleRequest(request())).json();
    check(result.sent === 1 && result.failed === 0, "send count");
    check(new URLSearchParams(memberQuery).get("user_id") === "neq.author", "exclude author");
    check(new URLSearchParams(memberQuery).get("family_id") === "eq.family", "family isolation");
    check(new URLSearchParams(tokenQuery).get("user_id") === "in.(recipient)", "recipient tokens only");
    const message = payloads[0].message;
    check(message.android.notification.channel_id === "chat_messages", "chat channel");
    check(message.android.notification.sound === "thuisradar_message", "chat tone");
    check(message.data.type === "chat", "foreground routing");
    check(!JSON.stringify(message).includes("private text"), "lockscreen privacy");
    notificationVersion = 1;
    await handleRequest(request());
    check(payloads[1].message.android.notification.channel_id === "places", "old app keeps an existing channel");
    check(payloads[1].message.android.notification.sound === "default", "old app does not request missing sound");
    fcmError = true;
    const failed = await (await handleRequest(request())).json();
    check(failed.sent === 0 && failed.failed === 1 && failed.cleaned === 0, "do not report failed delivery as sent");
    const count = payloads.length;
    hasRecipients = false;
    check((await (await handleRequest(request())).json()).sent === 0, "empty family");
    exists = false;
    check((await handleRequest(request())).status === 404, "must use stored message");
    exists = true;
    membersError = true;
    check((await handleRequest(request())).status === 503, "membership lookup failure");
    check(payloads.length === count, "must not send on invalid or empty recipients");
  } finally {
    globalThis.fetch = previousFetch;
    keys.forEach((key, i) => old[i] === undefined ? Deno.env.delete(key) : Deno.env.set(key, old[i]!));
  }
});
