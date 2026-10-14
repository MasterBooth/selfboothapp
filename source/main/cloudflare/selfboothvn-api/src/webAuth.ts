// Browser admin authentication.
//
// Web sessions deliberately do not reuse desktop machine tokens. A browser
// proves identity with an HttpOnly cookie, and every data route scopes reads
// by the studio_id stored in that server-side session.

import {
  Env, HttpError, int, json, nowIso, randomToken, readJson, sha256Hex, str,
} from "./http";
import { burnPasswordCheck, hashPassword, verifyPassword } from "./password";
import { requireHuman } from "./turnstile";
import { ALL_PERMISSIONS, READ_MACHINES, parseStoredPermissions, permissionLabel } from "./permissions";

/**
 * One session cookie per door, so the owner (`/`) and a staff member (`/staff`) can both be
 * signed in on the same browser without pushing each other out. The two portals say which door
 * they are with `X-SB-Portal: owner | staff` and only ever see that door's session. Pages that
 * belong to neither (gallery / editor opened from the library) send no header and use whichever
 * session the browser has, the owner's first.
 */
const COOKIE_NAME = "sb_session";
const STAFF_COOKIE_NAME = "sb_staff_session";
const PORTAL_HEADER = "x-sb-portal";

type Portal = "owner" | "staff";

const PORTAL_COOKIES: Record<Portal, string> = {
  owner: COOKIE_NAME,
  staff: STAFF_COOKIE_NAME,
};

/** The requested sign-in door, or null for shared gallery/editor pages. */
function portalOf(req: Request): Portal | null {
  const portal = req.headers.get(PORTAL_HEADER);
  if (portal === null) return null;
  if (portal === "owner" || portal === "staff") return portal;
  throw new HttpError(400, "invalid_portal", "Cổng đăng nhập không hợp lệ");
}

function sessionCandidates(req: Request): Array<{ name: string; portal: Portal; token: string }> {
  const requested = portalOf(req);
  const portals: Portal[] = requested ? [requested] : ["owner", "staff"];
  return portals.map((portal) => {
    const name = PORTAL_COOKIES[portal];
    return { name, portal, token: cookieValue(req, name) };
  });
}

/** The session cookie this request carries (first door that has one), or "" + the door's name. */
function sessionTokenOf(req: Request): { name: string; token: string } {
  const candidates = sessionCandidates(req);
  for (const { name, token } of candidates) {
    if (token) return { name, token };
  }
  return { name: candidates[0].name, token: "" };
}

function cookieNameForRole(role: string): string {
  if (role === "owner" || role === "staff") return PORTAL_COOKIES[role];
  throw new HttpError(403, "unsupported_role");
}

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
  /** Staff only (owners sign in with their email). */
  username: string;
  displayName: string;
  /** Every permission for the owner; what the owner ticked for staff. */
  permissions: Set<string>;
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

function sessionCookie(req: Request, name: string, token: string, maxAge: number): string {
  const value = token ? encodeURIComponent(token) : "";
  const secure = new URL(req.url).protocol === "https:" ? "; Secure" : "";
  return `${name}=${value}; Path=/; HttpOnly${secure}; SameSite=Lax; Max-Age=${maxAge}`;
}

function authPayload(caller: WebCaller) {
  return {
    user: {
      id: caller.userId,
      // A staff account's email column is its internal login key, never shown.
      email: caller.role === "owner" ? caller.email : "",
      role: caller.role,
      username: caller.username,
      display_name: caller.displayName,
      permissions: [...caller.permissions],
    },
    studio: { id: caller.studioId, name: caller.studioName },
  };
}

function callerPermissions(role: string, stored: string | null | undefined): Set<string> {
  return role === "owner" ? new Set(ALL_PERMISSIONS) : parseStoredPermissions(stored);
}

export async function requireWebSession(req: Request, env: Env): Promise<WebCaller> {
  const now = nowIso();
  for (const { portal, token } of sessionCandidates(req)) {
    if (!token.startsWith("ws_")) continue;
    const tokenHash = await sha256Hex(token);
    const row = await env.DB.prepare(
      `SELECT ws.user_id, ws.studio_id, u.email, u.role, u.status AS user_status, u.deleted_at,
              u.username, u.display_name, u.permissions,
              s.name AS studio_name, s.status AS studio_status
         FROM web_sessions ws
         JOIN studio_users u ON u.id = ws.user_id
         JOIN studios s ON s.id = ws.studio_id
        WHERE ws.token_hash = ?
          AND u.role = ?
          AND ws.revoked_at IS NULL
          AND ws.expires_at > ?`)
      .bind(tokenHash, portal, now).first<Record<string, string>>();
    // A missing/revoked/expired/wrong-role owner cookie must not mask a valid staff cookie on
    // shared pages. Requests that explicitly select a portal have only one candidate.
    if (!row || row.deleted_at) continue;
    if (row.user_status !== "active") throw new HttpError(403, "user_disabled", "Tài khoản đã bị khóa");
    if (row.studio_status !== "active") throw new HttpError(403, "studio_suspended");
    return {
      userId: row.user_id,
      studioId: row.studio_id,
      email: row.email,
      role: row.role,
      studioName: row.studio_name,
      tokenHash,
      username: row.username || "",
      displayName: row.display_name || "",
      permissions: callerPermissions(row.role, row.permissions),
    };
  }
  throw new HttpError(401, "unauthorized");
}

/**
 * The signed-in caller, if they hold at least one of `anyOf`. The owner always passes.
 * Every /v1/web route goes through this (or requireOwner): hiding a button in the web
 * is only a convenience, this is the check.
 */
export async function requirePermission(req: Request, env: Env, ...anyOf: string[]): Promise<WebCaller> {
  const caller = await requireWebSession(req, env);
  if (anyOf.some((code) => caller.permissions.has(code))) return caller;
  throw new HttpError(403, "forbidden", `Bạn chưa được cấp quyền: ${permissionLabel(anyOf[0])}`);
}

/** Owner-only routes: staff management. */
export async function requireOwner(req: Request, env: Env): Promise<WebCaller> {
  const caller = await requireWebSession(req, env);
  if (caller.role !== "owner") throw new HttpError(403, "owner_only", "Chỉ chủ studio làm được việc này");
  return caller;
}

/** Login lockout keyed by the login key (owner email or staff internal key). Throws while locked. */
export async function checkLoginLock(env: Env, key: string): Promise<number> {
  const attempt = await env.DB.prepare("SELECT fail_count, locked_until FROM login_attempts WHERE email = ?")
    .bind(key).first<{ fail_count: number; locked_until: string | null }>();
  if (attempt?.locked_until && attempt.locked_until > nowIso()) {
    throw new HttpError(429, "login_locked", "Đăng nhập sai quá nhiều lần, thử lại sau 15 phút");
  }
  return int(attempt?.fail_count);
}

export async function recordLoginFailure(env: Env, key: string, previousFails: number) {
  const fails = previousFails + 1;
  const lockedUntil = fails >= MAX_LOGIN_FAILS
    ? new Date(Date.now() + LOCK_MINUTES * 60_000).toISOString() : null;
  await env.DB.prepare(
    `INSERT INTO login_attempts (email, fail_count, locked_until, updated_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(email) DO UPDATE SET fail_count = excluded.fail_count,
       locked_until = excluded.locked_until, updated_at = excluded.updated_at`)
    .bind(key, fails >= MAX_LOGIN_FAILS ? 0 : fails, lockedUntil, nowIso()).run();
}

type SessionUser = {
  id: string;
  studio_id: string;
  email: string;
  role: string;
  studio_name: string;
  username?: string | null;
  display_name?: string | null;
  permissions?: string | null;
};

/** Opens a browser session for a verified user, in the cookie of that user's door. */
export async function startWebSession(req: Request, env: Env, user: SessionUser, loginKey: string): Promise<Response> {
  const now = nowIso();
  const token = randomToken("ws_");
  const tokenHash = await sha256Hex(token);
  const expiresAt = new Date(Date.now() + SESSION_MAX_AGE * 1000).toISOString();
  await env.DB.batch([
    env.DB.prepare("DELETE FROM login_attempts WHERE email = ?").bind(loginKey),
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
      email: user.email,
      role: user.role,
      studioName: user.studio_name,
      tokenHash,
      username: user.username || "",
      displayName: user.display_name || "",
      permissions: callerPermissions(user.role, user.permissions),
    }),
  }, 200, {
    "set-cookie": sessionCookie(req, cookieNameForRole(user.role), token, SESSION_MAX_AGE),
    "cache-control": "no-store",
  });
}

/** Ends every browser session of a user (staff locked, deleted or given a new password). */
export async function revokeUserSessions(env: Env, userId: string, keepTokenHash = "") {
  await env.DB.prepare(
    "UPDATE web_sessions SET revoked_at = ? WHERE user_id = ? AND revoked_at IS NULL AND token_hash <> ?")
    .bind(nowIso(), userId, keepTokenHash).run();
}

export async function handleWebLogin(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const email = normalizeEmail(b.email);
  const password = typeof b.password === "string" ? b.password : "";
  if (!email || !password) throw new HttpError(400, "missing_credentials");
  await requireHuman(req, env, b.turnstile_token, "owner_login");

  const fails = await checkLoginLock(env, email);
  // Owners only: staff sign in at /staff (POST /v1/web/staff/login).
  const user = await env.DB.prepare(
    `SELECT u.id, u.studio_id, u.email, u.password_hash, u.role, u.status,
            s.name AS studio_name, s.status AS studio_status
       FROM studio_users u
       JOIN studios s ON s.id = u.studio_id
      WHERE u.email = ? AND u.role = 'owner'`)
    .bind(email).first<Record<string, string>>();

  const ok = user ? await verifyPassword(password, user.password_hash) : (await burnPasswordCheck(password), false);
  if (!ok || !user) {
    await recordLoginFailure(env, email, fails);
    throw new HttpError(401, "invalid_credentials", "Sai email hoặc mật khẩu");
  }
  if (user.status !== "active") throw new HttpError(403, "user_disabled");
  if (user.studio_status !== "active") throw new HttpError(403, "studio_suspended");
  return startWebSession(req, env, { id: user.id, studio_id: user.studio_id, email, role: user.role, studio_name: user.studio_name }, email);
}

export async function handleWebMe(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  return json({ success: true, ...authPayload(caller) }, 200, { "cache-control": "no-store" });
}

/** Signs out of the door the request came from; the other door's session stays. */
export async function handleWebLogout(req: Request, env: Env): Promise<Response> {
  const { name, token } = sessionTokenOf(req);
  if (token.startsWith("ws_")) {
    const tokenHash = await sha256Hex(token);
    await env.DB.prepare("UPDATE web_sessions SET revoked_at = ? WHERE token_hash = ? AND revoked_at IS NULL")
      .bind(nowIso(), tokenHash).run();
  }
  return json({ success: true }, 200, {
    "set-cookie": sessionCookie(req, name, "", 0),
    "cache-control": "no-store",
  });
}

/** POST /v1/web/auth/password { current, next } — anyone signed in changes their own password. */
export async function handleWebPasswordChange(req: Request, env: Env): Promise<Response> {
  const caller = await requireWebSession(req, env);
  const b = await readJson(req);
  const current = typeof b.current === "string" ? b.current : "";
  const next = typeof b.next === "string" ? b.next : "";
  if (next.length < 8) throw new HttpError(400, "password_too_short", "Mật khẩu mới tối thiểu 8 ký tự");
  if (next.length > 128) throw new HttpError(400, "password_too_long");
  const row = await env.DB.prepare("SELECT password_hash FROM studio_users WHERE id = ?")
    .bind(caller.userId).first<{ password_hash: string }>();
  if (!row || !await verifyPassword(current, row.password_hash)) {
    throw new HttpError(403, "wrong_password", "Mật khẩu hiện tại không đúng");
  }
  await env.DB.prepare("UPDATE studio_users SET password_hash = ?, updated_at = ? WHERE id = ?")
    .bind(await hashPassword(next), nowIso(), caller.userId).run();
  // Other devices still signed in with the old password are signed out; this one stays.
  await revokeUserSessions(env, caller.userId, caller.tokenHash);
  return json({ success: true }, 200, { "cache-control": "no-store" });
}

export async function handleWebMachines(req: Request, env: Env): Promise<Response> {
  const caller = await requirePermission(req, env, ...READ_MACHINES);
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
  const caller = await requirePermission(req, env, "devices.rename");
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
