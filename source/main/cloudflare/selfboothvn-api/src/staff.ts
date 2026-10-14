// Staff accounts of a studio and the staff portal (/staff).
//
//   POST   /v1/web/staff/login            { studio_id, username, password } -> session cookie
//   GET    /v1/public/staff-portal/:sid   studio name + branding for the portal's sign-in screen
//   GET    /v1/web/staff                  (owner) staff list + permission catalogue + presets
//   POST   /v1/web/staff                  (owner) { username, display_name, password, permissions }
//   PATCH  /v1/web/staff/:id              (owner) { display_name?, permissions?, status?, password? }
//   DELETE /v1/web/staff/:id              (owner) soft delete, signs the account out
//
// A staff member is a studio_users row with role 'staff' (see migration 0016). Its email
// column holds the internal login key 'staff:<studio_id>:<username>'.

import { Env, HttpError, isSafeId, json, newId, nowIso, readJson, str } from "./http";
import { burnPasswordCheck, hashPassword, verifyPassword } from "./password";
import { requireHuman } from "./turnstile";
import { PERMISSION_GROUPS, PERMISSION_PRESETS, normalizePermissions } from "./permissions";
import {
  checkLoginLock, recordLoginFailure, requireOwner, revokeUserSessions, startWebSession,
} from "./webAuth";
import { brandingFor } from "./branding";

const NO_STORE = { "cache-control": "no-store" };
const MAX_STAFF = 100;

function loginKey(studioId: string, username: string) {
  return `staff:${studioId}:${username}`;
}

function cleanUsername(v: unknown): string {
  const name = str(v, 40).toLowerCase();
  if (!/^[a-z0-9][a-z0-9._-]{2,31}$/.test(name)) {
    throw new HttpError(400, "invalid_username", "Tên đăng nhập 3–32 ký tự: chữ thường không dấu, số, dấu . _ -");
  }
  return name;
}

function cleanPassword(v: unknown): string {
  const password = typeof v === "string" ? v : "";
  if (password.length < 8) throw new HttpError(400, "password_too_short", "Mật khẩu tối thiểu 8 ký tự");
  if (password.length > 128) throw new HttpError(400, "password_too_long");
  return password;
}

function studioIdParam(v: unknown): string {
  const id = str(v, 64);
  if (!isSafeId(id, 8, 64)) throw new HttpError(400, "invalid_studio", "Link cổng nhân viên không hợp lệ");
  return id;
}

type StaffRow = {
  id: string;
  username: string;
  display_name: string;
  permissions: string;
  status: string;
  created_at: string;
  updated_at: string | null;
  last_login_at: string | null;
};

function staffDto(row: StaffRow) {
  let permissions: string[] = [];
  try { permissions = normalizePermissions(JSON.parse(row.permissions || "[]")); } catch { permissions = []; }
  return {
    id: row.id,
    username: row.username,
    display_name: row.display_name,
    permissions,
    status: row.status,
    created_at: row.created_at,
    updated_at: row.updated_at || row.created_at,
    last_login_at: row.last_login_at || "",
  };
}

const STAFF_COLUMNS = "id, username, display_name, permissions, status, created_at, updated_at, last_login_at";

async function staffById(env: Env, studioId: string, id: string): Promise<StaffRow> {
  if (!isSafeId(id, 8, 64)) throw new HttpError(400, "invalid_staff_id");
  const row = await env.DB.prepare(
    `SELECT ${STAFF_COLUMNS} FROM studio_users
      WHERE id = ? AND studio_id = ? AND role = 'staff' AND deleted_at IS NULL`)
    .bind(id, studioId).first<StaffRow>();
  if (!row) throw new HttpError(404, "staff_not_found", "Không tìm thấy nhân viên");
  return row;
}

export async function handleStaffLogin(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const studioId = studioIdParam(b.studio_id);
  const username = str(b.username, 40).toLowerCase();
  const password = typeof b.password === "string" ? b.password : "";
  if (!username || !password) throw new HttpError(400, "missing_credentials");
  await requireHuman(req, env, b.turnstile_token, "staff_login");

  const key = loginKey(studioId, username);
  const fails = await checkLoginLock(env, key);
  const user = await env.DB.prepare(
    `SELECT u.id, u.studio_id, u.email, u.password_hash, u.role, u.status, u.username, u.display_name, u.permissions,
            s.name AS studio_name, s.status AS studio_status
       FROM studio_users u
       JOIN studios s ON s.id = u.studio_id
      WHERE u.studio_id = ? AND u.username = ? AND u.role = 'staff' AND u.deleted_at IS NULL`)
    .bind(studioId, username).first<Record<string, string>>();

  const ok = user ? await verifyPassword(password, user.password_hash) : (await burnPasswordCheck(password), false);
  if (!ok || !user) {
    await recordLoginFailure(env, key, fails);
    throw new HttpError(401, "invalid_credentials", "Sai tên đăng nhập hoặc mật khẩu");
  }
  if (user.status !== "active") throw new HttpError(403, "user_disabled", "Tài khoản đã bị khóa, liên hệ quản lý studio");
  if (user.studio_status !== "active") throw new HttpError(403, "studio_suspended");
  return startWebSession(req, env, {
    id: user.id,
    studio_id: user.studio_id,
    email: user.email,
    role: user.role,
    studio_name: user.studio_name,
    username: user.username,
    display_name: user.display_name,
    permissions: user.permissions,
  }, key);
}

/** The sign-in screen of /staff?studio=… shows whose portal it is. */
export async function handleStaffPortal(env: Env, url: URL, rawStudioId: string): Promise<Response> {
  const studioId = studioIdParam(rawStudioId);
  const studio = await env.DB.prepare("SELECT id, name FROM studios WHERE id = ? AND status = 'active'")
    .bind(studioId).first<{ id: string; name: string }>();
  if (!studio) throw new HttpError(404, "studio_not_found", "Link cổng nhân viên không hợp lệ");
  return json({ success: true, studio, branding: await brandingFor(env, url.origin, studio.id) }, 200, NO_STORE);
}

export async function handleWebStaff(req: Request, env: Env): Promise<Response> {
  const owner = await requireOwner(req, env);
  if (req.method === "GET") {
    const rows = await env.DB.prepare(
      `SELECT ${STAFF_COLUMNS} FROM studio_users
        WHERE studio_id = ? AND role = 'staff' AND deleted_at IS NULL
        ORDER BY created_at DESC`)
      .bind(owner.studioId).all<StaffRow>();
    return json({
      success: true,
      staff: (rows.results ?? []).map(staffDto),
      groups: PERMISSION_GROUPS,
      presets: PERMISSION_PRESETS,
    }, 200, NO_STORE);
  }

  const b = await readJson(req);
  const username = cleanUsername(b.username);
  const password = cleanPassword(b.password);
  const displayName = str(b.display_name, 60) || username;
  const permissions = normalizePermissions(b.permissions);
  const count = await env.DB.prepare(
    "SELECT COUNT(*) AS n FROM studio_users WHERE studio_id = ? AND role = 'staff' AND deleted_at IS NULL")
    .bind(owner.studioId).first<{ n: number }>();
  if (Number(count?.n ?? 0) >= MAX_STAFF) throw new HttpError(409, "staff_limit", `Tối đa ${MAX_STAFF} nhân viên`);
  const taken = await env.DB.prepare(
    "SELECT deleted_at FROM studio_users WHERE studio_id = ? AND username = ?")
    .bind(owner.studioId, username).first<{ deleted_at: string | null }>();
  if (taken && !taken.deleted_at) throw new HttpError(409, "username_taken", "Tên đăng nhập đã có trong studio");
  if (taken) {
    // A deleted account keeps its row (sessions and history point at it): free the name.
    await env.DB.prepare(
      "UPDATE studio_users SET username = NULL, email = email || ':deleted:' || id WHERE studio_id = ? AND username = ?")
      .bind(owner.studioId, username).run();
  }

  const id = newId();
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_users (id, studio_id, email, password_hash, role, status, username, display_name,
                               permissions, created_by, created_at, updated_at)
     VALUES (?, ?, ?, ?, 'staff', 'active', ?, ?, ?, ?, ?, ?)`)
    .bind(id, owner.studioId, loginKey(owner.studioId, username), await hashPassword(password), username, displayName,
      JSON.stringify(permissions), owner.userId, now, now)
    .run();
  return json({ success: true, staff: staffDto(await staffById(env, owner.studioId, id)) }, 201, NO_STORE);
}

export async function handleWebStaffDetail(req: Request, env: Env, staffId: string): Promise<Response> {
  const owner = await requireOwner(req, env);
  const current = await staffById(env, owner.studioId, staffId);
  const now = nowIso();

  if (req.method === "DELETE") {
    await env.DB.prepare(
      "UPDATE studio_users SET status = 'disabled', deleted_at = ?, updated_at = ? WHERE id = ? AND studio_id = ?")
      .bind(now, now, current.id, owner.studioId).run();
    await revokeUserSessions(env, current.id);
    return json({ success: true }, 200, NO_STORE);
  }

  const b = await readJson(req);
  const displayName = b.display_name === undefined ? current.display_name : (str(b.display_name, 60) || current.username);
  const permissions = b.permissions === undefined ? null : normalizePermissions(b.permissions);
  const status = b.status === undefined ? current.status : str(b.status, 16);
  if (status !== "active" && status !== "disabled") throw new HttpError(400, "invalid_status");
  const passwordHash = b.password === undefined ? null : await hashPassword(cleanPassword(b.password));

  await env.DB.prepare(
    `UPDATE studio_users
        SET display_name = ?, permissions = COALESCE(?, permissions), status = ?,
            password_hash = COALESCE(?, password_hash), updated_at = ?
      WHERE id = ? AND studio_id = ?`)
    .bind(displayName, permissions ? JSON.stringify(permissions) : null, status, passwordHash, now, current.id, owner.studioId)
    .run();
  // Locked or given a new password: every device signed in as this staff member is signed out.
  // A permission change needs no sign-out: every request reads the current permissions.
  if (status === "disabled" || passwordHash) await revokeUserSessions(env, current.id);
  return json({ success: true, staff: staffDto(await staffById(env, owner.studioId, current.id)) }, 200, NO_STORE);
}
