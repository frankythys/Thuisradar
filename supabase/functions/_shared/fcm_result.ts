/** Only explicitly unregistered tokens are safe to delete. A bad payload is not a bad token. */
export function invalidFcmToken(error: unknown): boolean {
  const payload = error as { error?: { details?: { errorCode?: string }[] } } | null;
  return payload?.error?.details?.some((detail) => detail.errorCode === "UNREGISTERED") ?? false;
}
