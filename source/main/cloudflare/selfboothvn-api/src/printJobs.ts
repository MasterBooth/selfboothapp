import {
  Env, HttpError, hmacHex, int, isSafeId, json, newId, nowIso, readJson, str,
} from "./http";
import { MachineCaller, requireMachine } from "./auth";
import { isSafeObjectKey, signedMediaUrl, STORAGE_ROOT } from "./upload";
import { requireGalleryAccess } from "./publicGallery";

const NO_STORE = { "cache-control": "no-store" };
const UPLOAD_URL_TTL_SECONDS = 900;
/** Shared print links (sent to an outside print shop) stay open for a week. */
const SHARE_URL_TTL_SECONDS = 7 * 24 * 3600;
const MAX_PRINT_BYTES = 80 * 1024 * 1024;
const MAX_HISTORY = 100;

type PrintSession = {
  machine_id: string;
  hwid: string;
  session_id: string;
  studio_id: string;
  studio_name: string;
  gallery_token: string;
};

function uploadSignaturePayload(key: string, exp: number, ct: string, machineId: string, studioId: string): string {
  return [key, exp, ct, machineId, studioId].join("\n");
}

function cleanFileName(v: unknown): string {
  const name = str(v, 180).replace(/\\/g, "/").split("/").pop() || "print.png";
  const safe = name.replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 180);
  return safe || "print.png";
}

function safeCopies(v: unknown): number {
  return Math.min(10, Math.max(1, int(v, 1)));
}

function patchCopies(body: Record<string, unknown>): number {
  return Object.prototype.hasOwnProperty.call(body, "copies") ? safeCopies(body.copies) : 0;
}

function safeOrientation(v: unknown): string {
  const value = str(v, 20).toLowerCase();
  return value === "portrait" || value === "landscape" ? value : "auto";
}

function patchOrientation(body: Record<string, unknown>): string {
  return Object.prototype.hasOwnProperty.call(body, "orientation") ? safeOrientation(body.orientation) : "";
}

function publicPrintObjectKey(session: PrintSession, fileName: string): string {
  const ext = fileName.toLowerCase().endsWith(".png") ? "png" : "png";
  return `${STORAGE_ROOT}/${session.hwid}/${session.session_id}/prints/${newId()}.${ext}`;
}

async function sessionByGalleryToken(req: Request, env: Env, token: string): Promise<PrintSession> {
  if (!/^gal_[A-Za-z0-9_-]{20,80}$/.test(token)) {
    throw new HttpError(404, "gallery_not_found", "Link album không hợp lệ");
  }
  const row = await env.DB.prepare(
    `SELECT cs.machine_id, cs.session_id, cs.studio_id, cs.gallery_token, cs.created_at,
            m.hwid, s.name AS studio_name, s.status AS studio_status
       FROM capture_sessions cs
       JOIN machines m ON m.id = cs.machine_id
       JOIN studios s ON s.id = cs.studio_id
      WHERE cs.gallery_token = ?`)
    .bind(token).first<PrintSession & { studio_status: string; created_at: string }>();
  if (!row || row.studio_status !== "active") {
    throw new HttpError(404, "gallery_not_found", "Link album không hợp lệ hoặc đã bị gỡ");
  }
  // Same 24 h rule as the gallery itself.
  await requireGalleryAccess(req, env, row);
  return row;
}

function assertPrintObjectForSession(session: PrintSession, objectKey: string): void {
  if (!isSafeObjectKey(objectKey)) throw new HttpError(400, "invalid_object_key");
  const prefix = `${STORAGE_ROOT}/${session.hwid}/${session.session_id}/prints/`;
  if (!objectKey.startsWith(prefix)) throw new HttpError(403, "object_key_prefix_mismatch");
}

function jobDto(row: Record<string, string | number>, mediaUrl: string) {
  return {
    id: row.id,
    studio_id: row.studio_id,
    machine_id: row.machine_id || "",
    session_machine_id: row.session_machine_id,
    session_id: row.session_id,
    object_key: row.object_key,
    file_name: row.file_name,
    content_type: row.content_type,
    size_bytes: Number(row.size_bytes || 0),
    status: row.status,
    copies: Number(row.copies || 1),
    orientation: row.orientation,
    printer_name: row.printer_name || "",
    requested_at: row.requested_at,
    claimed_at: row.claimed_at || "",
    printed_at: row.printed_at || "",
    failed_at: row.failed_at || "",
    error_code: row.error_code || "",
    error_message: row.error_message || "",
    media_url: mediaUrl,
  };
}

async function rowToJob(env: Env, url: URL, row: Record<string, string | number>) {
  return jobDto(row, await signedMediaUrl(env, url.origin, String(row.object_key), 600));
}

export async function handlePublicPrintPrepare(req: Request, env: Env, url: URL, token: string): Promise<Response> {
  const session = await sessionByGalleryToken(req, env, token);
  const secret = (env.UPLOAD_SIGNING_SECRET ?? "").trim();
  if (!secret) throw new HttpError(500, "upload_signing_not_configured");
  const b = await readJson(req);
  const fileName = cleanFileName(b.file_name);
  const contentType = str(b.content_type, 100) || "image/png";
  if (contentType !== "image/png") throw new HttpError(400, "unsupported_print_type", "Ảnh in phải là PNG");
  const sizeBytes = int(b.size_bytes);
  if (sizeBytes <= 0 || sizeBytes > MAX_PRINT_BYTES) throw new HttpError(400, "invalid_size");
  const objectKey = publicPrintObjectKey(session, fileName);
  const exp = Math.floor(Date.now() / 1000) + UPLOAD_URL_TTL_SECONDS;
  const sig = await hmacHex(secret, uploadSignaturePayload(objectKey, exp, contentType, session.machine_id, session.studio_id));
  const uploadUrl = `${url.origin}/v1/upload/object?${new URLSearchParams({
    key: objectKey,
    exp: String(exp),
    ct: contentType,
    m: session.machine_id,
    s: session.studio_id,
    sig,
  }).toString()}`;
  return json({
    success: true,
    object_key: objectKey,
    upload_url: uploadUrl,
    expires_at: new Date(exp * 1000).toISOString(),
    // Link the guest can paste into Zalo for a print shop; valid once the upload lands.
    share_url: await signedMediaUrl(env, url.origin, objectKey, SHARE_URL_TTL_SECONDS),
  }, 201, NO_STORE);
}

export async function handlePublicPrintJobCreate(req: Request, env: Env, token: string): Promise<Response> {
  const session = await sessionByGalleryToken(req, env, token);
  const b = await readJson(req);
  const objectKey = str(b.object_key, 512);
  assertPrintObjectForSession(session, objectKey);
  const object = await env.MEDIA.head(objectKey);
  if (!object) throw new HttpError(409, "print_object_missing", "Ảnh in chưa tải lên xong");

  const now = nowIso();
  const id = newId();
  const fileName = cleanFileName(b.file_name);
  await env.DB.prepare(
    `INSERT INTO print_jobs (id, studio_id, machine_id, session_machine_id, session_id, gallery_token,
       object_key, file_name, content_type, size_bytes, status, copies, orientation, requested_at)
     VALUES (?, ?, NULL, ?, ?, ?, ?, ?, ?, ?, 'pending', ?, ?, ?)`)
    .bind(id, session.studio_id, session.machine_id, session.session_id, token, objectKey, fileName,
      str(b.content_type, 100) || "image/png", object.size, safeCopies(b.copies), safeOrientation(b.orientation), now)
    .run();
  return json({ success: true, job: { id, status: "pending", requested_at: now } }, 201, NO_STORE);
}

/** Asset ids of prints the guest made in the web editor; the booth never uses this prefix. */
export const WEB_COMPOSED_PREFIX = "web-";
/** Web prints are listed after the booth's own photos and collages. */
const WEB_COMPOSED_INDEX = 100000;

/**
 * POST /v1/public/gallery/:token/composed  { id, object_key, file_name, created_at? }
 * Lists a print made in the web editor (the full-size PNG, already uploaded through
 * prints/prepare) as a collage of the session, so "Ảnh đã ghép" shows it on every
 * device, the studio admin's too. `id` is the browser's own id for that print: sending
 * the same print twice keeps one entry.
 */
export async function handlePublicComposedCreate(req: Request, env: Env, token: string): Promise<Response> {
  const session = await sessionByGalleryToken(req, env, token);
  const b = await readJson(req);
  const id = str(b.id, 64);
  if (!isSafeId(id, 8, 64)) throw new HttpError(400, "invalid_id");
  const objectKey = str(b.object_key, 512);
  assertPrintObjectForSession(session, objectKey);
  const object = await env.MEDIA.head(objectKey);
  if (!object) throw new HttpError(409, "print_object_missing", "Ảnh ghép chưa tải lên xong");

  const now = nowIso();
  // A print kept in the browser before it could be sent keeps the time it was made.
  const made = Date.parse(str(b.created_at, 40));
  const createdAt = Number.isNaN(made) || made > Date.now() ? now : new Date(made).toISOString();
  const assetId = `${WEB_COMPOSED_PREFIX}${id}`;
  await env.DB.prepare(
    `INSERT INTO session_assets (asset_id, machine_id, session_id, studio_id, object_key, kind, file_name, content_type,
                                 size_bytes, photo_index, status, uploaded_size_bytes, uploaded_at, committed_at, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, 'collage', ?, ?, ?, ?, 'committed', ?, ?, ?, ?, ?)
     ON CONFLICT DO NOTHING`)
    .bind(assetId, session.machine_id, session.session_id, session.studio_id, objectKey, cleanFileName(b.file_name),
      object.httpMetadata?.contentType || "image/png", object.size, WEB_COMPOSED_INDEX, object.size, now, createdAt, now, now)
    .run();
  return json({ success: true, asset_id: assetId }, 201, NO_STORE);
}

/**
 * DELETE /v1/public/gallery/:token/composed/:assetId
 * Removes a web print from "Ảnh đã ghép". Booth collages cannot be removed here. The PNG
 * itself stays when a print order still points at it.
 */
export async function handlePublicComposedDelete(req: Request, env: Env, token: string, assetId: string): Promise<Response> {
  const session = await sessionByGalleryToken(req, env, token);
  if (!assetId.startsWith(WEB_COMPOSED_PREFIX) || !isSafeId(assetId, 8, 80)) throw new HttpError(400, "invalid_asset_id");
  const thumbId = `thumb-${assetId}`;
  const rows = await env.DB.prepare(
    `SELECT asset_id, object_key FROM session_assets
      WHERE machine_id = ? AND session_id = ? AND asset_id IN (?, ?)`)
    .bind(session.machine_id, session.session_id, assetId, thumbId).all<{ asset_id: string; object_key: string }>();
  const print = (rows.results ?? []).find((row) => row.asset_id === assetId);
  if (!print) return json({ success: true }, 200, NO_STORE);
  const thumb = (rows.results ?? []).find((row) => row.asset_id === thumbId);
  const ordered = await env.DB.prepare(
    "SELECT 1 FROM print_jobs WHERE session_machine_id = ? AND session_id = ? AND object_key = ? LIMIT 1")
    .bind(session.machine_id, session.session_id, print.object_key).first();

  const stmts = [env.DB.prepare(
    "DELETE FROM session_assets WHERE machine_id = ? AND session_id = ? AND asset_id IN (?, ?)")
    .bind(session.machine_id, session.session_id, assetId, thumbId)];
  const keys = thumb ? [thumb.object_key] : [];
  if (!ordered) {
    keys.push(print.object_key);
    stmts.push(env.DB.prepare("DELETE FROM session_photos WHERE object_key = ?").bind(print.object_key));
  }
  await env.DB.batch(stmts);
  if (keys.length > 0) await env.MEDIA.delete(keys);
  return json({ success: true }, 200, NO_STORE);
}

export async function handleMachinePrintJobs(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireMachine(req, env);
  const status = str(url.searchParams.get("status"), 20) || "pending";
  const limit = Math.min(50, Math.max(1, int(Number(url.searchParams.get("limit") ?? 20), 20)));
  if (!["pending", "claimed", "printing", "printed", "failed", "cancelled"].includes(status)) {
    throw new HttpError(400, "invalid_status");
  }
  const rows = await env.DB.prepare(
    `SELECT * FROM print_jobs
      WHERE studio_id = ? AND status = ? AND (machine_id IS NULL OR machine_id = ?)
      ORDER BY requested_at ASC
      LIMIT ?`)
    .bind(caller.studioId, status, caller.machineId, limit).all<Record<string, string | number>>();
  return json({ success: true, jobs: await Promise.all((rows.results ?? []).map((row) => rowToJob(env, url, row))) }, 200, NO_STORE);
}

export async function handleMachinePrintHistory(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireMachine(req, env);
  const limit = Math.min(MAX_HISTORY, Math.max(1, int(Number(url.searchParams.get("limit") ?? 50), 50)));
  const rows = await env.DB.prepare(
    `SELECT * FROM print_jobs
      WHERE studio_id = ? AND machine_id = ? AND status IN ('printed', 'failed', 'cancelled')
      ORDER BY COALESCE(printed_at, failed_at, claimed_at, requested_at) DESC
      LIMIT ?`)
    .bind(caller.studioId, caller.machineId, limit).all<Record<string, string | number>>();
  return json({ success: true, jobs: await Promise.all((rows.results ?? []).map((row) => rowToJob(env, url, row))) }, 200, NO_STORE);
}

async function ownedJob(env: Env, caller: MachineCaller, id: string): Promise<Record<string, string | number>> {
  if (!isSafeId(id, 8, 80)) throw new HttpError(400, "invalid_job_id");
  const row = await env.DB.prepare("SELECT * FROM print_jobs WHERE id = ? AND studio_id = ?")
    .bind(id, caller.studioId).first<Record<string, string | number>>();
  if (!row) throw new HttpError(404, "print_job_not_found");
  const machineId = String(row.machine_id || "");
  if (machineId && machineId !== caller.machineId) throw new HttpError(409, "print_job_claimed");
  return row;
}

export async function handleMachinePrintClaim(req: Request, env: Env, url: URL, id: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  const row = await ownedJob(env, caller, id);
  if (!["pending", "claimed", "printing"].includes(String(row.status))) {
    throw new HttpError(409, "invalid_print_job_state");
  }
  const now = nowIso();
  const updated = await env.DB.prepare(
    `UPDATE print_jobs
        SET machine_id = ?, status = CASE WHEN status = 'pending' THEN 'claimed' ELSE status END,
            claimed_at = COALESCE(claimed_at, ?), error_code = '', error_message = ''
      WHERE id = ? AND studio_id = ? AND (machine_id IS NULL OR machine_id = ?)`)
    .bind(caller.machineId, now, id, caller.studioId, caller.machineId).run();
  if (!updated.meta?.changes) throw new HttpError(409, "print_job_claimed");
  const next = await env.DB.prepare("SELECT * FROM print_jobs WHERE id = ?").bind(id).first<Record<string, string | number>>();
  if (!next) throw new HttpError(404, "print_job_not_found");
  if (String(next.machine_id || "") !== caller.machineId) throw new HttpError(409, "print_job_claimed");
  return json({ success: true, job: await rowToJob(env, url, next) }, 200, NO_STORE);
}

export async function handleMachinePrintReprint(req: Request, env: Env, url: URL, id: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  const original = await ownedJob(env, caller, id);
  if (!["printed", "failed", "cancelled"].includes(String(original.status))) {
    throw new HttpError(409, "invalid_print_job_state");
  }
  const b = await readJson(req);
  const now = nowIso();
  const nextId = newId();
  const copies = Object.prototype.hasOwnProperty.call(b, "copies") ? safeCopies(b.copies) : Number(original.copies || 1);
  const orientation = Object.prototype.hasOwnProperty.call(b, "orientation") ? safeOrientation(b.orientation) : String(original.orientation || "auto");
  const printerName = str(b.printer_name, 120);
  await env.DB.prepare(
    `INSERT INTO print_jobs (id, studio_id, machine_id, session_machine_id, session_id, gallery_token,
       object_key, file_name, content_type, size_bytes, status, copies, orientation, printer_name, requested_at, claimed_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'claimed', ?, ?, ?, ?, ?)`)
    .bind(nextId, caller.studioId, caller.machineId, original.session_machine_id, original.session_id, original.gallery_token,
      original.object_key, original.file_name, original.content_type, original.size_bytes, copies, orientation, printerName, now, now)
    .run();
  const next = await env.DB.prepare("SELECT * FROM print_jobs WHERE id = ?").bind(nextId).first<Record<string, string | number>>();
  if (!next) throw new HttpError(404, "print_job_not_found");
  return json({ success: true, job: await rowToJob(env, url, next) }, 201, NO_STORE);
}

export async function handleMachinePrintPatch(req: Request, env: Env, id: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  const row = await ownedJob(env, caller, id);
  const b = await readJson(req);
  const status = str(b.status, 20);
  if (!["printing", "printed", "failed", "cancelled"].includes(status)) throw new HttpError(400, "invalid_status");
  const current = String(row.status);
  const allowed =
    (status === "printing" && ["claimed", "printing"].includes(current)) ||
    (status === "printed" && ["claimed", "printing", "printed"].includes(current)) ||
    (status === "failed" && ["claimed", "printing", "failed"].includes(current)) ||
    (status === "cancelled" && ["pending", "claimed"].includes(current));
  if (!allowed) throw new HttpError(409, "invalid_print_job_state");
  const now = nowIso();
  const nextCopies = patchCopies(b);
  const nextOrientation = patchOrientation(b);
  await env.DB.prepare(
    `UPDATE print_jobs
        SET status = ?,
            printer_name = CASE WHEN ? <> '' THEN ? ELSE printer_name END,
            copies = CASE WHEN ? > 0 THEN ? ELSE copies END,
            orientation = CASE WHEN ? <> '' THEN ? ELSE orientation END,
            printed_at = CASE WHEN ? = 'printed' THEN ? ELSE printed_at END,
            failed_at = CASE WHEN ? = 'failed' THEN ? ELSE failed_at END,
            error_code = CASE WHEN ? IN ('printed', 'printing') THEN '' ELSE ? END,
            error_message = CASE WHEN ? IN ('printed', 'printing') THEN '' ELSE ? END
      WHERE id = ? AND studio_id = ? AND machine_id = ?`)
    .bind(status,
      str(b.printer_name, 120), str(b.printer_name, 120),
      nextCopies, nextCopies,
      nextOrientation, nextOrientation,
      status, now,
      status, now,
      status, str(b.error_code, 80),
      status, str(b.error_message, 500),
      id, caller.studioId, caller.machineId)
    .run();
  return json({ success: true }, 200, NO_STORE);
}
