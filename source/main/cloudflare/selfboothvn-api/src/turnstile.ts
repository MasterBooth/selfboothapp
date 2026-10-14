// Cloudflare Turnstile — "is this a person" check on the admin and staff sign-in forms.
//
//   GET /v1/public/auth-config → { turnstile_site_key }  (empty = not configured: forms skip the widget)
//
// Setup: create a widget for boothme.tech in the Cloudflare dashboard (Turnstile → Add widget,
// mode Managed), put the site key in wrangler.toml [vars] TURNSTILE_SITE_KEY and the secret with
// `npx wrangler secret put TURNSTILE_SECRET_KEY`. Until the secret exists the check is skipped,
// so deploying this code first changes nothing.
//
// It runs before the password check: a bot is turned away before the costly PBKDF2 hash.

import { Env, HttpError, json } from "./http";

const SITEVERIFY_URL = "https://challenges.cloudflare.com/turnstile/v0/siteverify";
const VERIFY_TIMEOUT_MS = 5000;

/**
 * Site key when Turnstile is fully set up (site key AND secret), else "". Both sides use this one
 * switch: the form shows the widget exactly when the server will ask for a token, so a half-done
 * setup can never lock everyone out of sign-in.
 */
export function turnstileSiteKey(env: Env): string {
  const site = (env.TURNSTILE_SITE_KEY ?? "").trim();
  const secret = (env.TURNSTILE_SECRET_KEY ?? "").trim();
  return site && secret ? site : "";
}

export function handleAuthConfig(env: Env): Response {
  return json({ success: true, turnstile_site_key: turnstileSiteKey(env) }, 200, { "cache-control": "public, max-age=300" });
}

/** Throws unless the request carries a valid, unused Turnstile token for `action`. */
export async function requireHuman(req: Request, env: Env, token: unknown, action: string): Promise<void> {
  if (!turnstileSiteKey(env)) return;
  const secret = (env.TURNSTILE_SECRET_KEY ?? "").trim();
  const response = typeof token === "string" ? token.trim() : "";
  if (!response || response.length > 2048) {
    throw new HttpError(400, "turnstile_required", "Hãy hoàn tất bước xác minh trước khi đăng nhập");
  }
  const form = new FormData();
  form.append("secret", secret);
  form.append("response", response);
  const ip = req.headers.get("cf-connecting-ip");
  if (ip) form.append("remoteip", ip);

  let result: { success?: boolean; action?: string; "error-codes"?: string[] } = {};
  try {
    const res = await fetch(SITEVERIFY_URL, { method: "POST", body: form, signal: AbortSignal.timeout(VERIFY_TIMEOUT_MS) });
    result = await res.json();
  } catch {
    throw new HttpError(503, "turnstile_unavailable", "Chưa xác minh được, hãy thử lại sau ít phút");
  }
  // Each token is single-use and tied to the widget's action, so one from another form is refused.
  if (!result.success || (result.action && result.action !== action)) {
    throw new HttpError(403, "turnstile_failed", "Xác minh không thành công, hãy thử lại");
  }
}
