// Studio branding: name, logo and three colours (background, text, buttons) that the
// guest pages, the booking page and the admin derive their whole palette from.
//
//   GET    /v1/web/branding          current branding (admin)
//   PUT    /v1/web/branding          JSON { name, bg, text, accent }  ("" = built-in theme)
//   PUT    /v1/web/branding/logo     body: PNG / JPEG / WebP (≤ 2 MB)
//   DELETE /v1/web/branding/logo
//   GET    /v1/public/gallery/:token/branding   (see publicGallery.ts)

import { Env, HttpError, json, nowIso, readJson, str } from "./http";
import { requireWebSession } from "./webAuth";
import { signedMediaUrl } from "./upload";

const MAX_LOGO_BYTES = 2 * 1024 * 1024;
// SVG is left out on purpose: served from this origin it could run script when opened directly.
const LOGO_TYPES: Record<string, string> = { "image/png": "png", "image/jpeg": "jpg", "image/webp": "webp" };
const HEX = /^#[0-9a-f]{6}$/i;

export type Branding = { name: string; logo_url: string; bg: string; text: string; accent: string };

function color(v: unknown): string {
  const value = str(v, 16).toLowerCase();
  if (value === "") return "";
  if (!HEX.test(value)) throw new HttpError(400, "invalid_color", "Màu phải có dạng #rrggbb");
  return value;
}

/** Branding of a studio; studios that never set one get the studio name and the built-in theme. */
export async function brandingFor(env: Env, origin: string, studioId: string): Promise<Branding> {
  const row = await env.DB.prepare(
    `SELECT s.name AS studio_name, b.brand_name, b.logo_object_key, b.bg_color, b.text_color, b.accent_color
       FROM studios s LEFT JOIN studio_branding b ON b.studio_id = s.id
      WHERE s.id = ?`)
    .bind(studioId).first<Record<string, string | null>>();
  if (!row) throw new HttpError(404, "studio_not_found");
  return {
    name: String(row.brand_name || row.studio_name || ""),
    // Long-lived link: the key changes whenever the logo does.
    logo_url: row.logo_object_key ? await signedMediaUrl(env, origin, String(row.logo_object_key), 24 * 3600) : "",
    bg: String(row.bg_color || ""),
    text: String(row.text_color || ""),
    accent: String(row.accent_color || ""),
  };
}

async function ensureRow(env: Env, studioId: string) {
  await env.DB.prepare(
    `INSERT INTO studio_branding (studio_id, updated_at) VALUES (?, ?) ON CONFLICT(studio_id) DO NOTHING`)
    .bind(studioId, nowIso()).run();
}

export async function handleWebBranding(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "PUT") {
    const b = await readJson(req);
    const name = str(b.name, 80);
    const bg = color(b.bg);
    const text = color(b.text);
    const accent = color(b.accent);
    await ensureRow(env, caller.studioId);
    await env.DB.prepare(
      `UPDATE studio_branding SET brand_name = ?, bg_color = ?, text_color = ?, accent_color = ?, updated_at = ?
        WHERE studio_id = ?`)
      .bind(name, bg, text, accent, nowIso(), caller.studioId).run();
  }
  return json({ success: true, branding: await brandingFor(env, url.origin, caller.studioId) }, 200, { "cache-control": "no-store" });
}

export async function handleWebBrandingLogo(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const current = await env.DB.prepare("SELECT logo_object_key FROM studio_branding WHERE studio_id = ?")
    .bind(caller.studioId).first<{ logo_object_key: string | null }>();

  if (req.method === "DELETE") {
    if (current?.logo_object_key) await env.MEDIA.delete(current.logo_object_key);
    await env.DB.prepare("UPDATE studio_branding SET logo_object_key = NULL, updated_at = ? WHERE studio_id = ?")
      .bind(nowIso(), caller.studioId).run();
    return json({ success: true, branding: await brandingFor(env, url.origin, caller.studioId) });
  }

  const contentType = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
  const ext = LOGO_TYPES[contentType];
  if (!ext) throw new HttpError(400, "logo_type_invalid", "Logo phải là PNG, JPG hoặc WebP");
  const bytes = await req.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_LOGO_BYTES) throw new HttpError(400, "logo_too_large", "Logo tối đa 2MB");

  const key = `branding/${caller.studioId}/logo-${Date.now()}.${ext}`;
  await env.MEDIA.put(key, bytes, { httpMetadata: { contentType } });
  await ensureRow(env, caller.studioId);
  await env.DB.prepare("UPDATE studio_branding SET logo_object_key = ?, updated_at = ? WHERE studio_id = ?")
    .bind(key, nowIso(), caller.studioId).run();
  if (current?.logo_object_key) await env.MEDIA.delete(current.logo_object_key);
  return json({ success: true, branding: await brandingFor(env, url.origin, caller.studioId) });
}
