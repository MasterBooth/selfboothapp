// Guest accounts for online booking. The studio chose phone-number-only sign-in, so the
// account is protected by short sessions (24 h) and a per-IP limit on failed attempts.
//
//   POST /v1/public/customers/register  { studio_id, name, phone }
//   POST /v1/public/customers/login     { studio_id, phone }
//   POST /v1/public/customers/logout
//   GET  /v1/public/customers/me        account + "Lịch của tôi" + "Ảnh của tôi"
//
// The same session unlocks the guest's own galleries after 24 h (see requireGalleryAccess).

import { Env, HttpError, json, newId, nowIso, randomToken, readJson, sha256Hex, str } from "./http";
import { cookieValue } from "./webAuth";
import { ensureGalleryToken, signedMediaUrl } from "./upload";
import { studioForPublic } from "./bookings";

const COOKIE = "bcs";
const SESSION_SECONDS = 24 * 3600;
/** Failed sign-ins (unknown phone) allowed per IP in the window. */
const MAX_FAILS = 8;
const FAIL_WINDOW_MINUTES = 15;
const NO_STORE = { "cache-control": "no-store" };

export type Customer = { id: string; studio_id: string; name: string; phone: string };

/** "0912 345 678", "+84 912…" → "0912345678". Throws on anything that is not a phone number. */
export function normalizePhone(v: unknown): string {
  let digits = str(v, 24).replace(/[^\d+]/g, "");
  if (digits.startsWith("+84")) digits = "0" + digits.slice(3);
  else if (digits.startsWith("84") && digits.length === 11) digits = "0" + digits.slice(2);
  digits = digits.replace(/\+/g, "");
  if (!/^\d{9,15}$/.test(digits)) throw new HttpError(400, "invalid_phone", "Số điện thoại không hợp lệ");
  return digits;
}

/** "0912345678" → "09•• ••• 678": enough to recognise one's own number, not to read it. */
export function maskPhone(phone: string): string {
  return phone.length < 6 ? "•••" : `${phone.slice(0, 2)}•• ••• ${phone.slice(-3)}`;
}

function cookie(req: Request, token: string, maxAge: number) {
  const secure = new URL(req.url).protocol === "https:" ? "; Secure" : "";
  return `${COOKIE}=${token ? encodeURIComponent(token) : ""}; Path=/; HttpOnly${secure}; SameSite=Lax; Max-Age=${maxAge}`;
}

function clientIp(req: Request) {
  return req.headers.get("cf-connecting-ip") || req.headers.get("x-forwarded-for")?.split(",")[0].trim() || "unknown";
}

/** Refuse when this IP has too many recent failures (phone numbers are guessable). */
export async function throttleCustomerAttempts(req: Request, env: Env) {
  const since = new Date(Date.now() - FAIL_WINDOW_MINUTES * 60000).toISOString();
  const row = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM customer_login_attempts WHERE ip = ? AND attempted_at > ?")
    .bind(clientIp(req), since).first<{ n: number }>();
  if (Number(row?.n ?? 0) >= MAX_FAILS) {
    throw new HttpError(429, "too_many_attempts", `Thử sai quá nhiều lần. Vui lòng thử lại sau ${FAIL_WINDOW_MINUTES} phút.`);
  }
}

export async function recordCustomerFailure(req: Request, env: Env) {
  await env.DB.prepare("INSERT INTO customer_login_attempts (ip, attempted_at) VALUES (?, ?)")
    .bind(clientIp(req), nowIso()).run();
}

/** Open a 24 h session for this customer; returns the Set-Cookie header value. */
export async function startCustomerSession(req: Request, env: Env, customer: Customer): Promise<string> {
  const token = randomToken("cs_");
  const now = new Date();
  await env.DB.batch([
    env.DB.prepare(
      `INSERT INTO customer_sessions (token_hash, customer_id, studio_id, created_at, expires_at) VALUES (?, ?, ?, ?, ?)`)
      .bind(await sha256Hex(token), customer.id, customer.studio_id, now.toISOString(), new Date(now.getTime() + SESSION_SECONDS * 1000).toISOString()),
    env.DB.prepare("UPDATE studio_customers SET last_login_at = ? WHERE id = ?").bind(now.toISOString(), customer.id),
    // Old sessions of this customer no longer matter.
    env.DB.prepare("DELETE FROM customer_sessions WHERE customer_id = ? AND expires_at < ?").bind(customer.id, now.toISOString()),
  ]);
  return cookie(req, token, SESSION_SECONDS);
}

/** The signed-in customer, or null (no cookie, unknown, or older than 24 h). */
export async function currentCustomer(req: Request, env: Env): Promise<Customer | null> {
  const token = cookieValue(req, COOKIE);
  if (!token.startsWith("cs_")) return null;
  const row = await env.DB.prepare(
    `SELECT c.id, c.studio_id, c.name, c.phone
       FROM customer_sessions s JOIN studio_customers c ON c.id = s.customer_id
      WHERE s.token_hash = ? AND s.expires_at > ?`)
    .bind(await sha256Hex(token), nowIso()).first<Customer>();
  return row ?? null;
}

export async function requireCustomer(req: Request, env: Env): Promise<Customer> {
  const customer = await currentCustomer(req, env);
  if (!customer) throw new HttpError(401, "customer_signin_required", "Vui lòng đăng nhập bằng số điện thoại");
  return customer;
}

function publicCustomer(c: Customer) {
  return { id: c.id, name: c.name, phone: c.phone, phone_masked: maskPhone(c.phone) };
}

export async function handleCustomerRegister(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const studioId = await studioForPublic(env, str(b.studio_id, 64) || null);
  const name = str(b.name, 80);
  if (name.length < 2) throw new HttpError(400, "invalid_name", "Nhập họ tên");
  const phone = normalizePhone(b.phone);
  await throttleCustomerAttempts(req, env);
  const existing = await env.DB.prepare("SELECT id FROM studio_customers WHERE studio_id = ? AND phone = ?")
    .bind(studioId, phone).first();
  if (existing) throw new HttpError(409, "phone_registered", "Số điện thoại này đã đăng ký, hãy đăng nhập");
  const customer: Customer = { id: newId(), studio_id: studioId, name, phone };
  await env.DB.prepare("INSERT INTO studio_customers (id, studio_id, name, phone, created_at) VALUES (?, ?, ?, ?, ?)")
    .bind(customer.id, studioId, name, phone, nowIso()).run();
  const setCookie = await startCustomerSession(req, env, customer);
  return json({ success: true, customer: publicCustomer(customer) }, 201, { ...NO_STORE, "set-cookie": setCookie });
}

export async function handleCustomerLogin(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const studioId = await studioForPublic(env, str(b.studio_id, 64) || null);
  const phone = normalizePhone(b.phone);
  await throttleCustomerAttempts(req, env);
  const customer = await env.DB.prepare("SELECT id, studio_id, name, phone FROM studio_customers WHERE studio_id = ? AND phone = ?")
    .bind(studioId, phone).first<Customer>();
  if (!customer) {
    await recordCustomerFailure(req, env);
    throw new HttpError(404, "customer_not_found", "Số điện thoại chưa đăng ký");
  }
  const setCookie = await startCustomerSession(req, env, customer);
  return json({ success: true, customer: publicCustomer(customer) }, 200, { ...NO_STORE, "set-cookie": setCookie });
}

export async function handleCustomerLogout(req: Request, env: Env): Promise<Response> {
  const token = cookieValue(req, COOKIE);
  if (token.startsWith("cs_")) {
    await env.DB.prepare("DELETE FROM customer_sessions WHERE token_hash = ?").bind(await sha256Hex(token)).run();
  }
  return json({ success: true }, 200, { ...NO_STORE, "set-cookie": cookie(req, "", 0) });
}

/** Account, bookings (with the 4-digit code once confirmed) and the galleries shot with them. */
export async function handleCustomerMe(req: Request, env: Env, url: URL): Promise<Response> {
  const customer = await requireCustomer(req, env);
  const bookings = await env.DB.prepare(
    `SELECT b.id, b.code, b.room_id, b.package_id, b.booking_date, b.start_minute, b.end_minute, b.note, b.price_vnd,
            b.status, b.created_at, r.name AS room_name, p.name AS package_name,
            pc.code AS play_code, pc.status AS play_code_status
       FROM studio_bookings b
       LEFT JOIN studio_rooms r ON r.id = b.room_id
       LEFT JOIN studio_packages p ON p.id = b.package_id
       LEFT JOIN package_codes pc ON pc.id = b.code_id
      WHERE b.customer_id = ? AND b.studio_id = ?
      ORDER BY b.booking_date DESC, b.start_minute DESC
      LIMIT 100`)
    .bind(customer.id, customer.studio_id).all<Record<string, string | number | null>>();

  const sessions = await env.DB.prepare(
    `SELECT cs.machine_id, cs.session_id, cs.gallery_token, cs.photos_count, cs.started_at, cs.created_at,
            b.booking_date, b.code AS booking_code, r.name AS room_name
       FROM studio_bookings b
       JOIN package_codes pc ON pc.id = b.code_id
       JOIN capture_sessions cs ON cs.machine_id = pc.used_machine_id AND cs.session_id = pc.used_session_id
       LEFT JOIN studio_rooms r ON r.id = b.room_id
      WHERE b.customer_id = ? AND b.studio_id = ?
      ORDER BY cs.created_at DESC
      LIMIT 50`)
    .bind(customer.id, customer.studio_id).all<Record<string, string | number | null>>();

  const galleries = await Promise.all((sessions.results ?? []).map(async (s) => {
    const token = String(s.gallery_token || "") || await ensureGalleryToken(env, String(s.machine_id), String(s.session_id));
    const cover = await env.DB.prepare(
      `SELECT COALESCE(t.object_key, a.object_key) AS object_key
         FROM session_assets a
         LEFT JOIN session_assets t ON t.machine_id = a.machine_id AND t.session_id = a.session_id
          AND t.photo_index = a.photo_index AND t.kind = 'thumbnail' AND t.status = 'committed'
        WHERE a.machine_id = ? AND a.session_id = ? AND a.kind = 'photo' AND a.status = 'committed'
        ORDER BY a.photo_index LIMIT 1`)
      .bind(s.machine_id, s.session_id).first<{ object_key: string }>();
    return {
      token,
      photos_count: Number(s.photos_count || 0),
      shot_at: String(s.started_at || s.created_at || ""),
      booking_code: String(s.booking_code || ""),
      booking_date: String(s.booking_date || ""),
      room_name: String(s.room_name || ""),
      cover_url: cover?.object_key ? await signedMediaUrl(env, url.origin, cover.object_key, 3600) : "",
    };
  }));

  return json({
    success: true,
    customer: publicCustomer(customer),
    bookings: (bookings.results ?? []).map((b) => ({
      ...b,
      // The code is only handed out once staff have confirmed the booking.
      play_code: b.status === "confirmed" || b.status === "done" ? b.play_code : null,
    })),
    galleries,
  }, 200, NO_STORE);
}
