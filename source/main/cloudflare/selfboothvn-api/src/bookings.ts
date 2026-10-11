// Studio bookings: guests pick room → package → day → free time on the public booking
// page; staff see and change them in the admin. Times are studio local time
// (Asia/Ho_Chi_Minh, UTC+7): a date "YYYY-MM-DD" plus minutes after midnight.
//
//   GET   /v1/public/booking/availability?studio_id&room_id&date   busy times of that room (no names)
//   POST  /v1/public/booking                                         { studio_id, room_id, package_id, date, start_minute, name, phone, note }
//   GET   /v1/web/bookings?from&to&status                            admin list
//   POST  /v1/web/bookings                                           admin creates (phone / walk-in)
//   PATCH /v1/web/bookings/:id                                       admin changes time, room, package, status, details
//   GET   /v1/web/booking-settings · PUT /v1/web/booking-settings

import { Env, HttpError, isSafeId, json, newId, nowIso, readJson, str } from "./http";
import { requireWebSession } from "./webAuth";
import { requireCustomer } from "./customers";

const NO_STORE = { "cache-control": "no-store" };
const TZ_OFFSET_MINUTES = 7 * 60;
const STATUSES = ["pending", "confirmed", "done", "cancelled"] as const;
type Status = typeof STATUSES[number];
/** Open bookings one phone number may hold at once from the public page. */
const MAX_OPEN_PER_PHONE = 3;

export type BookingSettings = {
  enabled: boolean;
  open_minute: number;
  close_minute: number;
  slot_minutes: number;
  days_ahead: number;
  notice: string;
};

const DEFAULT_SETTINGS: BookingSettings = { enabled: true, open_minute: 540, close_minute: 1260, slot_minutes: 30, days_ahead: 30, notice: "" };

/** Today's date and the current minute in studio local time. */
function localNow() {
  const shifted = new Date(Date.now() + TZ_OFFSET_MINUTES * 60000);
  return { date: shifted.toISOString().slice(0, 10), minute: shifted.getUTCHours() * 60 + shifted.getUTCMinutes() };
}

function addDays(date: string, days: number) {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

function isDate(v: string) {
  return /^\d{4}-\d{2}-\d{2}$/.test(v) && !Number.isNaN(Date.parse(`${v}T00:00:00Z`));
}

function minuteValue(v: unknown, code: string) {
  const n = Number(v);
  if (!Number.isInteger(n) || n < 0 || n > 1440) throw new HttpError(400, code);
  return n;
}

function bookingCode() {
  const alphabet = "ABCDEFGHJKMNPQRSTUVWXYZ23456789";
  const bytes = new Uint8Array(6);
  crypto.getRandomValues(bytes);
  return "BK" + [...bytes].map((b) => alphabet[b % alphabet.length]).join("");
}

export async function settingsFor(env: Env, studioId: string): Promise<BookingSettings> {
  const row = await env.DB.prepare(
    `SELECT enabled, open_minute, close_minute, slot_minutes, days_ahead, notice FROM studio_booking_settings WHERE studio_id = ?`)
    .bind(studioId).first<Record<string, number | string>>();
  if (!row) return { ...DEFAULT_SETTINGS };
  return {
    enabled: Number(row.enabled) === 1,
    open_minute: Number(row.open_minute),
    close_minute: Number(row.close_minute),
    slot_minutes: Number(row.slot_minutes),
    days_ahead: Number(row.days_ahead),
    notice: String(row.notice || ""),
  };
}

/** Times already taken in a room that day (cancelled bookings free their time). */
async function busyTimes(env: Env, studioId: string, roomId: string, date: string, exceptId = "") {
  const rows = await env.DB.prepare(
    `SELECT id, start_minute, end_minute FROM studio_bookings
      WHERE studio_id = ? AND room_id = ? AND booking_date = ? AND status <> 'cancelled' AND id <> ?
      ORDER BY start_minute`)
    .bind(studioId, roomId, date, exceptId).all<{ id: string; start_minute: number; end_minute: number }>();
  return (rows.results ?? []).map((r) => ({ start: Number(r.start_minute), end: Number(r.end_minute) }));
}

async function roomAndPackage(env: Env, studioId: string, roomId: string, packageId: string) {
  if (!isSafeId(roomId, 8, 64)) throw new HttpError(400, "invalid_room");
  const room = await env.DB.prepare("SELECT id, name FROM studio_rooms WHERE id = ? AND studio_id = ? AND status = 'active'")
    .bind(roomId, studioId).first<{ id: string; name: string }>();
  if (!room) throw new HttpError(404, "room_not_found", "Phòng không còn nhận lịch");
  if (!isSafeId(packageId, 8, 64)) throw new HttpError(400, "invalid_package");
  const pkg = await env.DB.prepare(
    "SELECT id, name, minutes, price_vnd, room_id FROM studio_packages WHERE id = ? AND studio_id = ? AND status = 'active'")
    .bind(packageId, studioId).first<{ id: string; name: string; minutes: number; price_vnd: number; room_id: string }>();
  if (!pkg) throw new HttpError(404, "package_not_found", "Gói chụp không còn");
  if (pkg.room_id !== room.id) throw new HttpError(400, "package_room_mismatch", "Gói này không thuộc phòng đã chọn");
  return { room, pkg };
}

function overlaps(busy: Array<{ start: number; end: number }>, start: number, end: number) {
  return busy.some((b) => start < b.end && b.start < end);
}

export async function studioForPublic(env: Env, raw: string | null) {
  let studioId = str(raw, 64);
  if (!studioId) {
    const studio = await env.DB.prepare("SELECT id FROM studios WHERE status = 'active' ORDER BY created_at DESC LIMIT 1")
      .first<{ id: string }>();
    studioId = studio?.id ?? "";
  }
  if (!studioId || !isSafeId(studioId, 8, 64)) throw new HttpError(404, "studio_not_found");
  const active = await env.DB.prepare("SELECT 1 FROM studios WHERE id = ? AND status = 'active'").bind(studioId).first();
  if (!active) throw new HttpError(404, "studio_not_found");
  return studioId;
}

export async function handlePublicAvailability(env: Env, url: URL): Promise<Response> {
  const studioId = await studioForPublic(env, url.searchParams.get("studio_id"));
  const roomId = str(url.searchParams.get("room_id"), 64);
  const date = str(url.searchParams.get("date"), 10);
  if (!isSafeId(roomId, 8, 64) || !isDate(date)) throw new HttpError(400, "invalid_query");
  const now = localNow();
  return json({
    success: true,
    date,
    busy: await busyTimes(env, studioId, roomId, date),
    // Lets the page grey out times already past today.
    now_minute: date === now.date ? now.minute : null,
  }, 200, NO_STORE);
}

export async function handlePublicBookingCreate(req: Request, env: Env): Promise<Response> {
  const customer = await requireCustomer(req, env);
  const b = await readJson(req);
  const studioId = await studioForPublic(env, str(b.studio_id, 64) || null);
  if (customer.studio_id !== studioId) throw new HttpError(403, "customer_studio_mismatch", "Tài khoản thuộc studio khác");
  const settings = await settingsFor(env, studioId);
  if (!settings.enabled) throw new HttpError(403, "booking_closed", "Studio tạm ngừng nhận lịch online");

  const { room, pkg } = await roomAndPackage(env, studioId, str(b.room_id, 64), str(b.package_id, 64));
  const date = str(b.date, 10);
  const start = minuteValue(b.start_minute, "invalid_time");
  const end = start + Number(pkg.minutes);
  const now = localNow();
  if (!isDate(date) || date < now.date || date > addDays(now.date, settings.days_ahead)) {
    throw new HttpError(400, "invalid_date", "Ngày này chưa mở đặt lịch");
  }
  if (date === now.date && start <= now.minute) throw new HttpError(400, "time_passed", "Giờ này đã qua");
  if (start < settings.open_minute || end > settings.close_minute || (start - settings.open_minute) % settings.slot_minutes !== 0) {
    throw new HttpError(400, "outside_hours", "Giờ này ngoài giờ mở cửa");
  }
  const name = customer.name;
  const phone = customer.phone;
  const note = str(b.note, 500);
  if (note.length < 2) throw new HttpError(400, "note_required", "Nhập ghi chú cho studio");

  const open = await env.DB.prepare(
    `SELECT COUNT(*) AS n FROM studio_bookings
      WHERE studio_id = ? AND customer_phone = ? AND status IN ('pending', 'confirmed') AND booking_date >= ?`)
    .bind(studioId, phone, now.date).first<{ n: number }>();
  if (Number(open?.n ?? 0) >= MAX_OPEN_PER_PHONE) {
    throw new HttpError(429, "too_many_bookings", "Số điện thoại này đã có nhiều lịch đang chờ. Liên hệ studio để đổi lịch.");
  }
  if (overlaps(await busyTimes(env, studioId, room.id, date), start, end)) {
    throw new HttpError(409, "slot_taken", "Giờ này vừa có người đặt, hãy chọn giờ khác");
  }

  const id = newId();
  const code = bookingCode();
  const stamp = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_bookings (id, studio_id, code, room_id, package_id, booking_date, start_minute, end_minute,
                                  customer_name, customer_phone, note, price_vnd, status, source, customer_id, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'pending', 'web', ?, ?, ?)`)
    .bind(id, studioId, code, room.id, pkg.id, date, start, end, name, phone, note, Number(pkg.price_vnd), customer.id, stamp, stamp).run();
  return json({
    success: true,
    booking: { code, date, start_minute: start, end_minute: end, room_name: room.name, package_name: pkg.name, price_vnd: Number(pkg.price_vnd), status: "pending" },
  }, 201, NO_STORE);
}

const ADMIN_COLUMNS = `b.id, b.code, b.room_id, b.package_id, b.booking_date, b.start_minute, b.end_minute,
  b.customer_name, b.customer_phone, b.note, b.price_vnd, b.status, b.source, b.created_at, b.updated_at,
  r.name AS room_name, p.name AS package_name, b.customer_id, b.code_id,
  pc.code AS play_code, pc.status AS play_code_status`;

async function adminBooking(env: Env, studioId: string, id: string) {
  return env.DB.prepare(
    `SELECT ${ADMIN_COLUMNS} FROM studio_bookings b
       LEFT JOIN studio_rooms r ON r.id = b.room_id
       LEFT JOIN studio_packages p ON p.id = b.package_id
       LEFT JOIN package_codes pc ON pc.id = b.code_id
      WHERE b.id = ? AND b.studio_id = ?`)
    .bind(id, studioId).first();
}

export async function handleWebBookings(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "POST") return createByStaff(req, env, caller.studioId);

  const now = localNow();
  const from = isDate(str(url.searchParams.get("from"), 10)) ? str(url.searchParams.get("from"), 10) : now.date;
  const to = isDate(str(url.searchParams.get("to"), 10)) ? str(url.searchParams.get("to"), 10) : addDays(from, 6);
  const status = str(url.searchParams.get("status"), 16);
  const rows = await env.DB.prepare(
    `SELECT ${ADMIN_COLUMNS} FROM studio_bookings b
       LEFT JOIN studio_rooms r ON r.id = b.room_id
       LEFT JOIN studio_packages p ON p.id = b.package_id
       LEFT JOIN package_codes pc ON pc.id = b.code_id
      WHERE b.studio_id = ? AND b.booking_date BETWEEN ? AND ? ${STATUSES.includes(status as Status) ? "AND b.status = ?" : ""}
      ORDER BY b.booking_date, b.start_minute
      LIMIT 500`)
    .bind(caller.studioId, from, to, ...(STATUSES.includes(status as Status) ? [status] : [])).all();
  const pending = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM studio_bookings WHERE studio_id = ? AND status = 'pending' AND booking_date >= ?")
    .bind(caller.studioId, now.date).first<{ n: number }>();
  return json({ success: true, from, to, today: now.date, pending: Number(pending?.n ?? 0), bookings: rows.results ?? [] }, 200, NO_STORE);
}

async function createByStaff(req: Request, env: Env, studioId: string): Promise<Response> {
  const b = await readJson(req);
  const { room, pkg } = await roomAndPackage(env, studioId, str(b.room_id, 64), str(b.package_id, 64));
  const date = str(b.date, 10);
  if (!isDate(date)) throw new HttpError(400, "invalid_date");
  const start = minuteValue(b.start_minute, "invalid_time");
  const end = Math.min(1440, start + Number(pkg.minutes));
  const name = str(b.name, 80) || "Khách tại quầy";
  const phone = str(b.phone, 20).replace(/[\s.-]/g, "");
  if (overlaps(await busyTimes(env, studioId, room.id, date), start, end)) {
    throw new HttpError(409, "slot_taken", "Phòng đã có lịch trong khung giờ này");
  }
  const id = newId();
  const stamp = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_bookings (id, studio_id, code, room_id, package_id, booking_date, start_minute, end_minute,
                                  customer_name, customer_phone, note, price_vnd, status, source, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'confirmed', 'admin', ?, ?)`)
    .bind(id, studioId, bookingCode(), room.id, pkg.id, date, start, end, name, phone, str(b.note, 500), Number(pkg.price_vnd), stamp, stamp).run();
  await syncPlayCode(env, studioId, id);
  return json({ success: true, booking: await adminBooking(env, studioId, id) }, 201, NO_STORE);
}

export async function handleWebBookingDetail(req: Request, env: Env, bookingId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!isSafeId(bookingId, 8, 64)) throw new HttpError(400, "invalid_booking_id");
  const current = await env.DB.prepare(
    "SELECT * FROM studio_bookings WHERE id = ? AND studio_id = ?")
    .bind(bookingId, caller.studioId).first<Record<string, string | number>>();
  if (!current) throw new HttpError(404, "booking_not_found");

  const b = await readJson(req);
  const status = b.status === undefined ? String(current.status) : str(b.status, 16);
  if (!STATUSES.includes(status as Status)) throw new HttpError(400, "invalid_status");
  const roomId = b.room_id === undefined ? String(current.room_id) : str(b.room_id, 64);
  const packageId = b.package_id === undefined ? String(current.package_id || "") : str(b.package_id, 64);
  const date = b.date === undefined ? String(current.booking_date) : str(b.date, 10);
  if (!isDate(date)) throw new HttpError(400, "invalid_date");
  const start = b.start_minute === undefined ? Number(current.start_minute) : minuteValue(b.start_minute, "invalid_time");

  // Moving the booking or changing the package re-reads the package length and checks the room is free.
  const { pkg } = await roomAndPackage(env, caller.studioId, roomId, packageId);
  const end = Math.min(1440, start + Number(pkg.minutes));
  if (status !== "cancelled" && overlaps(await busyTimes(env, caller.studioId, roomId, date, bookingId), start, end)) {
    throw new HttpError(409, "slot_taken", "Phòng đã có lịch khác trong khung giờ này");
  }
  const name = b.name === undefined ? String(current.customer_name) : str(b.name, 80);
  const phone = b.phone === undefined ? String(current.customer_phone) : str(b.phone, 20).replace(/[\s.-]/g, "");
  const note = b.note === undefined ? String(current.note || "") : str(b.note, 500);
  const price = packageId !== String(current.package_id || "") ? Number(pkg.price_vnd) : Number(current.price_vnd);

  await env.DB.prepare(
    `UPDATE studio_bookings
        SET status = ?, room_id = ?, package_id = ?, booking_date = ?, start_minute = ?, end_minute = ?,
            customer_name = ?, customer_phone = ?, note = ?, price_vnd = ?, updated_at = ?
      WHERE id = ? AND studio_id = ?`)
    .bind(status, roomId, packageId, date, start, end, name, phone, note, price, nowIso(), bookingId, caller.studioId).run();
  await syncPlayCode(env, caller.studioId, bookingId);
  return json({ success: true, booking: await adminBooking(env, caller.studioId, bookingId) }, 200, NO_STORE);
}

export async function handleWebBookingSettings(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (req.method === "PUT") {
    const b = await readJson(req);
    const open = minuteValue(b.open_minute, "invalid_open_time");
    const close = minuteValue(b.close_minute, "invalid_close_time");
    if (close <= open) throw new HttpError(400, "invalid_hours", "Giờ đóng cửa phải sau giờ mở cửa");
    const slot = Number(b.slot_minutes);
    if (![15, 30, 60].includes(slot)) throw new HttpError(400, "invalid_slot");
    const days = Number(b.days_ahead);
    if (!Number.isInteger(days) || days < 1 || days > 180) throw new HttpError(400, "invalid_days_ahead");
    await env.DB.prepare(
      `INSERT INTO studio_booking_settings (studio_id, enabled, open_minute, close_minute, slot_minutes, days_ahead, notice, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(studio_id) DO UPDATE SET enabled = excluded.enabled, open_minute = excluded.open_minute,
         close_minute = excluded.close_minute, slot_minutes = excluded.slot_minutes, days_ahead = excluded.days_ahead,
         notice = excluded.notice, updated_at = excluded.updated_at`)
      .bind(caller.studioId, b.enabled === false ? 0 : 1, open, close, slot, days, str(b.notice, 300), nowIso()).run();
  }
  return json({ success: true, studio_id: caller.studioId, settings: await settingsFor(env, caller.studioId) }, 200, NO_STORE);
}

/** A studio-local day (UTC+7) as the UTC ISO window package_codes.checkWindow compares against. */
function dayWindow(date: string) {
  return {
    from: new Date(`${date}T00:00:00+07:00`).toISOString(),
    until: new Date(`${date}T23:59:59.999+07:00`).toISOString(),
  };
}

/**
 * Keep the booking's 4-digit play code in step with its status. The code is the same
 * single-use package code the booth already redeems online (mode3), so the guest types it
 * at the machine and the server links the capture session back to this booking.
 *   confirmed / done → has a code, valid on the booking day only
 *   pending / cancelled → no usable code (an active one is revoked)
 */
async function syncPlayCode(env: Env, studioId: string, bookingId: string) {
  const booking = await env.DB.prepare(
    `SELECT b.id, b.code, b.status, b.booking_date, b.package_id, b.code_id, pc.status AS code_status
       FROM studio_bookings b LEFT JOIN package_codes pc ON pc.id = b.code_id
      WHERE b.id = ? AND b.studio_id = ?`)
    .bind(bookingId, studioId).first<{ id: string; code: string; status: string; booking_date: string; package_id: string; code_id: string | null; code_status: string | null }>();
  if (!booking) return;
  const window = dayWindow(booking.booking_date);

  if (booking.status === "pending" || booking.status === "cancelled") {
    if (booking.code_id && booking.code_status === "active") {
      await env.DB.batch([
        env.DB.prepare("UPDATE package_codes SET status = 'revoked' WHERE id = ? AND status = 'active'").bind(booking.code_id),
        env.DB.prepare("UPDATE studio_bookings SET code_id = NULL WHERE id = ?").bind(booking.id),
      ]);
    }
    return;
  }
  if (booking.code_id && booking.code_status === "active") {
    // Moved to another day: the code follows.
    await env.DB.prepare("UPDATE package_codes SET valid_from = ?, valid_until = ? WHERE id = ? AND status = 'active'")
      .bind(window.from, window.until, booking.code_id).run();
    return;
  }
  if (booking.code_id && booking.code_status === "used") return;

  const pkg = await env.DB.prepare("SELECT id, room_id, minutes, price_vnd FROM studio_packages WHERE id = ? AND studio_id = ?")
    .bind(booking.package_id, studioId).first<{ id: string; room_id: string; minutes: number; price_vnd: number }>();
  if (!pkg) return;
  for (let attempt = 0; attempt < 3; attempt++) {
    const active = await env.DB.prepare("SELECT code FROM package_codes WHERE studio_id = ? AND status = 'active'")
      .bind(studioId).all<{ code: string }>();
    const taken = new Set((active.results ?? []).map((row) => row.code));
    let code = "";
    for (let i = 0; i < 200 && !code; i++) {
      const n = new Uint32Array(1);
      crypto.getRandomValues(n);
      const candidate = String(n[0] % 10000).padStart(4, "0");
      if (!taken.has(candidate)) code = candidate;
    }
    if (!code) throw new HttpError(409, "no_free_code", "Studio đã dùng gần hết 10 000 mã 4 số");
    const codeId = newId();
    try {
      await env.DB.batch([
        env.DB.prepare(
          `INSERT INTO package_codes (id, studio_id, code, kind, minutes, price_vnd, valid_from, valid_until, note, created_at, room_id, package_id)
           VALUES (?, ?, ?, 'single', ?, ?, ?, ?, ?, ?, ?, ?)`)
          .bind(codeId, studioId, code, Number(pkg.minutes), Number(pkg.price_vnd), window.from, window.until,
            `Đặt lịch ${booking.code}`, nowIso(), pkg.room_id, pkg.id),
        env.DB.prepare("UPDATE studio_bookings SET code_id = ? WHERE id = ?").bind(codeId, booking.id),
      ]);
      return;
    } catch (err) {
      // Another request took the same 4 digits a moment ago (unique active index): pick again.
      if (attempt === 2) throw err;
    }
  }
}

