// Xác thực + tài khoản studio + đăng ký máy.
//
// Ba loại Bearer token:
//   bootstrap  env.API_TOKEN          (legacy, không đóng gói trong desktop)
//   machine    token riêng từng máy    (cấp khi studio đăng nhập trên máy) — mọi route /v1/machine/*
//   admin      env.ADMIN_API_TOKEN     — /v1/admin/*
// Route máy lấy hwid/studio TỪ TOKEN, không tin giá trị client gửi trong body.

import {
  Env, HttpError, bearer, int, isSafeId, json, newId, nowIso, randomToken, readJson,
  sha256Hex, str, timingSafeEqual,
} from "./http";
import { burnPasswordCheck, hashPassword, verifyPassword } from "./password";

export interface MachineCaller {
  machineId: string;
  hwid: string;
  studioId: string;
  userId: string;
  tokenHash: string;
}

const MAX_LOGIN_FAILS = 10;
const LOCK_MINUTES = 15;
const AUTH_RATE_LIMIT_MAX = 30;
const AUTH_RATE_LIMIT_WINDOW_SECONDS = 15 * 60;

export function requireBootstrap(req: Request, env: Env): void {
  const token = (env.API_TOKEN ?? "").trim();
  if (!token || !timingSafeEqual(bearer(req), token)) throw new HttpError(401, "unauthorized");
}

export function requireAdmin(req: Request, env: Env): void {
  const token = (env.ADMIN_API_TOKEN ?? "").trim();
  if (!token || !timingSafeEqual(bearer(req), token)) throw new HttpError(401, "unauthorized");
}

export async function requireMachine(req: Request, env: Env): Promise<MachineCaller> {
  const token = bearer(req);
  if (!token.startsWith("mt_")) throw new HttpError(401, "unauthorized");
  const tokenHash = await sha256Hex(token);
  const row = await env.DB.prepare(
    `SELECT t.machine_id, t.studio_id, t.user_id, m.hwid, m.status AS machine_status,
            m.studio_id AS machine_studio, s.status AS studio_status
       FROM machine_tokens t
       JOIN machines m ON m.id = t.machine_id
       JOIN studios s  ON s.id = t.studio_id
      WHERE t.token_hash = ? AND t.revoked_at IS NULL`)
    .bind(tokenHash).first<Record<string, string>>();
  // Máy đã gắn sang studio khác sau khi token này được cấp -> token hết hiệu lực.
  if (!row || row.machine_studio !== row.studio_id) throw new HttpError(401, "unauthorized");
  if (row.machine_status !== "active") throw new HttpError(403, "machine_disabled");
  if (row.studio_status !== "active") throw new HttpError(403, "studio_suspended");
  return {
    machineId: row.machine_id, hwid: row.hwid, studioId: row.studio_id,
    userId: row.user_id, tokenHash,
  };
}

function normalizeEmail(v: unknown): string {
  return str(v, 254).toLowerCase();
}

function isValidEmail(email: string): boolean {
  return /^[^\s@]+@[^\s@]+\.[^\s@]+$/.test(email);
}

function validatePassword(pw: string): void {
  if (pw.length < 8) throw new HttpError(400, "password_too_short", "Mật khẩu tối thiểu 8 ký tự");
  if (pw.length > 128) throw new HttpError(400, "password_too_long");
}

function readHwid(b: Record<string, unknown>): string {
  const hwid = str(b.hwid, 128);
  if (!isSafeId(hwid, 8, 128)) throw new HttpError(400, "invalid_hwid");
  return hwid;
}

function clientIp(req: Request): string {
  return (req.headers.get("cf-connecting-ip") ?? req.headers.get("x-forwarded-for") ?? "unknown")
    .split(",")[0].trim().slice(0, 80) || "unknown";
}

async function rateLimitAuth(env: Env, req: Request, purpose: string, email: string): Promise<void> {
  const key = await sha256Hex(`${purpose}:${email || "no-email"}:${clientIp(req)}`);
  const nowMs = Date.now();
  const now = new Date(nowMs).toISOString();
  const reset = new Date(nowMs + AUTH_RATE_LIMIT_WINDOW_SECONDS * 1000).toISOString();
  const row = await env.DB.prepare("SELECT count, reset_at FROM auth_rate_limits WHERE key = ?")
    .bind(key).first<{ count: number; reset_at: string }>();
  const count = row && row.reset_at > now ? int(row.count) : 0;
  if (count >= AUTH_RATE_LIMIT_MAX)
    throw new HttpError(429, "rate_limited", "Thử quá nhiều lần, vui lòng chờ một lúc rồi thử lại");
  await env.DB.prepare(
    `INSERT INTO auth_rate_limits (key, count, reset_at, updated_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(key) DO UPDATE SET count = excluded.count, reset_at = excluded.reset_at, updated_at = excluded.updated_at`)
    .bind(key, count + 1, count === 0 ? reset : row!.reset_at, now).run();
}

// Đảm bảo có bản ghi máy (tự kích hoạt: status mặc định 'active'). Trả machine id.
async function upsertMachine(env: Env, hwid: string, deviceName: string, appVersion: string): Promise<string> {
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO machines (id, hwid, device_name, app_version, first_seen_at, last_seen_at)
     VALUES (?, ?, ?, ?, ?, ?)
     ON CONFLICT(hwid) DO UPDATE SET
       device_name  = CASE WHEN excluded.device_name <> '' THEN excluded.device_name ELSE machines.device_name END,
       app_version  = CASE WHEN excluded.app_version <> '' THEN excluded.app_version ELSE machines.app_version END,
       last_seen_at = excluded.last_seen_at`)
    .bind(newId(), hwid, deviceName, appVersion, now, now).run();
  const row = await env.DB.prepare("SELECT id, status FROM machines WHERE hwid = ?")
    .bind(hwid).first<{ id: string; status: string }>();
  if (!row) throw new HttpError(500, "machine_upsert_failed");
  if (row.status !== "active") throw new HttpError(403, "machine_disabled");
  return row.id;
}

// Gắn máy vào studio + thu hồi mọi token cũ của máy + cấp token mới (một transaction).
async function linkMachineAndIssueToken(env: Env, machineId: string, studioId: string, userId: string,
                                        extra: D1PreparedStatement[] = []): Promise<string> {
  const token = randomToken("mt_");
  const tokenHash = await sha256Hex(token);
  const now = nowIso();
  await env.DB.batch([
    ...extra,
    env.DB.prepare("UPDATE machines SET studio_id = ?, linked_at = ? WHERE id = ?").bind(studioId, now, machineId),
    env.DB.prepare("UPDATE machine_tokens SET revoked_at = ? WHERE machine_id = ? AND revoked_at IS NULL").bind(now, machineId),
    env.DB.prepare(
      "INSERT INTO machine_tokens (token_hash, machine_id, studio_id, user_id, created_at) VALUES (?, ?, ?, ?, ?)")
      .bind(tokenHash, machineId, studioId, userId, now),
  ]);
  return token;
}

// POST /v1/machines/register (legacy bootstrap) — không dùng trong desktop mới.
export async function handleMachineRegister(req: Request, env: Env): Promise<Response> {
  requireBootstrap(req, env);
  const b = await readJson(req);
  const hwid = readHwid(b);
  const machineId = await upsertMachine(env, hwid, str(b.device_name, 100), str(b.app_version, 50));
  const studio = await env.DB.prepare(
    `SELECT s.id, s.name FROM machines m JOIN studios s ON s.id = m.studio_id WHERE m.id = ?`)
    .bind(machineId).first<{ id: string; name: string }>();
  return json({ success: true, machine_id: machineId, studio: studio ?? null });
}

// POST /v1/studios/register — tạo studio + chủ studio, gắn máy, cấp token máy.
export async function handleStudioRegister(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const hwid = readHwid(b);
  const studioName = str(b.studio_name, 100);
  const email = normalizeEmail(b.email);
  await rateLimitAuth(env, req, "studio_register", email);
  const password = typeof b.password === "string" ? b.password : "";
  if (!studioName) throw new HttpError(400, "studio_name_required", "Nhập tên studio");
  if (!isValidEmail(email)) throw new HttpError(400, "invalid_email", "Email không hợp lệ");
  validatePassword(password);

  const exists = await env.DB.prepare("SELECT 1 FROM studio_users WHERE email = ?").bind(email).first();
  if (exists) throw new HttpError(409, "email_taken", "Email đã được đăng ký");

  const machineId = await upsertMachine(env, hwid, str(b.device_name, 100), str(b.app_version, 50));
  const passwordHash = await hashPassword(password);
  const studioId = newId();
  const userId = newId();
  const now = nowIso();
  let token: string;
  try {
    token = await linkMachineAndIssueToken(env, machineId, studioId, userId, [
      env.DB.prepare("INSERT INTO studios (id, name, created_at, updated_at) VALUES (?, ?, ?, ?)")
        .bind(studioId, studioName, now, now),
      env.DB.prepare(
        `INSERT INTO studio_users (id, studio_id, email, password_hash, role, created_at, last_login_at)
         VALUES (?, ?, ?, ?, 'owner', ?, ?)`)
        .bind(userId, studioId, email, passwordHash, now, now),
    ]);
  } catch (err) {
    // Hai request đăng ký cùng email chạy song song: UNIQUE(email) chặn request sau.
    if (String(err).includes("UNIQUE")) throw new HttpError(409, "email_taken", "Email đã được đăng ký");
    throw err;
  }
  return json({
    success: true,
    token,
    studio: { id: studioId, name: studioName },
    user: { id: userId, email, role: "owner" },
    machine_id: machineId,
    machine: await machineInfo(env, machineId),
  }, 201);
}

// POST /v1/auth/login — đăng nhập studio trên máy; máy gắn vào studio của user.
export async function handleLogin(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const hwid = readHwid(b);
  const email = normalizeEmail(b.email);
  await rateLimitAuth(env, req, "studio_login", email);
  const password = typeof b.password === "string" ? b.password : "";
  if (!email || !password) throw new HttpError(400, "missing_credentials");

  const now = nowIso();
  const attempt = await env.DB.prepare("SELECT fail_count, locked_until FROM login_attempts WHERE email = ?")
    .bind(email).first<{ fail_count: number; locked_until: string | null }>();
  if (attempt?.locked_until && attempt.locked_until > now) {
    throw new HttpError(429, "login_locked", "Đăng nhập sai quá nhiều lần, thử lại sau 15 phút");
  }

  const user = await env.DB.prepare(
    `SELECT u.id, u.studio_id, u.password_hash, u.role, u.status, s.name AS studio_name, s.status AS studio_status
       FROM studio_users u JOIN studios s ON s.id = u.studio_id WHERE u.email = ?`)
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

  const machineId = await upsertMachine(env, hwid, str(b.device_name, 100), str(b.app_version, 50));
  const token = await linkMachineAndIssueToken(env, machineId, user.studio_id, user.id, [
    env.DB.prepare("DELETE FROM login_attempts WHERE email = ?").bind(email),
    env.DB.prepare("UPDATE studio_users SET last_login_at = ? WHERE id = ?").bind(now, user.id),
  ]);
  return json({
    success: true,
    token,
    studio: { id: user.studio_id, name: user.studio_name },
    user: { id: user.id, email, role: user.role },
    machine_id: machineId,
    machine: await machineInfo(env, machineId),
  });
}

// POST /v1/auth/logout  (machine) — thu hồi token hiện tại. Máy vẫn gắn studio cho tới
// khi có người đăng nhập studio khác trên máy.
export async function handleLogout(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  await env.DB.prepare("UPDATE machine_tokens SET revoked_at = ? WHERE token_hash = ?")
    .bind(nowIso(), caller.tokenHash).run();
  return json({ success: true });
}

/** Name shown for a machine: the studio's display_name, else the app's config name. */
async function machineInfo(env: Env, machineId: string) {
  const row = await env.DB.prepare("SELECT id, device_name, display_name FROM machines WHERE id = ?")
    .bind(machineId).first<{ id: string; device_name: string; display_name: string }>();
  return { id: machineId, device_name: row?.device_name || "", display_name: row?.display_name || "" };
}

// GET /v1/machine/me  (machine)
export async function handleMe(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const row = await env.DB.prepare(
    `SELECT m.id AS machine_id, m.hwid, m.device_name, m.display_name, s.id AS studio_id, s.name AS studio_name, u.email, u.role
       FROM machines m JOIN studios s ON s.id = ? JOIN studio_users u ON u.id = ?
      WHERE m.id = ?`)
    .bind(caller.studioId, caller.userId, caller.machineId).first<Record<string, string>>();
  if (!row) throw new HttpError(404, "not_found");
  await env.DB.prepare("UPDATE machines SET last_seen_at = ? WHERE id = ?").bind(nowIso(), caller.machineId).run();
  return json({
    success: true,
    machine: { id: row.machine_id, hwid: row.hwid, device_name: row.device_name, display_name: row.display_name || "" },
    studio: { id: row.studio_id, name: row.studio_name },
    user: { email: row.email, role: row.role },
  });
}
