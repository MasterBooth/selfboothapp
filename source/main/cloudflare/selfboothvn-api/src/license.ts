// Giấy phép máy ký số + mã kích hoạt OTP 4 số.
//
// Token: LM1.<base64url(payload JSON)>.<base64url(chữ ký Ed25519 64 byte)>
//   typ "license" (hoặc thiếu typ — bản cũ): giấy phép của một hwid.
//   typ "revoke"                           : phiếu thu hồi một serial của một hwid.
//
// Khoá private CHỈ nằm trong app BOOTHME_ADMIN. Worker chỉ xác minh chữ ký bằng
// LICENSE_PUBLIC_KEYS rồi lưu / phát lại; máy booth xác minh lại lần nữa bằng khoá
// công khai biên dịch cứng. Vì vậy lộ D1 hay Worker cũng không tạo được giấy phép
// giả và không khoá được máy (phiếu thu hồi cũng phải có chữ ký admin).
//
// Luồng: máy đăng nhập studio -> POST /v1/machine/license/request (chờ duyệt)
//        -> admin ký + POST /v1/admin/licenses/issue -> Worker sinh OTP 4 số
//        -> khách nhập OTP -> POST /v1/machine/license/redeem -> nhận token, lưu cục bộ.

import { Env, HttpError, fromB64, isSafeId, json, newId, nowIso, readJson, str, timingSafeEqual } from "./http";
import { requireMachine } from "./auth";

const OTP_TTL_MS = 24 * 60 * 60 * 1000;
const OTP_MAX_ATTEMPTS = 5;

export interface SignedPayload {
  typ: "license" | "revoke";
  kid: string;
  hwid: string;
  serial: string;
  issued_at: string;
  not_after: string | null;
  device_tier: string;
  raw: Record<string, unknown>;
}

function b64urlToBytes(s: string): Uint8Array {
  if (!/^[A-Za-z0-9_-]*$/.test(s)) throw new HttpError(400, "invalid_token", "Token sai định dạng");
  const b64 = s.replace(/-/g, "+").replace(/_/g, "/");
  try {
    return fromB64(b64 + "=".repeat((4 - (b64.length % 4)) % 4));
  } catch {
    throw new HttpError(400, "invalid_token", "Token sai định dạng");
  }
}

function hexToBytes(hex: string): Uint8Array | null {
  if (!/^[0-9a-fA-F]{64}$/.test(hex)) return null;
  const out = new Uint8Array(32);
  for (let i = 0; i < 32; i++) out[i] = parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return out;
}

// LICENSE_PUBLIC_KEYS = "kid:hex,kid2:hex" — đúng dòng LicenseSigner::wranglerVarLine() in ra.
function publicKeyFor(env: Env, kid: string): Uint8Array | null {
  for (const entry of (env.LICENSE_PUBLIC_KEYS ?? "").split(",")) {
    const [k, hex] = entry.trim().split(":");
    if (k && hex && k.trim() === kid) return hexToBytes(hex.trim());
  }
  return null;
}

// Xác minh chữ ký trên ĐÚNG chuỗi byte payload đã giải mã (không tuần tự hoá lại).
export async function verifySignedToken(env: Env, token: string, expectTyp: "license" | "revoke"): Promise<SignedPayload> {
  const parts = token.trim().split(".");
  if (parts.length !== 3 || parts[0] !== "LM1") throw new HttpError(400, "invalid_token", "Token sai định dạng");
  const payloadBytes = b64urlToBytes(parts[1]);
  const sig = b64urlToBytes(parts[2]);
  if (sig.length !== 64 || payloadBytes.length === 0) throw new HttpError(400, "invalid_token", "Token sai định dạng");

  let raw: Record<string, unknown>;
  try {
    const parsed = JSON.parse(new TextDecoder().decode(payloadBytes));
    if (!parsed || typeof parsed !== "object" || Array.isArray(parsed)) throw new Error("not object");
    raw = parsed as Record<string, unknown>;
  } catch {
    throw new HttpError(400, "invalid_token", "Payload không phải JSON");
  }

  const kid = str(raw.kid, 64);
  const pk = publicKeyFor(env, kid);
  if (!pk) throw new HttpError(400, "unknown_key", `Worker không biết khoá ký '${kid}'`);
  const key = await crypto.subtle.importKey("raw", pk, { name: "Ed25519" }, false, ["verify"]);
  const ok = await crypto.subtle.verify({ name: "Ed25519" }, key, sig, payloadBytes);
  if (!ok) throw new HttpError(400, "bad_signature", "Chữ ký không hợp lệ");

  const typ = raw.typ === undefined ? "license" : str(raw.typ, 16);
  if (typ !== expectTyp) throw new HttpError(400, "wrong_token_type", `Cần token loại ${expectTyp}`);

  const hwid = str(raw.hwid, 128).toUpperCase();
  const serial = str(raw.serial, 100);
  const issuedAt = str(raw.issued_at, 40);
  if (!isSafeId(hwid, 8, 128)) throw new HttpError(400, "invalid_hwid");
  if (!isSafeId(serial, 1, 100)) throw new HttpError(400, "invalid_serial");
  if (!issuedAt) throw new HttpError(400, "missing_issued_at");

  return {
    typ, kid, hwid, serial, issued_at: issuedAt,
    not_after: str(raw.not_after, 40) || null,
    device_tier: str(raw.device_tier, 40),
    raw,
  };
}

// 0000–9999 phân phối đều (loại bỏ phần dư để không lệch về số nhỏ).
export function newOtp(): string {
  const buf = new Uint32Array(1);
  const limit = Math.floor(0x1_0000_0000 / 10000) * 10000;
  for (;;) {
    crypto.getRandomValues(buf);
    if (buf[0] < limit) return String(buf[0] % 10000).padStart(4, "0");
  }
}

// ── Câu lệnh dựng sẵn (ghép vào DB.batch để chạy nguyên tử) ──────────────────

function issueStatements(env: Env, lic: SignedPayload, token: string, machineId: string | null,
                         approver: string, now: string): D1PreparedStatement[] {
  return [
    env.DB.prepare("UPDATE licenses SET status = 'superseded' WHERE hwid = ? AND status = 'active'").bind(lic.hwid),
    env.DB.prepare(
      `INSERT INTO licenses (serial, hwid, machine_id, token, device_tier, not_after, issued_at, status, approver, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)`)
      .bind(lic.serial, lic.hwid, machineId, token.trim(), lic.device_tier, lic.not_after, lic.issued_at, approver, now),
  ];
}

function otpStatements(env: Env, hwid: string, serial: string, code: string, expiresAt: string,
                       now: string): D1PreparedStatement[] {
  return [
    env.DB.prepare("UPDATE license_otps SET status = 'cancelled' WHERE hwid = ? AND status = 'active'").bind(hwid),
    env.DB.prepare(
      `INSERT INTO license_otps (id, hwid, serial, code, expires_at, attempts, status, created_at)
       VALUES (?, ?, ?, ?, ?, 0, 'active', ?)`)
      .bind(newId(), hwid, serial, code, expiresAt, now),
  ];
}

function revokeStatements(env: Env, rev: SignedPayload, token: string, now: string): D1PreparedStatement[] {
  return [
    env.DB.prepare("UPDATE licenses SET status = 'revoked', revoked_at = ? WHERE serial = ? AND hwid = ?")
      .bind(now, rev.serial, rev.hwid),
    env.DB.prepare("INSERT OR IGNORE INTO license_revocations (serial, hwid, token, created_at) VALUES (?, ?, ?, ?)")
      .bind(rev.serial, rev.hwid, token.trim(), now),
    env.DB.prepare("UPDATE license_otps SET status = 'cancelled' WHERE hwid = ? AND status = 'active'").bind(rev.hwid),
  ];
}

async function machineIdFor(env: Env, hwid: string): Promise<string | null> {
  const row = await env.DB.prepare("SELECT id FROM machines WHERE hwid = ?").bind(hwid).first<{ id: string }>();
  return row?.id ?? null;
}

async function ensureSerialFree(env: Env, serial: string): Promise<void> {
  const row = await env.DB.prepare("SELECT 1 FROM licenses WHERE serial = ?").bind(serial).first();
  if (row) throw new HttpError(409, "serial_exists", "Số hiệu giấy phép đã tồn tại");
}

async function revocationTarget(env: Env, rev: SignedPayload) {
  const row = await env.DB.prepare("SELECT serial, status FROM licenses WHERE serial = ? AND hwid = ?")
    .bind(rev.serial, rev.hwid).first<{ serial: string; status: string }>();
  if (!row) throw new HttpError(404, "license_not_found", "Không có giấy phép này cho máy này");
  return row;
}

// ── Route máy ─────────────────────────────────────────────────────────────────

// POST /v1/machine/license/request — máy báo "chưa có chữ ký, chờ admin cấp".
export async function handleLicenseRequest(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const hwid = caller.hwid.toUpperCase();
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO license_requests (hwid, machine_id, studio_id, requested_at, updated_at) VALUES (?, ?, ?, ?, ?)
     ON CONFLICT(hwid) DO UPDATE SET machine_id = excluded.machine_id, studio_id = excluded.studio_id,
       updated_at = excluded.updated_at`)
    .bind(hwid, caller.machineId, caller.studioId, now, now).run();
  const active = await env.DB.prepare("SELECT 1 FROM licenses WHERE hwid = ? AND status = 'active'").bind(hwid).first();
  return json({ success: true, state: active ? "licensed" : "pending" });
}

// POST /v1/machine/license/redeem {otp}
export async function handleLicenseRedeem(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const hwid = caller.hwid.toUpperCase();
  const b = await readJson(req);
  const code = str(b.otp, 8);
  if (!/^[0-9]{4}$/.test(code)) throw new HttpError(400, "invalid_otp_format", "Mã kích hoạt gồm 4 chữ số");

  const otp = await env.DB.prepare(
    "SELECT id, code, expires_at, attempts FROM license_otps WHERE hwid = ? AND status = 'active'")
    .bind(hwid).first<{ id: string; code: string; expires_at: string; attempts: number }>();
  if (!otp) throw new HttpError(404, "otp_not_found", "Máy chưa có mã kích hoạt. Liên hệ quản trị viên để nhận mã.");

  const now = nowIso();
  if (otp.expires_at <= now) {
    await env.DB.prepare("UPDATE license_otps SET status = 'cancelled' WHERE id = ?").bind(otp.id).run();
    throw new HttpError(410, "otp_expired", "Mã kích hoạt đã hết hạn. Liên hệ quản trị viên để nhận mã mới.");
  }

  if (!timingSafeEqual(code, otp.code)) {
    // Tăng nguyên tử để hai request song song không cùng "lách" qua giới hạn.
    const row = await env.DB.prepare(
      `UPDATE license_otps SET attempts = attempts + 1,
         status = CASE WHEN attempts + 1 >= ? THEN 'locked' ELSE status END
       WHERE id = ? AND status = 'active' RETURNING attempts`)
      .bind(OTP_MAX_ATTEMPTS, otp.id).first<{ attempts: number }>();
    const used = row?.attempts ?? OTP_MAX_ATTEMPTS;
    const left = Math.max(0, OTP_MAX_ATTEMPTS - used);
    if (left === 0) {
      return json({ success: false, error: "otp_locked", attempts_left: 0,
        message: "Nhập sai quá 5 lần, mã đã bị khoá. Liên hệ quản trị viên để nhận mã mới." }, 429);
    }
    return json({ success: false, error: "otp_invalid", attempts_left: left,
      message: `Mã kích hoạt không đúng. Còn ${left} lần thử.` }, 400);
  }

  // Trả giấy phép ĐANG active của máy (không phải serial lúc sinh OTP): admin gia
  // hạn trong lúc khách chưa kịp nhập mã thì khách vẫn nhận bản mới nhất.
  const lic = await env.DB.prepare("SELECT serial, token FROM licenses WHERE hwid = ? AND status = 'active'")
    .bind(hwid).first<{ serial: string; token: string }>();
  if (!lic) throw new HttpError(409, "license_not_active", "Giấy phép của máy không còn hiệu lực. Liên hệ quản trị viên.");

  await env.DB.prepare("UPDATE license_otps SET status = 'used', used_at = ? WHERE id = ? AND status = 'active'")
    .bind(now, otp.id).run();
  return json({ success: true, serial: lic.serial, license: lic.token });
}

// GET /v1/machine/license/status — giấy phép mới nhất + mọi phiếu thu hồi của máy.
// Máy tự xác minh chữ ký từng token nên route này không cần đáng tin.
export async function handleLicenseStatus(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const hwid = caller.hwid.toUpperCase();
  const lic = await env.DB.prepare("SELECT token FROM licenses WHERE hwid = ? AND status = 'active'")
    .bind(hwid).first<{ token: string }>();
  const revs = await env.DB.prepare("SELECT token FROM license_revocations WHERE hwid = ? ORDER BY created_at")
    .bind(hwid).all<{ token: string }>();
  return json({
    success: true,
    license: lic?.token ?? null,
    revocations: (revs.results ?? []).map((r) => r.token),
  });
}

// ── Route admin ───────────────────────────────────────────────────────────────

// GET /v1/admin/licenses/machines
export async function handleAdminLicenseMachines(env: Env): Promise<Response> {
  const now = nowIso();
  const rs = await env.DB.prepare(
    `WITH h AS (SELECT hwid FROM license_requests UNION SELECT hwid FROM licenses)
     SELECT h.hwid, m.id AS machine_id, m.device_name, m.app_version, m.last_seen_at,
            s.id AS studio_id, s.name AS studio_name,
            (SELECT email FROM studio_users u WHERE u.studio_id = s.id AND u.role = 'owner' LIMIT 1) AS owner_email,
            r.requested_at, r.updated_at AS request_updated_at,
            l.serial, l.device_tier, l.not_after, l.issued_at, l.status AS license_status, l.approver, l.revoked_at,
            o.code AS otp, o.expires_at AS otp_expires_at, o.attempts AS otp_attempts
       FROM h
       LEFT JOIN machines m ON m.hwid = h.hwid
       LEFT JOIN studios s ON s.id = m.studio_id
       LEFT JOIN license_requests r ON r.hwid = h.hwid
       LEFT JOIN licenses l ON l.serial = (
         SELECT serial FROM licenses x WHERE x.hwid = h.hwid
          ORDER BY (x.status = 'active') DESC, x.issued_at DESC, x.created_at DESC LIMIT 1)
       LEFT JOIN license_otps o ON o.hwid = h.hwid AND o.status = 'active' AND o.expires_at > ?
      ORDER BY COALESCE(r.updated_at, l.created_at) DESC
      LIMIT 500`)
    .bind(now).all<Record<string, unknown>>();
  const machines = (rs.results ?? []).map((row) => ({
    ...row,
    state: row.license_status === "active" ? "licensed" : row.license_status === "revoked" ? "revoked" : "pending",
  }));
  return json({ success: true, machines });
}

// POST /v1/admin/licenses/issue {license, approver, with_otp}
//   Cấp mới (with_otp = true) hoặc gia hạn / đổi hạng (with_otp = false: máy tự nhận khi online).
export async function handleAdminLicenseIssue(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const token = str(b.license, 8000);
  const lic = await verifySignedToken(env, token, "license");
  const withOtp = b.with_otp !== false;
  await ensureSerialFree(env, lic.serial);
  const machineId = await machineIdFor(env, lic.hwid);
  if (!machineId) throw new HttpError(404, "machine_not_found", "Máy chưa từng báo danh với máy chủ");

  const now = nowIso();
  const stmts = issueStatements(env, lic, token, machineId, str(b.approver, 100), now);
  let otp: string | undefined;
  let expiresAt: string | undefined;
  if (withOtp) {
    otp = newOtp();
    expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();
    stmts.push(...otpStatements(env, lic.hwid, lic.serial, otp, expiresAt, now));
  }
  await env.DB.batch(stmts);
  return json({ success: true, serial: lic.serial, hwid: lic.hwid, otp: otp ?? null, otp_expires_at: expiresAt ?? null });
}

// POST /v1/admin/licenses/otp {hwid} — cấp lại OTP cho giấy phép đang active.
export async function handleAdminLicenseOtp(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const hwid = str(b.hwid, 128).toUpperCase();
  if (!isSafeId(hwid, 8, 128)) throw new HttpError(400, "invalid_hwid");
  const lic = await env.DB.prepare("SELECT serial FROM licenses WHERE hwid = ? AND status = 'active'")
    .bind(hwid).first<{ serial: string }>();
  if (!lic) throw new HttpError(409, "license_not_active", "Máy chưa có giấy phép đang hiệu lực");
  const now = nowIso();
  const otp = newOtp();
  const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();
  await env.DB.batch(otpStatements(env, hwid, lic.serial, otp, expiresAt, now));
  return json({ success: true, hwid, serial: lic.serial, otp, otp_expires_at: expiresAt });
}

// POST /v1/admin/licenses/revoke {revocation}
export async function handleAdminLicenseRevoke(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const token = str(b.revocation, 8000);
  const rev = await verifySignedToken(env, token, "revoke");
  await revocationTarget(env, rev);
  await env.DB.batch(revokeStatements(env, rev, token, nowIso()));
  return json({ success: true, serial: rev.serial, hwid: rev.hwid });
}

// POST /v1/admin/licenses/transfer {revocation, license, approver}
//   Thu hồi máy cũ + cấp cho máy mới (kèm OTP) trong một transaction.
export async function handleAdminLicenseTransfer(req: Request, env: Env): Promise<Response> {
  const b = await readJson(req);
  const revToken = str(b.revocation, 8000);
  const licToken = str(b.license, 8000);
  const rev = await verifySignedToken(env, revToken, "revoke");
  const lic = await verifySignedToken(env, licToken, "license");
  if (rev.hwid === lic.hwid) throw new HttpError(400, "same_machine", "Máy mới phải khác máy cũ");
  await revocationTarget(env, rev);
  await ensureSerialFree(env, lic.serial);
  const machineId = await machineIdFor(env, lic.hwid);
  if (!machineId) throw new HttpError(404, "machine_not_found", "Máy mới chưa từng báo danh với máy chủ");

  const now = nowIso();
  const otp = newOtp();
  const expiresAt = new Date(Date.now() + OTP_TTL_MS).toISOString();
  await env.DB.batch([
    ...revokeStatements(env, rev, revToken, now),
    ...issueStatements(env, lic, licToken, machineId, str(b.approver, 100), now),
    ...otpStatements(env, lic.hwid, lic.serial, otp, expiresAt, now),
  ]);
  return json({ success: true, serial: lic.serial, hwid: lic.hwid, otp, otp_expires_at: expiresAt });
}

// DELETE /v1/admin/licenses/machines/{hwid} — chỉ khi đã thu hồi hết. Phiếu thu hồi được giữ lại.
export async function handleAdminLicenseDelete(env: Env, hwidParam: string): Promise<Response> {
  const hwid = hwidParam.trim().toUpperCase();
  if (!isSafeId(hwid, 8, 128)) throw new HttpError(400, "invalid_hwid");
  const active = await env.DB.prepare("SELECT 1 FROM licenses WHERE hwid = ? AND status = 'active'").bind(hwid).first();
  if (active) throw new HttpError(409, "license_active", "Thu hồi giấy phép trước khi xoá máy");
  await env.DB.batch([
    env.DB.prepare("DELETE FROM license_otps WHERE hwid = ?").bind(hwid),
    env.DB.prepare("DELETE FROM licenses WHERE hwid = ? AND status <> 'active'").bind(hwid),
    env.DB.prepare("DELETE FROM license_requests WHERE hwid = ?").bind(hwid),
  ]);
  return json({ success: true, hwid });
}

// GET /v1/admin/licenses/machines/{hwid} — lịch sử giấy phép + OTP của một máy (token
// license không trả về: app admin không cần, và bớt dữ liệu nhạy cảm đi qua mạng).
export async function handleAdminLicenseHistory(env: Env, hwidParam: string): Promise<Response> {
  const hwid = hwidParam.trim().toUpperCase();
  if (!isSafeId(hwid, 8, 128)) throw new HttpError(400, "invalid_hwid");
  const lic = await env.DB.prepare(
    `SELECT serial, device_tier, not_after, issued_at, status, approver, created_at, revoked_at
       FROM licenses WHERE hwid = ? ORDER BY issued_at DESC, created_at DESC LIMIT 50`)
    .bind(hwid).all();
  const otps = await env.DB.prepare(
    `SELECT code, serial, expires_at, attempts, status, created_at, used_at
       FROM license_otps WHERE hwid = ? ORDER BY created_at DESC LIMIT 20`)
    .bind(hwid).all();
  return json({ success: true, hwid, licenses: lic.results ?? [], otps: otps.results ?? [] });
}
