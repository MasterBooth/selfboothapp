// Mã gói chụp (4 số, thuộc studio).
//   single   : dùng đúng 1 lần, bắt buộc online (redeem nguyên tử ở server).
//   reusable : dùng nhiều lần; app cache danh sách để nhận mã khi mất mạng, rồi đẩy
//              các lượt dùng offline lên /v1/machine/codes/uses.
// Mỗi lượt dùng có use_id do app sinh -> gửi lại bao nhiêu lần cũng chỉ 1 bản ghi.

import { Env, HttpError, isSafeId, json, newId, nowIso, readJson, str } from "./http";
import { MachineCaller, requireMachine } from "./auth";

interface CodeRow {
  id: string;
  code: string;
  kind: "single" | "reusable";
  minutes: number;
  price_vnd: number;
  status: string;
  valid_from: string | null;
  valid_until: string | null;
}

export function isFourDigitCode(v: string): boolean {
  return /^[0-9]{4}$/.test(v);
}

function useResult(use: { id: string; code_id: string; kind: string; minutes: number; price_vnd: number }) {
  return {
    success: true, use_id: use.id, code_id: use.code_id, kind: use.kind,
    minutes: use.minutes, price_vnd: use.price_vnd,
  };
}

function checkWindow(row: CodeRow, at: string): void {
  if (row.valid_from && at < row.valid_from) throw new HttpError(410, "code_not_yet_valid", "Mã chưa tới thời gian sử dụng");
  if (row.valid_until && at > row.valid_until) throw new HttpError(410, "code_expired", "Mã đã hết hạn");
}

function codeInfo(row: CodeRow) {
  return {
    success: true,
    code: row.code,
    code_id: row.id,
    kind: row.kind,
    minutes: row.minutes,
    price_vnd: row.price_vnd,
  };
}

async function findExistingUse(env: Env, caller: MachineCaller, useId: string) {
  const use = await env.DB.prepare(
    "SELECT id, code_id, kind, minutes, price_vnd, machine_id FROM package_code_uses WHERE id = ?")
    .bind(useId).first<{ id: string; code_id: string; kind: string; minutes: number; price_vnd: number; machine_id: string }>();
  if (use && use.machine_id !== caller.machineId) throw new HttpError(409, "use_id_conflict");
  return use;
}

// POST /v1/machine/codes/check {code}
// Kiểm tra mã còn dùng được nhưng KHÔNG đánh dấu đã dùng. App gọi khi nhập đủ 4 số.
export async function handleCheck(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const b = await readJson(req);
  const code = str(b.code, 4);
  if (!isFourDigitCode(code)) throw new HttpError(400, "invalid_code", "Mã gồm đúng 4 chữ số");

  const row = await env.DB.prepare(
    `SELECT id, code, kind, minutes, price_vnd, status, valid_from, valid_until
       FROM package_codes WHERE studio_id = ? AND code = ?
      ORDER BY (status = 'active') DESC, created_at DESC LIMIT 1`)
    .bind(caller.studioId, code).first<CodeRow>();
  if (!row || row.status === "revoked") throw new HttpError(404, "code_invalid", "Mã không đúng");
  if (row.status === "used") throw new HttpError(409, "code_used", "Mã đã được sử dụng");
  checkWindow(row, nowIso());
  // Codes handed out for a web booking: the booth greets the guest by name.
  const booking = await env.DB.prepare(
    `SELECT b.customer_name, b.booking_date, b.start_minute, r.name AS room_name
       FROM studio_bookings b LEFT JOIN studio_rooms r ON r.id = b.room_id
      WHERE b.code_id = ? AND b.studio_id = ?`)
    .bind(row.id, caller.studioId).first<{ customer_name: string; booking_date: string; start_minute: number; room_name: string | null }>();
  return json({
    ...codeInfo(row),
    ...(booking ? {
      booking: {
        customer_name: booking.customer_name,
        booking_date: booking.booking_date,
        start_minute: Number(booking.start_minute),
        room_name: booking.room_name || "",
      },
    } : {}),
  }, 200, { "cache-control": "no-store" });
}

// POST /v1/machine/codes/redeem {code, session_id, use_id}
export async function handleRedeem(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const b = await readJson(req);
  const code = str(b.code, 4);
  const sessionId = str(b.session_id, 100);
  const useId = str(b.use_id, 64);
  if (!isFourDigitCode(code)) throw new HttpError(400, "invalid_code", "Mã gồm đúng 4 chữ số");
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  if (!isSafeId(useId, 8, 64)) throw new HttpError(400, "invalid_use_id");

  // Gửi lại cùng use_id (app retry sau timeout) -> trả đúng kết quả lần trước.
  const prior = await findExistingUse(env, caller, useId);
  if (prior) return json(useResult(prior));

  const row = await env.DB.prepare(
    `SELECT id, code, kind, minutes, price_vnd, status, valid_from, valid_until
       FROM package_codes WHERE studio_id = ? AND code = ?
      ORDER BY (status = 'active') DESC, created_at DESC LIMIT 1`)
    .bind(caller.studioId, code).first<CodeRow>();
  if (!row || row.status === "revoked") throw new HttpError(404, "code_invalid", "Mã không đúng");
  if (row.status === "used") throw new HttpError(409, "code_used", "Mã đã được sử dụng");
  const now = nowIso();
  checkWindow(row, now);

  if (row.kind === "single") {
    // Hai máy nhập cùng lúc: batch D1 chạy tuần tự trong transaction, chỉ UPDATE của một
    // bên đổi được active -> used. INSERT lượt dùng chỉ chạy khi bản ghi used mang đúng
    // máy/phiên/thời điểm của CHÍNH request này.
    await env.DB.batch([
      env.DB.prepare(
        `UPDATE package_codes SET status = 'used', used_at = ?, used_machine_id = ?, used_session_id = ?
          WHERE id = ? AND status = 'active'`)
        .bind(now, caller.machineId, sessionId, row.id),
      env.DB.prepare(
        `INSERT OR IGNORE INTO package_code_uses (id, studio_id, machine_id, code_id, code, kind, session_id,
           minutes, price_vnd, used_at, source, created_at)
         SELECT ?, ?, ?, ?, ?, 'single', ?, ?, ?, ?, 'online', ?
          WHERE EXISTS (SELECT 1 FROM package_codes WHERE id = ? AND status = 'used'
                          AND used_machine_id = ? AND used_session_id = ? AND used_at = ?)`)
        .bind(useId, caller.studioId, caller.machineId, row.id, code, sessionId, row.minutes, row.price_vnd,
              now, now, row.id, caller.machineId, sessionId, now),
    ]);
  } else {
    await env.DB.prepare(
      `INSERT OR IGNORE INTO package_code_uses (id, studio_id, machine_id, code_id, code, kind, session_id,
         minutes, price_vnd, used_at, source, created_at)
       VALUES (?, ?, ?, ?, ?, 'reusable', ?, ?, ?, ?, 'online', ?)`)
      .bind(useId, caller.studioId, caller.machineId, row.id, code, sessionId, row.minutes, row.price_vnd, now, now)
      .run();
  }

  const use = await findExistingUse(env, caller, useId);
  if (!use) throw new HttpError(409, "code_used", "Mã đã được sử dụng");
  return json(useResult(use));
}

// POST /v1/machine/codes/uses {uses:[{use_id, code, session_id, used_at, kind?, minutes?, price_vnd?, package_name?, room_name?}]}
// Lượt dùng mã DÙNG LẠI mà app đã chấp nhận khi mất mạng. Với mã local chỉ có trên máy,
// app gửi kèm metadata gói để web vẫn ghi nhận doanh thu dù server chưa từng phát mã đó.
export async function handleOfflineUses(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const b = await readJson(req);
  const uses = Array.isArray(b.uses) ? b.uses.slice(0, 100) : [];
  const results: Array<{ use_id: string; status: string }> = [];
  const now = nowIso();

  for (const raw of uses) {
    const u = (raw ?? {}) as Record<string, unknown>;
    const useId = str(u.use_id, 64);
    const code = str(u.code, 4);
    const sessionId = str(u.session_id, 100);
    const usedAt = str(u.used_at, 40) || now;
    const kind = str(u.kind, 20);
    const minutes = Number(u.minutes);
    const price = Number(u.price_vnd ?? 0);
    const packageName = str(u.package_name, 120);
    const roomName = str(u.room_name, 120);
    if (!isSafeId(useId, 8, 64) || !isFourDigitCode(code) || (sessionId && !isSafeId(sessionId, 1, 100))) {
      results.push({ use_id: useId, status: "invalid" });
      continue;
    }
    // Mã có thể đã bị thu hồi sau khi máy dùng offline -> vẫn ghi nhận lượt đã dùng thật.
    const row = await env.DB.prepare(
      `SELECT id, minutes, price_vnd FROM package_codes
        WHERE studio_id = ? AND code = ? AND kind = 'reusable'
        ORDER BY (status = 'active') DESC, created_at DESC LIMIT 1`)
      .bind(caller.studioId, code).first<{ id: string; minutes: number; price_vnd: number }>();
    if (!row) {
      if (kind !== "local" || !Number.isInteger(minutes) || minutes <= 0 || !Number.isInteger(price) || price < 0) {
        results.push({ use_id: useId, status: "code_not_found" });
        continue;
      }
      const localCodeId = `local-${useId}`;
      await env.DB.prepare(
        `INSERT OR IGNORE INTO package_codes (id, studio_id, code, kind, minutes, price_vnd,
           status, note, created_at, used_at, used_machine_id, used_session_id)
         VALUES (?, ?, ?, 'reusable', ?, ?, 'used', ?, ?, ?, ?, ?)`)
        .bind(localCodeId, caller.studioId, code, minutes, price, packageName, now, usedAt,
              caller.machineId, sessionId)
        .run();
      const res = await env.DB.prepare(
        `INSERT OR IGNORE INTO package_code_uses (id, studio_id, machine_id, code_id, code, kind, session_id,
           minutes, price_vnd, used_at, source, created_at, package_name, room_name)
         VALUES (?, ?, ?, ?, ?, 'local', ?, ?, ?, ?, 'offline', ?, ?, ?)`)
        .bind(useId, caller.studioId, caller.machineId, localCodeId, code, sessionId, minutes, price,
              usedAt, now, packageName, roomName)
        .run();
      results.push({ use_id: useId, status: (res.meta.changes ?? 0) > 0 ? "inserted" : "duplicate" });
      continue;
    }
    const res = await env.DB.prepare(
      `INSERT OR IGNORE INTO package_code_uses (id, studio_id, machine_id, code_id, code, kind, session_id,
         minutes, price_vnd, used_at, source, created_at, package_name, room_name)
       VALUES (?, ?, ?, ?, ?, 'reusable', ?, ?, ?, ?, 'offline', ?, '', '')`)
      .bind(useId, caller.studioId, caller.machineId, row.id, code, sessionId, row.minutes, row.price_vnd, usedAt, now)
      .run();
    results.push({ use_id: useId, status: (res.meta.changes ?? 0) > 0 ? "inserted" : "duplicate" });
  }
  return json({ success: true, results });
}

// GET /v1/machine/codes/reusable — app cache để nhận mã dùng lại khi mất mạng.
export async function handleReusableList(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const rs = await env.DB.prepare(
    `SELECT code, minutes, price_vnd, valid_from, valid_until FROM package_codes
      WHERE studio_id = ? AND kind = 'reusable' AND status = 'active' ORDER BY code`)
    .bind(caller.studioId).all();
  return json({ success: true, fetched_at: nowIso(), codes: rs.results ?? [] });
}

// ── Admin (chưa có web) ─────────────────────────────────────────────────────

async function randomFreeCode(env: Env, studioId: string, taken: Set<string>): Promise<string> {
  for (let i = 0; i < 200; i++) {
    const n = new Uint32Array(1);
    crypto.getRandomValues(n);
    const code = String(n[0] % 10000).padStart(4, "0");
    if (!taken.has(code)) return code;
  }
  throw new HttpError(409, "no_free_code", "Studio đã dùng gần hết 10 000 mã 4 số");
}

// POST /v1/admin/studios/{studio_id}/codes
// {kind, minutes, price_vnd, code?, count?, valid_from?, valid_until?, note?}
// Không truyền code -> sinh ngẫu nhiên; count (1..100) chỉ dùng khi không truyền code.
export async function handleAdminCreateCodes(req: Request, env: Env, studioId: string): Promise<Response> {
  const b = await readJson(req);
  const kind = str(b.kind, 10);
  const minutes = Number(b.minutes);
  const price = Number(b.price_vnd ?? 0);
  if (kind !== "single" && kind !== "reusable") throw new HttpError(400, "invalid_kind");
  if (!Number.isInteger(minutes) || minutes <= 0) throw new HttpError(400, "invalid_minutes");
  if (!Number.isInteger(price) || price < 0) throw new HttpError(400, "invalid_price");
  const studio = await env.DB.prepare("SELECT id FROM studios WHERE id = ?").bind(studioId).first();
  if (!studio) throw new HttpError(404, "studio_not_found");

  const fixed = str(b.code, 4);
  if (fixed && !isFourDigitCode(fixed)) throw new HttpError(400, "invalid_code");
  const count = fixed ? 1 : Math.min(100, Math.max(1, Number(b.count ?? 1) | 0));
  const active = await env.DB.prepare("SELECT code FROM package_codes WHERE studio_id = ? AND status = 'active'")
    .bind(studioId).all<{ code: string }>();
  const taken = new Set((active.results ?? []).map((r) => r.code));
  if (fixed && taken.has(fixed)) throw new HttpError(409, "code_exists", "Mã này đang hoạt động trong studio");

  const now = nowIso();
  const created: Array<Record<string, unknown>> = [];
  const stmts: D1PreparedStatement[] = [];
  for (let i = 0; i < count; i++) {
    const code = fixed || await randomFreeCode(env, studioId, taken);
    taken.add(code);
    const id = newId();
    stmts.push(env.DB.prepare(
      `INSERT INTO package_codes (id, studio_id, code, kind, minutes, price_vnd, valid_from, valid_until, note, created_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
      .bind(id, studioId, code, kind, minutes, price, str(b.valid_from, 40) || null,
            str(b.valid_until, 40) || null, str(b.note, 200), now));
    created.push({ id, code, kind, minutes, price_vnd: price });
  }
  await env.DB.batch(stmts);
  return json({ success: true, codes: created }, 201);
}

// GET /v1/admin/studios/{studio_id}/codes?status=active|used|revoked
export async function handleAdminListCodes(env: Env, studioId: string, url: URL): Promise<Response> {
  const status = url.searchParams.get("status");
  const rs = status
    ? await env.DB.prepare(
        `SELECT id, code, kind, minutes, price_vnd, status, valid_from, valid_until, note, created_at, used_at,
                used_machine_id, used_session_id
           FROM package_codes WHERE studio_id = ? AND status = ? ORDER BY created_at DESC LIMIT 500`)
        .bind(studioId, status).all()
    : await env.DB.prepare(
        `SELECT id, code, kind, minutes, price_vnd, status, valid_from, valid_until, note, created_at, used_at,
                used_machine_id, used_session_id
           FROM package_codes WHERE studio_id = ? ORDER BY created_at DESC LIMIT 500`)
        .bind(studioId).all();
  return json({ success: true, codes: rs.results ?? [] });
}

// POST /v1/admin/codes/{id}/revoke
export async function handleAdminRevokeCode(env: Env, codeId: string): Promise<Response> {
  const res = await env.DB.prepare("UPDATE package_codes SET status = 'revoked' WHERE id = ? AND status = 'active'")
    .bind(codeId).run();
  if ((res.meta.changes ?? 0) === 0) throw new HttpError(404, "code_not_active");
  return json({ success: true });
}

// GET /v1/admin/studios
export async function handleAdminListStudios(env: Env): Promise<Response> {
  const rs = await env.DB.prepare(
    `SELECT s.id, s.name, s.status, s.created_at,
            (SELECT COUNT(*) FROM machines m WHERE m.studio_id = s.id) AS machines,
            (SELECT email FROM studio_users u WHERE u.studio_id = s.id AND u.role = 'owner' LIMIT 1) AS owner_email
       FROM studios s ORDER BY s.created_at DESC LIMIT 500`).all();
  return json({ success: true, studios: rs.results ?? [] });
}
