// Studio operations for the browser admin and public booking page.

import {
  Env, HttpError, int, isSafeId, json, newId, nowIso, readJson, str,
} from "./http";
import { isFourDigitCode } from "./codes";
import { requirePermission } from "./webAuth";
import { READ_FRAMES, READ_ROOMS_PACKAGES } from "./permissions";
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

/** Room description shown on the booking page: a short paragraph, line breaks kept. */
const ROOM_DESCRIPTION_MAX = 1000;
const ROOM_CAPACITY_MAX = 80;
/** Cover upload: the admin's original (kept) + the guest-facing copy their browser made. */
const MAX_ROOM_COVER_BYTES = 15 * 1024 * 1024;
const MAX_ROOM_COVER_DISPLAY_BYTES = 3 * 1024 * 1024;
const ROOM_COVER_TYPES: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };
/** Cover links stay valid a day: the booking page is opened from a QR and left open. */
const ROOM_COVER_URL_TTL_SECONDS = 24 * 3600;

const ROOM_COLUMNS = "id, name, description, capacity, status, cover_object_key, cover_display_key, cover_crop, created_at, updated_at";

type CoverCrop = { x: number; y: number; w: number; h: number };

/** {"x","y","w","h"} as fractions of the original, inside it; anything else → null. */
function parseCoverCrop(v: unknown): CoverCrop | null {
  let raw: unknown = v;
  if (typeof v === "string") {
    try { raw = JSON.parse(v); } catch { return null; }
  }
  if (!raw || typeof raw !== "object") return null;
  const r = raw as Record<string, unknown>;
  const n = (k: string) => Number(r[k]);
  const crop = { x: n("x"), y: n("y"), w: n("w"), h: n("h") };
  const ok = Object.values(crop).every((value) => Number.isFinite(value))
    && crop.w > 0 && crop.h > 0 && crop.x >= 0 && crop.y >= 0
    && crop.x + crop.w <= 1.0001 && crop.y + crop.h <= 1.0001;
  return ok ? crop : null;
}

/**
 * Room row → JSON. cover_url is the guest-facing copy (the original when no copy exists).
 * The admin also gets the untouched original + the saved framing, to reframe without re-uploading.
 */
export async function roomRowToJson(env: Env, origin: string, row: Record<string, unknown>) {
  const coverKey = String(row.cover_display_key || row.cover_object_key || "");
  const originalKey = String(row.cover_object_key || "");
  return {
    id: String(row.id),
    name: String(row.name ?? ""),
    description: String(row.description ?? ""),
    capacity: String(row.capacity ?? ""),
    status: String(row.status ?? "active"),
    created_at: String(row.created_at ?? ""),
    updated_at: String(row.updated_at ?? ""),
    cover_url: coverKey ? await signedMediaUrl(env, origin, coverKey, ROOM_COVER_URL_TTL_SECONDS) : "",
    cover_original_url: originalKey ? await signedMediaUrl(env, origin, originalKey, ROOM_COVER_URL_TTL_SECONDS) : "",
    cover_crop: parseCoverCrop(row.cover_crop),
  };
}

async function roomById(env: Env, studioId: string, roomId: string) {
  if (!isSafeId(roomId, 8, 64)) throw new HttpError(400, "invalid_room_id");
  const row = await env.DB.prepare(
    `SELECT ${ROOM_COLUMNS} FROM studio_rooms WHERE id = ? AND studio_id = ? AND status = 'active'`)
    .bind(roomId, studioId).first<Record<string, unknown>>();
  if (!row) throw new HttpError(404, "room_not_found", "Không tìm thấy phòng chụp");
  return row;
}

export async function handleWebRooms(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requirePermission(req, env, ...(req.method === "GET" ? READ_ROOMS_PACKAGES : ["rooms.create"]));
  if (req.method === "GET") {
    const rs = await env.DB.prepare(
      `SELECT ${ROOM_COLUMNS} FROM studio_rooms WHERE studio_id = ? AND status = 'active' ORDER BY created_at DESC`)
      .bind(caller.studioId).all<Record<string, unknown>>();
    const rooms = await Promise.all((rs.results ?? []).map((row) => roomRowToJson(env, url.origin, row)));
    return json({ success: true, rooms }, 200, { "cache-control": "no-store" });
  }

  const b = await readJson(req);
  const name = str(b.name, 100);
  if (!name) throw new HttpError(400, "room_name_required", "Nhập tên phòng chụp");
  const id = newId();
  const now = nowIso();
  const description = str(b.description, ROOM_DESCRIPTION_MAX);
  const capacity = str(b.capacity, ROOM_CAPACITY_MAX);
  await env.DB.prepare(
    `INSERT INTO studio_rooms (id, studio_id, name, description, capacity, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?)`)
    .bind(id, caller.studioId, name, description, capacity, now, now).run();
  return json({
    success: true,
    room: { id, name, description, capacity, status: "active", created_at: now, updated_at: now, cover_url: "" },
  }, 201);
}

/** PATCH /v1/web/rooms/:id — { name?, capacity?, description? } */
export async function handleWebRoomUpdate(req: Request, env: Env, url: URL, roomId: string): Promise<Response> {
  const caller = await requirePermission(req, env, "rooms.edit");
  const current = await roomById(env, caller.studioId, roomId);
  const b = await readJson(req);
  const name = b.name === undefined ? String(current.name) : str(b.name, 100);
  if (!name) throw new HttpError(400, "room_name_required", "Nhập tên phòng chụp");
  const capacity = b.capacity === undefined ? String(current.capacity ?? "") : str(b.capacity, ROOM_CAPACITY_MAX);
  const description = b.description === undefined ? String(current.description ?? "") : str(b.description, ROOM_DESCRIPTION_MAX);
  await env.DB.prepare(
    "UPDATE studio_rooms SET name = ?, capacity = ?, description = ?, updated_at = ? WHERE id = ? AND studio_id = ?")
    .bind(name, capacity, description, nowIso(), roomId, caller.studioId).run();
  return json({ success: true, room: await roomRowToJson(env, url.origin, await roomById(env, caller.studioId, roomId)) });
}

/**
 * PUT /v1/web/rooms/:id/cover — multipart:
 *   `file`    the original as the admin picked it, stored untouched (omit to reframe the current one)
 *   `display` the framed 3:2 copy guests load
 *   `crop`    JSON {"x","y","w","h"} — the framing, fractions of the original
 * DELETE removes the cover.
 */
export async function handleWebRoomCover(req: Request, env: Env, url: URL, roomId: string): Promise<Response> {
  const caller = await requirePermission(req, env, "rooms.edit");
  const current = await roomById(env, caller.studioId, roomId);
  const currentOriginal = current.cover_object_key ? String(current.cover_object_key) : "";
  const currentDisplay = current.cover_display_key ? String(current.cover_display_key) : "";

  if (req.method === "DELETE") {
    await env.DB.prepare(
      `UPDATE studio_rooms SET cover_object_key = NULL, cover_display_key = NULL, cover_crop = NULL, updated_at = ?
        WHERE id = ? AND studio_id = ?`)
      .bind(nowIso(), roomId, caller.studioId).run();
    const oldKeys = [currentOriginal, currentDisplay].filter(Boolean);
    if (oldKeys.length) await env.MEDIA.delete(oldKeys);
    return json({ success: true, room: await roomRowToJson(env, url.origin, await roomById(env, caller.studioId, roomId)) });
  }

  const form = await req.formData();
  const file = form.get("file");
  const display = form.get("display");
  const cropField = form.get("crop");
  const crop = cropField === null ? null : parseCoverCrop(String(cropField));
  if (cropField !== null && !crop) throw new HttpError(400, "cover_crop_invalid", "Khung ảnh bìa không hợp lệ");
  if (file !== null) {
    if (!(file instanceof File) || !ROOM_COVER_TYPES[file.type]) {
      throw new HttpError(400, "cover_type_invalid", "Ảnh phòng phải là JPG, PNG hoặc WebP");
    }
    if (file.size <= 0 || file.size > MAX_ROOM_COVER_BYTES) throw new HttpError(400, "cover_too_large", "Ảnh phòng tối đa 15MB");
  } else if (!currentOriginal || !(display instanceof File)) {
    // Reframing keeps the stored original, so there has to be one, and a new framed copy.
    throw new HttpError(400, "cover_file_required", "Chọn ảnh bìa cho phòng");
  }
  if (display !== null && (!(display instanceof File) || !ROOM_COVER_TYPES[display.type]
    || display.size <= 0 || display.size > MAX_ROOM_COVER_DISPLAY_BYTES)) {
    throw new HttpError(400, "cover_display_invalid", "Bản xem trước của ảnh phòng không hợp lệ");
  }

  const stamp = Date.now();
  let originalKey = currentOriginal;
  if (file instanceof File) {
    originalKey = `rooms/${caller.studioId}/${roomId}-cover-${stamp}.${ROOM_COVER_TYPES[file.type]}`;
    await env.MEDIA.put(originalKey, await file.arrayBuffer(), { httpMetadata: { contentType: file.type } });
  }
  let displayKey: string | null = null;
  if (display instanceof File) {
    displayKey = `rooms/${caller.studioId}/${roomId}-cover-${stamp}-display.${ROOM_COVER_TYPES[display.type]}`;
    await env.MEDIA.put(displayKey, await display.arrayBuffer(), { httpMetadata: { contentType: display.type } });
  }
  await env.DB.prepare(
    `UPDATE studio_rooms SET cover_object_key = ?, cover_display_key = ?, cover_crop = ?, updated_at = ?
      WHERE id = ? AND studio_id = ?`)
    .bind(originalKey, displayKey, crop ? JSON.stringify(crop) : null, nowIso(), roomId, caller.studioId).run();
  // Old files go once the row points at the new ones; a reframe keeps the original.
  const oldKeys = [currentOriginal !== originalKey ? currentOriginal : "", currentDisplay].filter(Boolean);
  if (oldKeys.length) await env.MEDIA.delete(oldKeys);
  return json({ success: true, room: await roomRowToJson(env, url.origin, await roomById(env, caller.studioId, roomId)) });
}

export async function handleWebPackages(req: Request, env: Env): Promise<Response> {
  const caller = await requirePermission(req, env, ...(req.method === "GET" ? READ_ROOMS_PACKAGES : ["packages.create"]));
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
  const caller = await requirePermission(req, env, req.method === "GET" ? "codes.view" : "codes.create");
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
  const caller = await requirePermission(req, env, "codes.revoke");
  if (!isSafeId(codeId, 8, 64)) throw new HttpError(400, "invalid_code_id");
  const res = await env.DB.prepare(
    "UPDATE package_codes SET status = 'revoked' WHERE id = ? AND studio_id = ? AND status = 'active'")
    .bind(codeId, caller.studioId).run();
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "code_not_active");
  return json({ success: true });
}

/** POST /v1/web/capture-sessions/:machine/:session/gallery-link — the guest album link (token made on first ask). */
export async function handleWebSessionGalleryLink(req: Request, env: Env, url: URL, machineId: string, sessionId: string): Promise<Response> {
  const caller = await requirePermission(req, env, "library.share");
  if (!isSafeId(machineId, 8, 64) || !isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const owner = await env.DB.prepare("SELECT studio_id FROM capture_sessions WHERE machine_id = ? AND session_id = ?")
    .bind(machineId, sessionId).first<{ studio_id: string }>();
  if (owner?.studio_id !== caller.studioId) throw new HttpError(404, "session_not_found");
  const token = await ensureGalleryToken(env, machineId, sessionId);
  return json({ success: true, token, url: `${url.origin}/gallery?t=${encodeURIComponent(token)}` }, 200, { "cache-control": "no-store" });
}

/** DELETE /v1/web/rooms/:id — archives the room and its packages (bookings and codes keep their names). */
export async function handleWebRoomDelete(req: Request, env: Env, roomId: string): Promise<Response> {
  const caller = await requirePermission(req, env, "rooms.delete");
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
  const caller = await requirePermission(req, env, "packages.delete");
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
  const caller = await requirePermission(req, env, "codes.delete");
  if (!isSafeId(codeId, 8, 64)) throw new HttpError(400, "invalid_code_id");
  const [res] = await softDeleteCodes(env, caller.studioId, [codeId]);
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "code_not_found");
  return json({ success: true });
}

/** POST /v1/web/codes/bulk-delete {ids} */
export async function handleWebCodesBulkDelete(req: Request, env: Env): Promise<Response> {
  const caller = await requirePermission(req, env, "codes.delete");
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
  const caller = await requirePermission(req, env, "revenue.view");
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
  const caller = await requirePermission(req, env, "frames.upload", "frames.edit");
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
  const caller = await requirePermission(req, env, ...(req.method === "GET" ? READ_FRAMES : ["frames.upload"]));
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
  const caller = await requirePermission(req, env, req.method === "DELETE" ? "frames.delete" : "frames.edit");
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
  const caller = await requirePermission(req, env, "frames.delete");
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

/**
 * Session time in Vietnam local time ("YYYY-MM-DDTHH:MM:SS"). The booth sends started_at
 * as local time without an offset; created_at (server, UTC) is the fallback.
 */
const SESSION_LOCAL_AT = "COALESCE(cs.started_at, strftime('%Y-%m-%dT%H:%M:%S', cs.created_at, '+7 hours'))";
const DAY_PATTERN = /^\d{4}-\d{2}-\d{2}$/;

/**
 * GET /v1/web/capture-sessions — the photo library: sessions that have at least one photo,
 * newest first. day_no is the session's number within its day (1 = first of the day, across
 * all the studio's machines), so it stays the same whatever the filter.
 *   ?limit=10..100  ?machine_id=  ?from=YYYY-MM-DD  ?to=YYYY-MM-DD  ?no=<day_no>  ?cursor=
 */
export async function handleWebCaptureSessions(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requirePermission(req, env, "library.view");
  const limit = Math.min(100, Math.max(10, int(Number(url.searchParams.get("limit") ?? 50), 50)));
  const cursor = decodeCursor(url.searchParams.get("cursor")).split("\n");
  const machineId = str(url.searchParams.get("machine_id"), 64);
  const from = str(url.searchParams.get("from"), 10);
  const to = str(url.searchParams.get("to"), 10);
  const dayNo = int(Number(url.searchParams.get("no") ?? 0), 0);
  if (machineId && !isSafeId(machineId, 8, 64)) throw new HttpError(400, "invalid_machine_id");
  if ((from && !DAY_PATTERN.test(from)) || (to && !DAY_PATTERN.test(to))) throw new HttpError(400, "invalid_date");

  // Days are numbered whole, so the date range can narrow the numbering itself.
  const dayWhere: string[] = [];
  const dayBind: string[] = [];
  if (from) { dayWhere.push(`substr(${SESSION_LOCAL_AT}, 1, 10) >= ?`); dayBind.push(from); }
  if (to) { dayWhere.push(`substr(${SESSION_LOCAL_AT}, 1, 10) <= ?`); dayBind.push(to); }

  const where: string[] = [];
  const bind: Array<string | number> = [];
  if (machineId) { where.push("n.machine_id = ?"); bind.push(machineId); }
  if (dayNo > 0) { where.push("n.day_no = ?"); bind.push(dayNo); }
  if (cursor[0]) {
    where.push("(n.local_at, n.machine_id, n.session_id) < (?, ?, ?)");
    bind.push(cursor[0], cursor[1] ?? "", cursor[2] ?? "");
  }

  const rows = await env.DB.prepare(
    `WITH photo_counts AS (
       -- Ảnh chụp của phiên; không đếm bản xem (thumbnail/preview), manifest, ảnh ghép.
       SELECT machine_id, session_id, COUNT(*) AS photos, MAX(committed_at) AS last_asset_at
         FROM session_assets
        WHERE studio_id = ? AND status = 'committed' AND kind = 'photo'
        GROUP BY machine_id, session_id
     ),
     numbered AS (
       SELECT cs.machine_id, cs.session_id, cs.studio_id, cs.gallery_token, cs.event_id, cs.operation_mode,
              cs.status, cs.photos_count, cs.expected_photos, cs.asset_sync_status, cs.started_at, cs.ended_at,
              cs.created_at, cs.updated_at, pc.photos, pc.last_asset_at,
              ${SESSION_LOCAL_AT} AS local_at,
              ROW_NUMBER() OVER (PARTITION BY substr(${SESSION_LOCAL_AT}, 1, 10)
                                 ORDER BY ${SESSION_LOCAL_AT}, cs.machine_id, cs.session_id) AS day_no
         FROM capture_sessions cs
         JOIN photo_counts pc ON pc.machine_id = cs.machine_id AND pc.session_id = cs.session_id
        WHERE cs.studio_id = ?${dayWhere.map((w) => ` AND ${w}`).join("")}
     )
     SELECT n.machine_id, n.session_id, n.gallery_token, n.event_id, n.operation_mode, n.status,
            n.photos_count, n.expected_photos, n.asset_sync_status, n.started_at, n.ended_at, n.created_at,
            n.updated_at, n.local_at, n.day_no, n.photos AS received_assets, n.last_asset_at,
            m.hwid, COALESCE(NULLIF(m.display_name, ''), m.device_name) AS device_name,
            (
              SELECT COALESCE(t.object_key, first_asset.object_key)
                FROM session_assets first_asset
                LEFT JOIN session_assets t
                  ON t.machine_id = first_asset.machine_id
                 AND t.session_id = first_asset.session_id
                 AND t.asset_id = 'thumb-' || first_asset.asset_id
                 AND t.status = 'committed'
               WHERE first_asset.studio_id = n.studio_id
                 AND first_asset.machine_id = n.machine_id
                 AND first_asset.session_id = n.session_id
                 AND first_asset.status = 'committed'
                 AND first_asset.kind = 'photo'
               ORDER BY first_asset.photo_index ASC, first_asset.committed_at ASC, first_asset.asset_id ASC
               LIMIT 1
            ) AS thumbnail_object_key
       FROM numbered n
       JOIN machines m ON m.id = n.machine_id
      ${where.length ? `WHERE ${where.join(" AND ")}` : ""}
      ORDER BY n.local_at DESC, n.machine_id DESC, n.session_id DESC
      LIMIT ?`)
    .bind(caller.studioId, caller.studioId, ...dayBind, ...bind, limit + 1).all<Record<string, string | number>>();

  const results = rows.results ?? [];
  const page = await Promise.all(results.slice(0, limit).map(async (row) => {
    const thumbnailKey = String(row.thumbnail_object_key || "");
    return {
      ...row,
      received_assets: Number(row.received_assets || 0),
      day_no: Number(row.day_no || 0),
      thumbnail_url: thumbnailKey ? await signedMediaUrl(env, url.origin, thumbnailKey, GALLERY_URL_TTL_SECONDS) : "",
    };
  }));
  const last = results.length > limit ? results[limit - 1] : null;
  const nextCursor = last
    ? encodeCursor([String(last.local_at), String(last.machine_id), String(last.session_id)].join("\n"))
    : null;
  return json({ success: true, sessions: page, next_cursor: nextCursor }, 200, { "cache-control": "no-store" });
}

export async function handleWebCaptureAssets(req: Request, env: Env, url: URL, machineId: string, sessionId: string): Promise<Response> {
  const caller = await requirePermission(req, env, "library.view");
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

  const roomRows = await env.DB.prepare(
    `SELECT ${ROOM_COLUMNS} FROM studio_rooms WHERE studio_id = ? AND status = 'active' ORDER BY created_at DESC`)
    .bind(studioId).all<Record<string, unknown>>();
  const rooms = { results: await Promise.all((roomRows.results ?? []).map(async (row) => {
    const room = await roomRowToJson(env, url.origin, row);
    return { id: room.id, name: room.name, description: room.description, capacity: room.capacity, cover_url: room.cover_url };
  })) };
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
