// Guest gallery opened from the booth QR. Access is by the session's unguessable
// gallery_token (gal_ + 32 random bytes), never by machine/session ids, so one guest
// cannot browse another session's photos.
//
//   POST /v1/machine/sessions/:sid/gallery-link   (machine token)  -> { token, url }
//   GET  /v1/public/gallery/:token                 photos of that session (+ upload progress)
//   GET  /v1/public/gallery/:token/frames          the studio's frames
//   GET  /v1/public/gallery/:token/filters         the studio's colour filters
//   POST /v1/public/gallery/:token/unlock          { phone } — reopen a booked guest's gallery after 24 h

import { Env, HttpError, isSafeId, json, nowIso, randomToken, readJson } from "./http";
import { requireMachine } from "./auth";
import { ensureGalleryToken } from "./upload";
import { listSessionAssets, listStudioFrames } from "./webStudio";
import { listStudioFilters } from "./webFilters";
import { brandingFor } from "./branding";
import {
  currentCustomer, maskPhone, normalizePhone, recordCustomerFailure, startCustomerSession, throttleCustomerAttempts,
} from "./customers";

const NO_STORE = { "cache-control": "no-store" };

export async function handleMachineGalleryLink(req: Request, env: Env, url: URL, sessionId: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const now = nowIso();
  // The QR can be shown before any photo is uploaded: create the session row if needed.
  await env.DB.prepare(
    `INSERT INTO capture_sessions (machine_id, session_id, studio_id, status, status_version, photos_count,
                                   expected_photos, created_at, updated_at, gallery_token)
     VALUES (?, ?, ?, 'capturing', 0, 0, 0, ?, ?, ?)
     ON CONFLICT(machine_id, session_id) DO NOTHING`)
    .bind(caller.machineId, sessionId, caller.studioId, now, now, randomToken("gal_")).run();
  const owner = await env.DB.prepare("SELECT studio_id FROM capture_sessions WHERE machine_id = ? AND session_id = ?")
    .bind(caller.machineId, sessionId).first<{ studio_id: string }>();
  if (owner?.studio_id !== caller.studioId) throw new HttpError(403, "session_studio_mismatch");
  const token = await ensureGalleryToken(env, caller.machineId, sessionId);
  return json({ success: true, token, url: `${url.origin}/gallery?t=${encodeURIComponent(token)}` }, 200, NO_STORE);
}

type GallerySession = {
  machine_id: string;
  session_id: string;
  studio_id: string;
  studio_name: string;
  status: string;
  asset_sync_status: string;
  expected_photos: number;
  photos_count: number;
  created_at: string;
  updated_at: string;
};

async function sessionByToken(env: Env, token: string): Promise<GallerySession> {
  if (!/^gal_[A-Za-z0-9_-]{20,80}$/.test(token)) throw new HttpError(404, "gallery_not_found", "Link album không hợp lệ");
  const row = await env.DB.prepare(
    `SELECT cs.machine_id, cs.session_id, cs.studio_id, s.name AS studio_name, s.status AS studio_status,
            cs.status, cs.asset_sync_status, cs.expected_photos, cs.photos_count, cs.created_at, cs.updated_at
       FROM capture_sessions cs
       JOIN studios s ON s.id = cs.studio_id
      WHERE cs.gallery_token = ?`)
    .bind(token).first<GallerySession & { studio_status: string }>();
  if (!row || row.studio_status !== "active") throw new HttpError(404, "gallery_not_found", "Link album không hợp lệ hoặc đã bị gỡ");
  return row;
}

/** After this long, a booked guest's gallery link needs the booking phone number again. */
const OPEN_GALLERY_MS = 24 * 3600 * 1000;

type GalleryOwner = { customer_id: string; studio_id: string; name: string; phone: string };

/** The online-booking customer whose 4-digit code started this capture session, if any. */
async function galleryOwner(env: Env, machineId: string, sessionId: string): Promise<GalleryOwner | null> {
  return await env.DB.prepare(
    `SELECT c.id AS customer_id, c.studio_id, c.name, c.phone
       FROM package_codes pc
       JOIN studio_bookings b ON b.code_id = pc.id
       JOIN studio_customers c ON c.id = b.customer_id
      WHERE pc.used_machine_id = ? AND pc.used_session_id = ?
      LIMIT 1`)
    .bind(machineId, sessionId).first<GalleryOwner>() ?? null;
}

/**
 * Gallery links from the booth QR stay open for 24 hours. After that, a session shot with
 * a web-booking code only opens for that guest's signed-in account; others get
 * 403 gallery_locked with the masked booking phone as the message (the page asks for it).
 * Walk-in sessions (no booking) keep working as before.
 */
export async function requireGalleryAccess(req: Request, env: Env, session: { machine_id: string; session_id: string; created_at: string }) {
  const created = Date.parse(session.created_at);
  if (!Number.isNaN(created) && Date.now() - created < OPEN_GALLERY_MS) return;
  const owner = await galleryOwner(env, session.machine_id, session.session_id);
  if (!owner) return;
  const customer = await currentCustomer(req, env);
  if (customer?.id === owner.customer_id) return;
  throw new HttpError(403, "gallery_locked", maskPhone(owner.phone));
}

/** sessionByToken + the 24 h rule, for every guest-facing gallery route. */
async function guestSession(req: Request, env: Env, token: string) {
  const session = await sessionByToken(env, token);
  await requireGalleryAccess(req, env, session);
  return session;
}

export async function handlePublicGalleryUnlock(req: Request, env: Env, token: string): Promise<Response> {
  const session = await sessionByToken(env, token);
  const owner = await galleryOwner(env, session.machine_id, session.session_id);
  if (!owner) return json({ success: true }, 200, NO_STORE);
  await throttleCustomerAttempts(req, env);
  const b = await readJson(req);
  if (normalizePhone(b.phone) !== owner.phone) {
    await recordCustomerFailure(req, env);
    throw new HttpError(403, "phone_mismatch", "Số điện thoại không khớp với lịch đã đặt");
  }
  // Proving the phone signs the guest in, so "Ảnh của tôi" works too.
  const setCookie = await startCustomerSession(req, env, { id: owner.customer_id, studio_id: owner.studio_id, name: owner.name, phone: owner.phone });
  return json({ success: true }, 200, { ...NO_STORE, "set-cookie": setCookie });
}

/** Thumbnails a guest's browser may store for a photo the booth uploaded without one. */
const MAX_THUMBNAIL_BYTES = 300 * 1024;

function thumbnailType(bytes: Uint8Array): string {
  if (bytes[0] === 0xff && bytes[1] === 0xd8 && bytes[2] === 0xff) return "image/jpeg";
  const tag = (from: number, to: number) => String.fromCharCode(...bytes.subarray(from, to));
  if (tag(0, 4) === "RIFF" && tag(8, 12) === "WEBP") return "image/webp";
  return "";
}

/**
 * PUT /v1/public/gallery/:token/thumbnails/:assetId
 * The booth uploads full-size photos only. The first browser that opens the gallery
 * makes a small JPEG/WebP of each photo (or collage) and stores it here, so later visits
 * load kilobytes instead of megabytes. One thumbnail per photo; the first one wins.
 * Display only: viewing in full and downloading always use the original.
 */
export async function handlePublicThumbnail(req: Request, env: Env, token: string, assetId: string): Promise<Response> {
  const session = await guestSession(req, env, token);
  if (!isSafeId(assetId, 1, 200)) throw new HttpError(400, "invalid_asset_id");
  const declared = Number(req.headers.get("content-length") ?? 0);
  if (declared > MAX_THUMBNAIL_BYTES) throw new HttpError(413, "thumbnail_too_large");

  const photo = await env.DB.prepare(
    `SELECT asset_id, photo_index FROM session_assets
      WHERE machine_id = ? AND session_id = ? AND asset_id = ? AND kind IN ('photo','collage') AND status = 'committed'`)
    .bind(session.machine_id, session.session_id, assetId).first<{ asset_id: string; photo_index: number }>();
  if (!photo) throw new HttpError(404, "photo_not_found");
  // The booth uploads its own thumbnail under the same id; whichever lands first stays.
  const thumbId = `thumb-${photo.asset_id}`.slice(0, 128);
  const existing = await env.DB.prepare(
    `SELECT 1 FROM session_assets WHERE machine_id = ? AND session_id = ? AND asset_id = ? LIMIT 1`)
    .bind(session.machine_id, session.session_id, thumbId).first();
  if (existing) return json({ success: true, existed: true }, 200, NO_STORE);

  const bytes = new Uint8Array(await req.arrayBuffer());
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_THUMBNAIL_BYTES) throw new HttpError(400, "thumbnail_size_invalid");
  const contentType = thumbnailType(bytes);
  if (!contentType) throw new HttpError(400, "thumbnail_type_invalid", "Thumbnail phải là JPG hoặc WebP");

  const ext = contentType === "image/webp" ? "webp" : "jpg";
  const objectKey = `thumbnails/${session.studio_id}/${session.machine_id}/${session.session_id}/${photo.asset_id}.${ext}`;
  await env.MEDIA.put(objectKey, bytes, { httpMetadata: { contentType } });
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO session_assets (asset_id, machine_id, session_id, studio_id, object_key, kind, file_name, content_type,
                                 size_bytes, photo_index, status, uploaded_size_bytes, uploaded_at, committed_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'thumbnail', ?, ?, ?, ?, 'committed', ?, ?, ?, ?, ?)
     ON CONFLICT DO NOTHING`)
    .bind(thumbId, session.machine_id, session.session_id, session.studio_id, objectKey,
      `thumb-${photo.asset_id}.${ext}`, contentType, bytes.byteLength, photo.photo_index, bytes.byteLength, now, now, now, now)
    .run();
  return json({ success: true }, 201, NO_STORE);
}

/** An upload started or a photo landed this recently: more may still be on the way. */
const UPLOAD_ACTIVITY_MS = 5 * 60 * 1000;
/** A session the booth still marks as capturing stops counting as live after this long without news. */
const CAPTURING_STALE_MS = 30 * 60 * 1000;
const ENDED_STATUSES = new Set(["COMPLETED", "PARTIAL", "CAMERA_ERROR", "APP_INTERRUPTED", "CANCELLED", "FINISHED"]);

function within(iso: string | null | undefined, ms: number) {
  const at = Date.parse(iso || "");
  return !Number.isNaN(at) && Date.now() - at < ms;
}

/**
 * Whether the booth may still be sending photos, decided here rather than in the browser:
 * the booth's own photo count can be wrong, and before the booth reports the expected
 * assets (finalize) the sync status stays "unknown". Recent upload activity, or a capture
 * still in progress, means yes; a finished session with every reported photo here means no.
 */
async function stillReceiving(env: Env, session: GallerySession, totalPhotos: number) {
  if (session.asset_sync_status === "synced") return false;
  const status = (session.status || "").toUpperCase();
  if (ENDED_STATUSES.has(status) && session.photos_count > 0 && totalPhotos >= session.photos_count) return false;
  // Prints from the web editor ("web-…") are not the booth sending anything.
  const activity = await env.DB.prepare(
    `SELECT MAX(CASE WHEN status = 'committed' AND kind IN ('photo','collage','video','other')
                      AND asset_id NOT LIKE 'web-%' THEN committed_at END) AS last_commit,
            MAX(CASE WHEN status = 'prepared' THEN updated_at END) AS last_prepare
       FROM session_assets
      WHERE machine_id = ? AND session_id = ?`)
    .bind(session.machine_id, session.session_id).first<{ last_commit: string | null; last_prepare: string | null }>();
  if (within(activity?.last_commit, UPLOAD_ACTIVITY_MS) || within(activity?.last_prepare, UPLOAD_ACTIVITY_MS)) return true;
  return (status === "CAPTURING" || status === "WAITING_CAPTURE") && within(session.updated_at, CAPTURING_STALE_MS);
}

export async function handlePublicGallery(req: Request, env: Env, url: URL, token: string, part: string): Promise<Response> {
  // Branding stays open so the "verify your phone" screen can still show the studio's look.
  const session = part === "branding" ? await sessionByToken(env, token) : await guestSession(req, env, token);
  if (part === "frames") {
    return json({ success: true, frames: await listStudioFrames(env, url.origin, session.studio_id) }, 200, NO_STORE);
  }
  if (part === "filters") {
    return json({ success: true, filters: await listStudioFilters(env, url.origin, session.studio_id) }, 200, NO_STORE);
  }
  if (part === "branding") {
    return json({ success: true, branding: await brandingFor(env, url.origin, session.studio_id) }, 200, NO_STORE);
  }
  const page = await listSessionAssets(
    env, url, { studio_id: session.studio_id, studio_name: session.studio_name }, session.machine_id, session.session_id);
  return json({
    ...page,
    session: {
      status: session.status,
      asset_sync_status: session.asset_sync_status,
      expected_photos: Number(session.expected_photos || 0),
      photos_count: Number(session.photos_count || 0),
      created_at: session.created_at,
      receiving: await stillReceiving(env, session, page.total_photos),
    },
  }, 200, NO_STORE);
}
