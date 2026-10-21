/**
 * Klopt de geheime header van de Database Webhook? Vergelijkt in constante
 * tijd, zodat de looptijd niet verraadt hoeveel tekens al juist zijn.
 * Zonder ingesteld geheim is niets geldig.
 */
export function hasValidWebhookSecret(req: Request, secret: string | undefined): boolean {
  if (!secret) return false;
  const given = new TextEncoder().encode(req.headers.get("x-webhook-secret") ?? "");
  const wanted = new TextEncoder().encode(secret);
  let diff = given.length ^ wanted.length;
  for (let i = 0; i < wanted.length; i++) diff |= (given[i] ?? 0) ^ wanted[i];
  return diff === 0;
}
