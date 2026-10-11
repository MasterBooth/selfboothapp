// Studio operations for the browser admin and public booking page.

import {
  Env, HttpError, int, isSafeId, json, newId, nowIso, readJson, str,
} from "./http";
import { isFourDigitCode } from "./codes";
import { requireWebSession } from "./webAuth";
import { ensureGalleryToken, signedMediaUrl } from "./upload";
import { brandingFor } from "./branding";
import { settingsFor } from "./bookings";

const FRAME_STORAGE_ROOT = "frames";
const MAX_FRAME_SIZE_BYTES = 20 * 1024 * 1024;
/** A4 sheets with several cards hold more than a dozen holes (the "Demo" sheet has 13). */
const MAX_FRAME_SLOTS = 24;

function money(v: unknown): number {
  const value = Number(v ?? 0);
  if (!Number.isInteger(value) || value < 0) throw new HttpError(400, "invalid_price");
  return value;
}

function positiveInt(v: unknown, code = "invalid_minutes"): number {
  const value = Number(v);
  if (!Number.isInteger(value) || value <= 0) throw new HttpError(400, code);
  return value;
}

async function ensureRoom(env: Env, studioId: string, roomId: string) {
  if (!isSafeId(roomId, 8, 64)) throw new HttpError(400, "invalid_room_id");
  const room = await env.DB.prepare("SELECT id, name FROM studio_rooms WHERE id = ? AND studio_id = ? AND status = 'active'")
    .bind(roomId, studioId).first<{ id: string; name: string }>();
  if (!room) throw new HttpError(404, "room_not_found");
  return room;
}

async function ensurePackage(env: Env, studioId: string, packageId: string) {
  if (!isSafeId(packageId, 8, 64)) throw new HttpError(400, "invalid_package_id");
  const pkg = await env.DB.prepare(
    `SELECT p.id, p.room_id, p.name, p.minutes, p.price_vnd, r.name AS room_name
       FROM studio_packages p
       JOIN studio_rooms r ON r.id = p.room_id
      WHERE p.id = ? AND p.studio_id = ? AND p.status = 'active' AND r.status = 'active'`)
    .bind(packageId, studioId).first<Record<string, string | number>>();
  if (!pkg) throw new HttpError(404, "package_not_found");
  return pkg;
}

async function randomFreeCode(env: Env, studioId: string, taken: Set<string>): Promise<string> {
  for (let i = 0; i < 200; i++) {
    const n = new Uint32Array(1);
    crypto.getRandomValues(n);
    const code = String(n[0] % 10000).padStart(4, "0");
    if (!taken.has(code)) return code;
  }
  throw new HttpError(409, "no_free_code", "Studio đã dùng gần hết 10 000 mã 4 số");
}

export async function handleWebRooms(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "GET") {
    const rs = await env.DB.prepare(
      `SELECT id, name, description, capacity, status, created_at, updated_at
         FROM studio_rooms WHERE studio_id = ? AND status = 'active' ORDER BY created_at DESC`)
      .bind(caller.studioId).all();
    return json({ success: true, rooms: rs.results ?? [] }, 200, { "cache-control": "no-store" });
  }

  const b = await readJson(req);
  const name = str(b.name, 100);
  if (!name) throw new HttpError(400, "room_name_required", "Nhập tên phòng chụp");
  const id = newId();
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_rooms (id, studio_id, name, description, capacity, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .bind(id, caller.studioId, name, str(b.description, 300), str(b.capacity, 80), now, now).run();
  return json({
    success: true,
    room: { id, name, description: str(b.description, 300), capacity: str(b.capacity, 80), status: "active", created_at: now, updated_at: now },
  }, 201);
}

export async function handleWebPackages(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "GET") {
    const rs = await env.DB.prepare(
      `SELECT p.id, p.room_id, p.name, p.minutes, p.price_vnd, p.description, p.status,
              p.created_at, p.updated_at, r.name AS room_name
         FROM studio_packages p
         JOIN studio_rooms r ON r.id = p.room_id
        WHERE p.studio_id = ? AND p.status = 'active' AND r.status = 'active'
        ORDER BY p.created_at DESC`)
      .bind(caller.studioId).all();
    return json({ success: true, packages: rs.results ?? [] }, 200, { "cache-control": "no-store" });
  }

  const b = await readJson(req);
  const room = await ensureRoom(env, caller.studioId, str(b.room_id, 64));
  const name = str(b.name, 100);
  if (!name) throw new HttpError(400, "package_name_required", "Nhập tên gói chụp");
  const minutes = positiveInt(b.minutes);
  const price = money(b.price_vnd);
  const id = newId();
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_packages (id, studio_id, room_id, name, minutes, price_vnd, description, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .bind(id, caller.studioId, room.id, name, minutes, price, str(b.description, 300), now, now).run();
  return json({
    success: true,
    package: {
      id, room_id: room.id, room_name: room.name, name, minutes, price_vnd: price,
      description: str(b.description, 300), status: "active", created_at: now, updated_at: now,
    },
  }, 201);
}

export async function handleWebCodes(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "GET") {
    const status = url.searchParams.get("status");
    const query = status
      ? `AND pc.status = ?`
      : "";
    const stmt = env.DB.prepare(
      `SELECT pc.id, pc.code, pc.kind, pc.minutes, pc.price_vnd, pc.status, pc.valid_from, pc.valid_until,
              pc.note, pc.created_at, pc.used_at, pc.used_machine_id, pc.used_session_id,
              pc.room_id, pc.package_id, r.name AS room_name, p.name AS package_name
         FROM package_codes pc
         LEFT JOIN studio_rooms r ON r.id = pc.room_id
         LEFT JOIN studio_packages p ON p.id = pc.package_id
        WHERE pc.studio_id = ? AND pc.deleted_at IS NULL ${query}
        ORDER BY pc.created_at DESC LIMIT 500`);
    const rs = status ? await stmt.bind(caller.studioId, status).all() : await stmt.bind(caller.studioId).all();
    return json({ success: true, codes: rs.results ?? [] }, 200, { "cache-control": "no-store" });
  }

  const b = await readJson(req);
  const pkg = await ensurePackage(env, caller.studioId, str(b.package_id, 64));
  const kind = str(b.kind, 10) || "single";
  if (kind !== "single" && kind !== "reusable") throw new HttpError(400, "invalid_kind");
  const fixed = str(b.code, 4);
  if (fixed && !isFourDigitCode(fixed)) throw new HttpError(400, "invalid_code", "Mã gồm đúng 4 chữ số");
  const count = fixed ? 1 : Math.min(100, Math.max(1, int(b.count, 1)));
  const active = await env.DB.prepare("SELECT code FROM package_codes WHERE studio_id = ? AND status = 'active'")
    .bind(caller.studioId).all<{ code: string }>();
  const taken = new Set((active.results ?? []).map((row) => row.code));
  if (fixed && taken.has(fixed)) throw new HttpError(409, "code_exists", "Mã này đang hoạt động trong studio");

  const now = nowIso();
  const created: Array<Record<string, unknown>> = [];
  const stmts: D1PreparedStatement[] = [];
  for (let i = 0; i < count; i++) {
    const code = fixed || await randomFreeCode(env, caller.studioId, taken);
    taken.add(code);
    const id = newId();
    stmts.push(env.DB.prepare(
      `INSERT INTO package_codes (id, studio_id, code, kind, minutes, price_vnd, valid_from, valid_until,
                                  note, created_at, room_id, package_id)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(id, caller.studioId, code, kind, Number(pkg.minutes), Number(pkg.price_vnd),
            str(b.valid_from, 40) || null, str(b.valid_until, 40) || null, str(b.note, 200),
            now, pkg.room_id, pkg.id));
    created.push({
      id, code, kind, minutes: Number(pkg.minutes), price_vnd: Number(pkg.price_vnd),
      room_id: pkg.room_id, room_name: pkg.room_name, package_id: pkg.id, package_name: pkg.name,
      status: "active", created_at: now,
    });
  }
  await env.DB.batch(stmts);
  return json({ success: true, codes: created }, 201);
}

export async function handleWebCodeRevoke(req: Request, env: Env, codeId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(codeId, 8, 64)) throw new HttpError(400, "invalid_code_id");
  const res = await env.DB.prepare(
    "UPDATE package_codes SET status = 'revoked' WHERE id = ? AND studio_id = ? AND status = 'active'")
    .bind(codeId, caller.studioId).run();
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "code_not_active");
  return json({ success: true });
}

/** POST /v1/web/capture-sessions/:machine/:session/gallery-link — the guest album link (token made on first ask). */
export async function handleWebSessionGalleryLink(req: Request, env: Env, url: URL, machineId: string, sessionId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(machineId, 8, 64) || !isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const owner = await env.DB.prepare("SELECT studio_id FROM capture_sessions WHERE machine_id = ? AND session_id = ?")
    .bind(machineId, sessionId).first<{ studio_id: string }>();
  if (owner?.studio_id !== caller.studioId) throw new HttpError(404, "session_not_found");
  const token = await ensureGalleryToken(env, machineId, sessionId);
  return json({ success: true, token, url: `${url.origin}/gallery?t=${encodeURIComponent(token)}` }, 200, { "cache-control": "no-store" });
}

/** DELETE /v1/web/rooms/:id — archives the room and its packages (bookings and codes keep their names). */
export async function handleWebRoomDelete(req: Request, env: Env, roomId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(roomId, 8, 64)) throw new HttpError(400, "invalid_room_id");
  const now = nowIso();
  const [room, packages] = await env.DB.batch([
    env.DB.prepare("UPDATE studio_rooms SET status = 'archived', updated_at = ? WHERE id = ? AND studio_id = ? AND status = 'active'")
      .bind(now, roomId, caller.studioId),
    env.DB.prepare("UPDATE studio_packages SET status = 'archived', updated_at = ? WHERE room_id = ? AND studio_id = ? AND status = 'active'")
      .bind(now, roomId, caller.studioId),
  ]);
  if ((room.meta.changes ?? 0) === 0) throw new HttpError(404, "room_not_found");
  return json({ success: true, archived_packages: packages.meta.changes ?? 0 });
}

/** DELETE /v1/web/packages/:id — archives the package; codes already issued keep working. */
export async function handleWebPackageDelete(req: Request, env: Env, packageId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(packageId, 8, 64)) throw new HttpError(400, "invalid_package_id");
  const res = await env.DB.prepare(
    "UPDATE studio_packages SET status = 'archived', updated_at = ? WHERE id = ? AND studio_id = ? AND status = 'active'")
    .bind(nowIso(), packageId, caller.studioId).run();
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "package_not_found");
  return json({ success: true });
}

const MAX_CODE_BULK_DELETE = 500;

/** Hides codes from the admin and revokes the active ones; revenue rows still reference them. */
function softDeleteCodes(env: Env, studioId: string, ids: string[]) {
  const now = nowIso();
  return env.DB.batch(ids.map((id) => env.DB.prepare(
    `UPDATE package_codes
        SET deleted_at = ?, status = CASE WHEN status = 'active' THEN 'revoked' ELSE status END
      WHERE id = ? AND studio_id = ? AND deleted_at IS NULL`)
    .bind(now, id, studioId)));
}

/** DELETE /v1/web/codes/:id */
export async function handleWebCodeDelete(req: Request, env: Env, codeId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(codeId, 8, 64)) throw new HttpError(400, "invalid_code_id");
  const [res] = await softDeleteCodes(env, caller.studioId, [codeId]);
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "code_not_found");
  return json({ success: true });
}

/** POST /v1/web/codes/bulk-delete {ids} */
export async function handleWebCodesBulkDelete(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const b = await readJson(req);
  const ids = Array.isArray(b.ids) ? [...new Set(b.ids.map((id) => String(id)))] : [];
  if (ids.length === 0 || ids.length > MAX_CODE_BULK_DELETE || !ids.every((id) => isSafeId(id, 8, 64))) {
    throw new HttpError(400, "invalid_code_ids");
  }
  const results = await softDeleteCodes(env, caller.studioId, ids);
  const deleted = results.reduce((sum, res) => sum + (res.meta.changes ?? 0), 0);
  return json({ success: true, deleted });
}

export async function handleWebRevenue(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const summary = await env.DB.prepare(
    `SELECT COUNT(*) AS used_codes,
            COALESCE(SUM(u.price_vnd), 0) AS code_revenue_vnd,
            COALESCE(SUM(CASE WHEN u.kind = 'single' THEN 1 ELSE 0 END), 0) AS single_uses,
            COALESCE(SUM(CASE WHEN u.kind = 'reusable' THEN 1 ELSE 0 END), 0) AS reusable_uses,
            COALESCE(SUM(CASE WHEN u.kind = 'local' THEN 1 ELSE 0 END), 0) AS local_uses
       FROM package_code_uses u WHERE u.studio_id = ?`)
    .bind(caller.studioId).first();
  const rows = await env.DB.prepare(
    `SELECT u.id, u.code, u.kind, u.minutes, u.price_vnd, u.used_at, u.source, u.session_id,
            m.hwid, COALESCE(NULLIF(m.display_name, ''), m.device_name) AS device_name, pc.package_id, pc.room_id,
            COALESCE(p.name, NULLIF(u.package_name, '')) AS package_name,
            COALESCE(r.name, NULLIF(u.room_name, '')) AS room_name
       FROM package_code_uses u
       JOIN machines m ON m.id = u.machine_id
       LEFT JOIN package_codes pc ON pc.id = u.code_id
       LEFT JOIN studio_packages p ON p.id = pc.package_id
       LEFT JOIN studio_rooms r ON r.id = pc.room_id
      WHERE u.studio_id = ?
      ORDER BY u.used_at DESC LIMIT 300`)
    .bind(caller.studioId).all();
  return json({ success: true, summary: summary ?? {}, uses: rows.results ?? [] }, 200, { "cache-control": "no-store" });
}

function decodeCursor(v: string | null): string {
  if (!v) return "";
  try { return atob(v); } catch { return ""; }
}

function encodeCursor(v: string): string {
  return btoa(v);
}

function frameObjectKey(studioId: string, frameId: string): string {
  return `${FRAME_STORAGE_ROOT}/${studioId}/${frameId}.png`;
}

function parseFrameSlots(raw: unknown): Array<Record<string, number>> {
  let value = raw;
  if (typeof raw === "string") {
    try {
      value = JSON.parse(raw);
    } catch {
      throw new HttpError(400, "invalid_slots");
    }
  }
  if (!Array.isArray(value)) throw new HttpError(400, "invalid_slots");
  return value.slice(0, MAX_FRAME_SLOTS).map((slot) => {
    const item = slot && typeof slot === "object" ? slot as Record<string, unknown> : {};
    const x = Number(item.x);
    const y = Number(item.y);
    const width = Number(item.width);
    const height = Number(item.height);
    if (![x, y, width, height].every(Number.isFinite) || width <= 0 || height <= 0 || x < 0 || y < 0 || x + width > 1.01 || y + height > 1.01) {
      throw new HttpError(400, "invalid_slots");
    }
    const rect = {
      x: Math.max(0, Math.min(1, x)),
      y: Math.max(0, Math.min(1, y)),
      width: Math.max(0, Math.min(1, width)),
      height: Math.max(0, Math.min(1, height)),
    };
    // Which card/strip of the frame this slot belongs to, set by the admin; absent on older frames.
    const group = Number(item.group);
    return Number.isInteger(group) && group >= 0 && group < MAX_FRAME_SLOTS ? { ...rect, group } : rect;
  });
}

function positiveDimension(v: unknown, code: string): number {
  const value = Number(v);
  if (!Number.isInteger(value) || value <= 0 || value > 20000) throw new HttpError(400, code);
  return value;
}

async function frameRowToJson(env: Env, origin: string, row: Record<string, string | number>) {
  const slots = (() => {
    try { return JSON.parse(String(row.slots_json || "[]")); } catch { return []; }
  })();
  // Same lifetime as the photo links: the guest may edit for a while before rendering the print.
  const imageUrl = await signedMediaUrl(env, origin, String(row.object_key), GALLERY_URL_TTL_SECONDS);
  // Screens show the small preview; the full PNG is only fetched to render the print.
  const previewUrl = row.preview_object_key ? await signedMediaUrl(env, origin, String(row.preview_object_key), GALLERY_URL_TTL_SECONDS) : imageUrl;
  // Grids (the guest's frame picker) show the thumbnail; until it exists, the preview.
  const thumbUrl = row.thumb_object_key ? await signedMediaUrl(env, origin, String(row.thumb_object_key), GALLERY_URL_TTL_SECONDS) : previewUrl;
  return {
    id: String(row.id),
    frame_id: String(row.id),
    name: String(row.name),
    width: Number(row.width || 0),
    height: Number(row.height || 0),
    slot_count: Number(row.slot_count || 0),
    slots,
    status: String(row.status || "active"),
    size_bytes: Number(row.size_bytes || 0),
    created_at: String(row.created_at || ""),
    updated_at: String(row.updated_at || ""),
    image_url: imageUrl,
    has_preview: Boolean(row.preview_object_key),
    has_thumbnail: Boolean(row.thumb_object_key),
    thumbnail_url: thumbUrl,
    preview_url: previewUrl,
  };
}

const MAX_FRAME_PREVIEW_BYTES = 3 * 1024 * 1024;

/**
 * PUT /v1/web/frames/:id/preview — body: the small PNG/WebP preview the admin page rendered.
 * With ?kind=thumb it is the frame's grid thumbnail instead.
 */
export async function handleWebFramePreview(req: Request, env: Env, url: URL, frameId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(frameId, 8, 64)) throw new HttpError(400, "invalid_frame_id");
  const thumb = url.searchParams.get("kind") === "thumb";
  const column = thumb ? "thumb_object_key" : "preview_object_key";
  const current = await env.DB.prepare(
    `SELECT ${column} AS object_key FROM studio_frames WHERE id = ? AND studio_id = ?`)
    .bind(frameId, caller.studioId).first<{ object_key: string | null }>();
  if (!current) throw new HttpError(404, "frame_not_found");
  const contentType = (req.headers.get("content-type") ?? "").split(";")[0].trim().toLowerCase();
  if (contentType !== "image/png" && contentType !== "image/webp") throw new HttpError(400, "preview_type_invalid");
  const bytes = await req.arrayBuffer();
  if (bytes.byteLength === 0 || bytes.byteLength > MAX_FRAME_PREVIEW_BYTES) throw new HttpError(400, "preview_size_invalid");

  // New key per upload so cached old previews are never shown.
  const key = `${FRAME_STORAGE_ROOT}/${caller.studioId}/${frameId}-${thumb ? "thumb" : "preview"}-${Date.now()}.${contentType === "image/webp" ? "webp" : "png"}`;
  await env.MEDIA.put(key, bytes, { httpMetadata: { contentType } });
  await env.DB.prepare(`UPDATE studio_frames SET ${column} = ?, updated_at = ? WHERE id = ? AND studio_id = ?`)
    .bind(key, nowIso(), frameId, caller.studioId).run();
  if (current.object_key) await env.MEDIA.delete(current.object_key);
  const row = await env.DB.prepare(
    `SELECT id, name, object_key, preview_object_key, thumb_object_key, size_bytes, width, height, slots_json, slot_count, status, created_at, updated_at
       FROM studio_frames WHERE id = ? AND studio_id = ?`)
    .bind(frameId, caller.studioId).first<Record<string, string | number>>();
  return json({ success: true, frame: await frameRowToJson(env, url.origin, row!) });
}

/** Active frames of one studio; shared by the admin and the public gallery. */
export async function listStudioFrames(env: Env, origin: string, studioId: string) {
  const rows = await env.DB.prepare(
    `SELECT id, name, object_key, preview_object_key, thumb_object_key, size_bytes, width, height, slots_json, slot_count, status, created_at, updated_at
       FROM studio_frames
      WHERE studio_id = ? AND status = 'active'
      ORDER BY created_at DESC`)
    .bind(studioId).all<Record<string, string | number>>();
  return Promise.all((rows.results ?? []).map((row) => frameRowToJson(env, origin, row)));
}

export async function handleWebFrames(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "GET") {
    const frames = await listStudioFrames(env, url.origin, caller.studioId);
    return json({ success: true, frames }, 200, { "cache-control": "no-store" });
  }

  const form = await req.formData();
  const file = form.get("file");
  if (!(file instanceof File)) throw new HttpError(400, "frame_file_required", "Chọn file PNG frame");
  if (file.type !== "image/png") throw new HttpError(400, "frame_must_be_png", "Frame phải là PNG trong suốt");
  if (file.size <= 0 || file.size > MAX_FRAME_SIZE_BYTES) throw new HttpError(400, "frame_size_invalid");
  const name = str(form.get("name"), 120) || file.name.replace(/\.png$/i, "") || "Frame";
  const width = positiveDimension(form.get("width"), "invalid_frame_width");
  const height = positiveDimension(form.get("height"), "invalid_frame_height");
  const slots = parseFrameSlots(form.get("slots"));
  if (slots.length === 0) throw new HttpError(400, "frame_slots_required", "Không tìm thấy vùng đục lỗ trong frame");

  const id = newId();
  const objectKey = frameObjectKey(caller.studioId, id);
  const bytes = await file.arrayBuffer();
  await env.MEDIA.put(objectKey, bytes, {
    httpMetadata: { contentType: "image/png" },
    customMetadata: { studio_id: caller.studioId, frame_id: id },
  });
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_frames (id, studio_id, name, object_key, content_type, size_bytes, width, height,
                                slots_json, slot_count, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'image/png', ?, ?, ?, ?, ?, 'active', ?, ?)`)
    .bind(id, caller.studioId, name, objectKey, file.size, width, height, JSON.stringify(slots), slots.length, now, now).run();
  const row = await env.DB.prepare(
    `SELECT id, name, object_key, preview_object_key, thumb_object_key, size_bytes, width, height, slots_json, slot_count, status, created_at, updated_at
       FROM studio_frames WHERE id = ? AND studio_id = ?`)
    .bind(id, caller.studioId).first<Record<string, string | number>>();
  return json({ success: true, frame: await frameRowToJson(env, url.origin, row!) }, 201);
}

export async function handleWebFrameDetail(req: Request, env: Env, url: URL, frameId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(frameId, 8, 64)) throw new HttpError(400, "invalid_frame_id");
  const current = await env.DB.prepare(
    "SELECT object_key, preview_object_key, thumb_object_key FROM studio_frames WHERE id = ? AND studio_id = ?")
    .bind(frameId, caller.studioId).first<{ object_key: string; preview_object_key: string | null; thumb_object_key: string | null }>();
  if (!current) throw new HttpError(404, "frame_not_found");

  if (req.method === "DELETE") {
    await env.MEDIA.delete([current.object_key, current.preview_object_key, current.thumb_object_key].filter((key): key is string => Boolean(key)));
    await env.DB.prepare("DELETE FROM studio_frames WHERE id = ? AND studio_id = ?")
      .bind(frameId, caller.studioId).run();
    return json({ success: true });
  }

  const b = await readJson(req);
  const name = str(b.name, 120);
  const slots = b.slots === undefined ? null : parseFrameSlots(b.slots);
  const width = b.width === undefined ? null : positiveDimension(b.width, "invalid_frame_width");
  const height = b.height === undefined ? null : positiveDimension(b.height, "invalid_frame_height");
  const now = nowIso();
  await env.DB.prepare(
    `UPDATE studio_frames
        SET name = CASE WHEN ? <> '' THEN ? ELSE name END,
            width = COALESCE(?, width),
            height = COALESCE(?, height),
            slots_json = COALESCE(?, slots_json),
            slot_count = COALESCE(?, slot_count),
            updated_at = ?
      WHERE id = ? AND studio_id = ?`)
    .bind(name, name, width, height, slots ? JSON.stringify(slots) : null, slots ? slots.length : null, now, frameId, caller.studioId).run();
  const row = await env.DB.prepare(
    `SELECT id, name, object_key, preview_object_key, thumb_object_key, size_bytes, width, height, slots_json, slot_count, status, created_at, updated_at
       FROM studio_frames WHERE id = ? AND studio_id = ?`)
    .bind(frameId, caller.studioId).first<Record<string, string | number>>();
  return json({ success: true, frame: await frameRowToJson(env, url.origin, row!) });
}

export async function handleWebFramesBulkDelete(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const b = await readJson(req);
  const ids = Array.isArray(b.ids) ? b.ids.map((v) => str(v, 64)).filter((id) => isSafeId(id, 8, 64)).slice(0, 100) : [];
  if (ids.length === 0) throw new HttpError(400, "frame_ids_required");
  const placeholders = ids.map(() => "?").join(",");
  const rows = await env.DB.prepare(
    `SELECT id, object_key, preview_object_key, thumb_object_key FROM studio_frames WHERE studio_id = ? AND id IN (${placeholders})`)
    .bind(caller.studioId, ...ids).all<{ id: string; object_key: string; preview_object_key: string | null; thumb_object_key: string | null }>();
  await Promise.all((rows.results ?? []).map((row) => env.MEDIA.delete(
    [row.object_key, row.preview_object_key, row.thumb_object_key].filter((key): key is string => Boolean(key)))));
  await env.DB.prepare(
    `DELETE FROM studio_frames WHERE studio_id = ? AND id IN (${placeholders})`)
    .bind(caller.studioId, ...ids).run();
  return json({ success: true, deleted: rows.results?.length ?? 0 });
}

export async function handleWebCaptureSessions(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const limit = Math.min(100, Math.max(10, int(Number(url.searchParams.get("limit") ?? 50), 50)));
  const cursor = decodeCursor(url.searchParams.get("cursor"));
  const machineId = str(url.searchParams.get("machine_id"), 64);
  const from = str(url.searchParams.get("from"), 40);
  const to = str(url.searchParams.get("to"), 40);

  const where = ["cs.studio_id = ?"];
  const bind: Array<string | number> = [caller.studioId];
  if (machineId) {
    if (!isSafeId(machineId, 8, 64)) throw new HttpError(400, "invalid_machine_id");
    where.push("cs.machine_id = ?");
    bind.push(machineId);
  }
  if (from) {
    where.push("COALESCE(cs.started_at, cs.created_at) >= ?");
    bind.push(from);
  }
  if (to) {
    where.push("COALESCE(cs.started_at, cs.created_at) <= ?");
    bind.push(to);
  }
  if (cursor) {
    where.push("COALESCE(cs.started_at, cs.created_at) < ?");
    bind.push(cursor);
  }

  const rows = await env.DB.prepare(
    `SELECT cs.machine_id, cs.session_id, cs.gallery_token, cs.event_id, cs.operation_mode, cs.status,
            cs.photos_count, cs.expected_photos, cs.asset_sync_status, cs.started_at, cs.ended_at, cs.created_at, cs.updated_at,
            m.hwid, COALESCE(NULLIF(m.display_name, ''), m.device_name) AS device_name,
            COUNT(DISTINCT CASE WHEN sa.status = 'committed' THEN sa.asset_id END) AS received_assets,
            MAX(sa.committed_at) AS last_asset_at,
            (
              SELECT COALESCE(t.object_key, first_asset.object_key)
                FROM session_assets first_asset
                LEFT JOIN session_assets t
                  ON t.machine_id = first_asset.machine_id
                 AND t.session_id = first_asset.session_id
                 AND t.photo_index = first_asset.photo_index
                 AND t.kind = 'thumbnail'
                 AND t.status = 'committed'
               WHERE first_asset.studio_id = cs.studio_id
                 AND first_asset.machine_id = cs.machine_id
                 AND first_asset.session_id = cs.session_id
                 AND first_asset.status = 'committed'
                 AND first_asset.kind IN ('photo','collage','video','other')
               ORDER BY first_asset.photo_index ASC, first_asset.committed_at ASC, first_asset.asset_id ASC
               LIMIT 1
            ) AS thumbnail_object_key
       FROM capture_sessions cs
       JOIN machines m ON m.id = cs.machine_id
       LEFT JOIN session_assets sa
         ON sa.machine_id = cs.machine_id AND sa.session_id = cs.session_id
      WHERE ${where.join(" AND ")}
      GROUP BY cs.machine_id, cs.session_id
      ORDER BY COALESCE(cs.started_at, cs.created_at) DESC
      LIMIT ?`)
    .bind(...bind, limit + 1).all<Record<string, string | number>>();

  const results = rows.results ?? [];
  const page = await Promise.all(results.slice(0, limit).map(async (row) => {
    const received = Number(row.received_assets || 0);
    const thumbnailKey = String(row.thumbnail_object_key || "");
    return {
      ...row,
      received_assets: received,
      thumbnail_url: thumbnailKey ? await signedMediaUrl(env, url.origin, thumbnailKey, 600) : "",
    };
  }));
  const last = page[page.length - 1];
  const nextCursor = results.length > limit && last
    ? encodeCursor(String(last.started_at || last.created_at || ""))
    : null;
  return json({ success: true, sessions: page, next_cursor: nextCursor }, 200, { "cache-control": "no-store" });
}

export async function handleWebCaptureAssets(req: Request, env: Env, url: URL, machineId: string, sessionId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(machineId, 8, 64)) throw new HttpError(400, "invalid_machine_id");
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const own = await env.DB.prepare(
    `SELECT cs.studio_id, s.name AS studio_name
       FROM capture_sessions cs
       JOIN studios s ON s.id = cs.studio_id
      WHERE cs.studio_id = ? AND cs.machine_id = ? AND cs.session_id = ?`)
    .bind(caller.studioId, machineId, sessionId).first<{ studio_id: string; studio_name: string }>();
  if (!own) throw new HttpError(404, "session_not_found");
  return json(await listSessionAssets(env, url, own, machineId, sessionId), 200, { "cache-control": "no-store" });
}

/** Gallery links stay valid this long (2–3 h after signedMediaUrl rounds up to the hour). */
const GALLERY_URL_TTL_SECONDS = 2 * 3600;

/** Which session assets the gallery lists: photos, collages, videos, never the JSON manifest. */
const LISTED_ASSETS = `a.status = 'committed'
        AND a.kind IN ('photo','collage','video','other')
        AND LOWER(COALESCE(a.content_type, '')) NOT LIKE '%json%'
        AND LOWER(COALESCE(a.file_name, '')) NOT LIKE '%.json'`;

/**
 * One page of committed photos for a capture session (signed URLs), plus the totals over
 * every page so a viewer can tell how many there are without loading them all.
 */
export async function listSessionAssets(
  env: Env,
  url: URL,
  own: { studio_id: string; studio_name: string },
  machineId: string,
  sessionId: string,
) {
  const limit = Math.min(100, Math.max(20, int(Number(url.searchParams.get("limit") ?? 80), 80)));
  const cursor = Math.max(0, int(Number(url.searchParams.get("cursor") ?? 0), 0));
  const totals = env.DB.prepare(
    `SELECT COALESCE(SUM(CASE WHEN a.kind = 'photo' THEN 1 ELSE 0 END), 0) AS photos, COUNT(*) AS items
       FROM session_assets a
      WHERE a.studio_id = ? AND a.machine_id = ? AND a.session_id = ? AND ${LISTED_ASSETS}`)
    .bind(own.studio_id, machineId, sessionId).first<{ photos: number; items: number }>();
  const rows = await env.DB.prepare(
    `SELECT a.asset_id, a.object_key, a.kind, a.file_name, a.content_type, a.size_bytes, a.checksum_sha256,
            a.photo_index, a.committed_at,
            CASE WHEN t.object_key IS NULL THEN 0 ELSE 1 END AS has_thumbnail,
            COALESCE(t.object_key, a.object_key) AS thumbnail_object_key,
            COALESCE(p.object_key, t.object_key, a.object_key) AS preview_object_key
       FROM session_assets a
       -- Display copies belong to one photo by id: "thumb-<photo asset_id>" (booth or the
       -- first guest browser) and "prev-<photo asset_id>" (booth). Never matched by
       -- photo_index, which a retake or a second copy can share.
       LEFT JOIN session_assets t
         ON t.machine_id = a.machine_id AND t.session_id = a.session_id
        AND t.asset_id = 'thumb-' || a.asset_id AND t.status = 'committed'
       LEFT JOIN session_assets p
         ON p.machine_id = a.machine_id AND p.session_id = a.session_id
        AND p.asset_id = 'prev-' || a.asset_id AND p.status = 'committed'
      WHERE a.studio_id = ? AND a.machine_id = ? AND a.session_id = ? AND ${LISTED_ASSETS}
      ORDER BY a.photo_index ASC, a.committed_at ASC, a.asset_id ASC
      LIMIT ? OFFSET ?`)
    .bind(own.studio_id, machineId, sessionId, limit + 1, cursor).all<Record<string, string | number>>();
  const items = rows.results ?? [];
  const page = await Promise.all(items.slice(0, limit).map(async (row) => ({
    ...row,
    // False: thumbnail_url is the full photo; the guest page makes and stores a small one.
    has_thumbnail: Number(row.has_thumbnail) === 1,
    url: await signedMediaUrl(env, url.origin, String(row.object_key), GALLERY_URL_TTL_SECONDS),
    thumbnail_url: await signedMediaUrl(env, url.origin, String(row.thumbnail_object_key || row.object_key), GALLERY_URL_TTL_SECONDS),
    preview_url: await signedMediaUrl(env, url.origin, String(row.preview_object_key || row.object_key), GALLERY_URL_TTL_SECONDS),
  })));
  const total = await totals;
  return {
    success: true,
    studio: { id: own.studio_id, name: own.studio_name },
    assets: page,
    next_cursor: items.length > limit ? String(cursor + limit) : null,
    total_photos: Number(total?.photos ?? 0),
    total_items: Number(total?.items ?? 0),
  };
}

export async function handlePublicBookingOptions(env: Env, url: URL): Promise<Response> {
  const requestedStudio = str(url.searchParams.get("studio_id"), 64);
  let studioId = requestedStudio;
  if (!studioId) {
    const studio = await env.DB.prepare("SELECT id FROM studios WHERE status = 'active' ORDER BY created_at DESC LIMIT 1")
      .first<{ id: string }>();
    studioId = studio?.id ?? "";
  }
  if (!studioId || !isSafeId(studioId, 8, 64)) throw new HttpError(404, "studio_not_found");

  const rooms = await env.DB.prepare(
    `SELECT id, name, description, capacity
       FROM studio_rooms WHERE studio_id = ? AND status = 'active' ORDER BY created_at DESC`)
    .bind(studioId).all();
  const packages = await env.DB.prepare(
    `SELECT id, room_id, name, minutes, price_vnd, description
       FROM studio_packages WHERE studio_id = ? AND status = 'active' ORDER BY created_at DESC`)
    .bind(studioId).all();
  return json({
    success: true,
    studio_id: studioId,
    branding: await brandingFor(env, url.origin, studioId),
    settings: await settingsFor(env, studioId),
    today: new Date(Date.now() + 7 * 3600000).toISOString().slice(0, 10),
    rooms: rooms.results ?? [],
    packages: packages.results ?? [],
  }, 200, { "cache-control": "no-store" });
}
