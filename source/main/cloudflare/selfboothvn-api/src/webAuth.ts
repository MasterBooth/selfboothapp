// Browser admin authentication.
//
// Web sessions deliberately do not reuse desktop machine tokens. A browser
// proves identity with an HttpOnly cookie, and every data route scopes reads
// by the studio_id stored in that server-side session.

import {
  Env, HttpError, int, json, nowIso, randomToken, readJson, sha256Hex, str,
} from "./http";
import { burnPasswordCheck, verifyPassword } from "./password";

const COOKIE_NAME = "sb_session";
const SESSION_DAYS = 7;
const SESSION_MAX_AGE = SESSION_DAYS * 24 * 60 * 60;
const MAX_LOGIN_FAILS = 10;
const LOCK_MINUTES = 15;

export interface WebCaller {
  userId: string;
  studioId: string;
  email: string;
  role: string;
  studioName: string;
  tokenHash: string;
}

function normalizeEmail(v: unknown): string {
  return str(v, 254).toLowerCase();
}

export function cookieValue(req: Request, name: string): string {
  const header = req.headers.get("cookie") ?? "";
  const parts = header.split(";");
  for (const part of parts) {
    const [rawKey, ...rawValue] = part.trim().split("=");
    if (rawKey === name) return decodeURIComponent(rawValue.join("="));
  }
  return "";
}

function sessionCookie(req: Request, token: string, maxAge: number): string {
  const value = token ? encodeURIComponent(token) : "";
  const secure = new URL(req.url).protocol === "https:" ? "; Secure" : "";
  return `${COOKIE_NAME}=${value}; Path=/; HttpOnly${secure}; SameSite=Lax; Max-Age=${maxAge}`;
}

function authPayload(caller: WebCaller) {
  return {
    user: { id: caller.userId, email: caller.email, role: caller.role },
    studio: { id: caller.studioId, name: caller.studioName },
  };
}

export async function requireWebSession(req: Request, env: Env): Promise<WebCaller> {
  const token = cookieValue(req, COOKIE_NAME);
  if (!token.startsWith("ws_")) throw new HttpError(401, "unauthorized");
  const tokenHash = await sha256Hex(token);
  const now = nowIso();
  const row = await env.DB.prepare(
    `SELECT ws.user_id, ws.studio_id, u.email, u.role, u.status AS user_status,
            s.name AS studio_name, s.status AS studio_status
       FROM web_sessions ws
       JOIN studio_users u ON u.id = ws.user_id
       JOIN studios s ON s.id = ws.studio_id
      WHERE ws.token_hash = ?
        AND ws.revoked_at IS NULL
        AND ws.expires_at > ?`)
    .bind(tokenHash, now).first<Record<string, string>>();
  if (!row) throw new HttpError(401, "unauthorized");
  if (row.user_status !== "active") throw new HttpError(403, "user_disabled");
  if (row.studio_status !== "active") throw new HttpError(403, "studio_suspended");
  return {
    userId: row.user_id,
    studioId: row.studio_id,
    email: row.email,
    role: row.role,
    studioName: row.studio_name,
    tokenHash,
  };
}

export async function handleWebLogin(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const email = normalizeEmail(b.email);
  const password = typeof b.password === "string" ? b.password : "";
  if (!email || !password) throw new HttpError(400, "missing_credentials");

  const now = nowIso();
  const attempt = await env.DB.prepare("SELECT fail_count, locked_until FROM login_attempts WHERE email = ?")
    .bind(email).first<{ fail_count: number; locked_until: string | null }>();
  if (attempt?.locked_until && attempt.locked_until > now) {
    throw new HttpError(429, "login_locked", "Đăng nhập sai quá nhiều lần, thử lại sau 15 phút");
  }

  const user = await env.DB.prepare(
    `SELECT u.id, u.studio_id, u.password_hash, u.role, u.status,
            s.name AS studio_name, s.status AS studio_status
       FROM studio_users u
       JOIN studios s ON s.id = u.studio_id
      WHERE u.email = ?`)
    .bind(email).first<Record<string, string>>();

  const ok = user ? await verifyPassword(password, user.password_hash) : (await burnPasswordCheck(password), false);
  if (!ok || !user) {
    const fails = int(attempt?.fail_count) + 1;
    const lockedUntil = fails >= MAX_LOGIN_FAILS
      ? new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString() : null;
    await env.DB.prepare(
      `INSERT INTO login_attempts (email, fail_count, locked_until, updated_at) VALUES (?, ?, ?, ?)
       ON CONFLICT(email) DO UPDATE SET fail_count = excluded.fail_count,
         locked_until = excluded.locked_until, updated_at = excluded.updated_at`)
      .bind(email, fails >= MAX_LOGIN_FAILS ? 0 : fails, lockedUntil, now).run();
    throw new HttpError(401, "invalid_credentials", "Sai email hoặc mật khẩu");
  }
  if (user.status !== "active") throw new HttpError(403, "user_disabled");
  if (user.studio_status !== "active") throw new HttpError(403, "studio_suspended");

  const token = randomToken("ws_");
  const tokenHash = await sha256Hex(token);
  const expiresAt = new Date(Date.now() + SESSION_MAX_AGE * 1000).toISOString();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM login_attempts WHERE email = ?").bind(email),
    env.DB.prepare("UPDATE studio_users SET last_login_at = ? WHERE id = ?").bind(now, user.id),
    env.DB.prepare(
      "INSERT INTO web_sessions (token_hash, user_id, studio_id, created_at, expires_at) VALUES (?, ?, ?, ?, ?)")
      .bind(tokenHash, user.id, user.studio_id, now, expiresAt),
  ]);

  return json({
    success: true,
    ...authPayload({
      userId: user.id,
      studioId: user.studio_id,
      email,
      role: user.role,
      studioName: user.studio_name,
      tokenHash,
    }),
  }, 200, {
    "set-cookie": sessionCookie(req, token, SESSION_MAX_AGE),
    "cache-control": "no-store",
  });
}

export async function handleWebMe(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  return json({ success: true, ...authPayload(caller) }, 200, { "cache-control": "no-store" });
}

export async function handleWebLogout(req: Request, env: Env): Promise<Response> {
  const token = cookieValue(req, COOKIE_NAME);
  if (token.startsWith("ws_")) {
    const tokenHash = await sha256Hex(token);
    await env.DB.prepare("UPDATE web_sessions SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL")
      .bind(nowIso(), tokenHash).run();
  }
  return json({ success: true }, 200, {
    "set-cookie": sessionCookie(req, "", 0),
    "cache-control": "no-store",
  });
}

export async function handleWebMachines(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const rs = await env.DB.prepare(
    `SELECT id, hwid, device_name, display_name, app_version, status, first_seen_at, last_seen_at, linked_at
       FROM machines
      WHERE studio_id = ?
      ORDER BY last_seen_at DESC`)
    .bind(caller.studioId).all();
  return json({ success: true, machines: rs.results ?? [] }, 200, { "cache-control": "no-store" });
}

/**
 * PATCH /v1/web/machines/:id { display_name } — the studio's name for a machine.
 * Stored apart from device_name (the name in the app's config, re-sent on every login),
 * so a rename here is never undone by the machine. "" goes back to the config name.
 */
export async function handleWebMachineRename(req: Request, env: Env, machineId: string): Promise<Response> {
  const caller = await requireWebSession(req, env);
  if (!/^[A-Za-z0-9._-]{8,64}$/.test(machineId)) throw new HttpError(400, "invalid_machine_id");
  const b = await readJson(req);
  const name = str(b.display_name, 60);
  const res = await env.DB.prepare("UPDATE machines SET display_name = ? WHERE id = ? AND studio_id = ?")
    .bind(name, machineId, caller.studioId).run();
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "machine_not_found");
  const machine = await env.DB.prepare(
    `SELECT id, hwid, device_name, display_name, app_version, status, first_seen_at, last_seen_at, linked_at
       FROM machines WHERE id = ? AND studio_id = ?`)
    .bind(machineId, caller.studioId).first();
  return json({ success: true, machine }, 200, { "cache-control": "no-store" });
}
