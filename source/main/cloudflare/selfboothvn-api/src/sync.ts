// Đồng bộ phiên chụp + doanh thu từ máy. App gửi qua outbox (có thể gửi lặp) nên
// mọi route ở đây idempotent.

import { Env, HttpError, int, isSafeId, json, nowIso, readJson, str } from "./http";
import { requireMachine } from "./auth";

// PUT /v1/machine/sessions/{session_id}
// Upsert theo (machine_id, session_id); bản có status_version cũ hơn bản đang lưu bị bỏ qua.
export async function handleSessionUpsert(req: Request, env: Env, sessionId: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const b = await readJson(req);
  const codeUseId = str(b.code_use_id, 64);
  if (codeUseId && !isSafeId(codeUseId, 8, 64)) throw new HttpError(400, "invalid_code_use_id");
  const now = nowIso();

  const res = await env.DB.prepare(
    `INSERT INTO capture_sessions (machine_id, session_id, studio_id, event_id, operation_mode, status,
       status_version, photos_count, expected_photos, started_at, ended_at, code_use_id, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(machine_id, session_id) DO UPDATE SET
       event_id        = excluded.event_id,
       operation_mode  = CASE WHEN excluded.operation_mode <> '' THEN excluded.operation_mode ELSE capture_sessions.operation_mode END,
       status          = excluded.status,
       status_version  = excluded.status_version,
       photos_count    = excluded.photos_count,
       expected_photos = excluded.expected_photos,
       started_at      = COALESCE(excluded.started_at, capture_sessions.started_at),
       ended_at        = COALESCE(excluded.ended_at, capture_sessions.ended_at),
       code_use_id     = COALESCE(excluded.code_use_id, capture_sessions.code_use_id),
       updated_at      = excluded.updated_at
     WHERE excluded.status_version >= capture_sessions.status_version`)
    .bind(
      caller.machineId, sessionId, caller.studioId, int(b.event_id), str(b.operation_mode, 20),
      str(b.status, 40), int(b.status_version), int(b.photos_count), int(b.expected_photos),
      str(b.started_at, 40) || null, str(b.ended_at, 40) || null, codeUseId || null, now, now)
    .run();
  return json({ success: true, applied: (res.meta.changes ?? 0) > 0 });
}

// POST /v1/machine/revenue — INSERT OR IGNORE theo revenue_id (app sinh, sha256 hex).
export async function handleRevenue(req: Request, env: Env): Promise<Response> {
  const caller = await requireMachine(req, env);
  const b = await readJson(req);
  const revenueId = str(b.revenue_id, 64);
  if (!/^[0-9a-f]{64}$/.test(revenueId)) throw new HttpError(400, "invalid_revenue_id");
  const recordedAt = str(b.recorded_at, 40);
  if (!recordedAt) throw new HttpError(400, "recorded_at_required");
  const sessionId = str(b.session_id, 100);
  if (sessionId && !isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const codeUseId = str(b.code_use_id, 64);
  if (codeUseId && !isSafeId(codeUseId, 8, 64)) throw new HttpError(400, "invalid_code_use_id");

  const res = await env.DB.prepare(
    `INSERT OR IGNORE INTO revenue_records (id, studio_id, machine_id, session_id, event_id, event_name,
       recorded_at, amount_required, received_amount, cash_received, transfer_amount, change_amount,
       voucher_amount, print_count, payment_method, source, note, code_use_id, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)`)
    .bind(
      revenueId, caller.studioId, caller.machineId, sessionId, int(b.event_id), str(b.event_name, 200),
      recordedAt, int(b.amount_required), int(b.received_amount), int(b.cash_received),
      int(b.transfer_amount), int(b.change_amount), int(b.voucher_amount), int(b.print_count),
      str(b.payment_method, 40), str(b.source, 40) || "session", str(b.note, 500), codeUseId || null, nowIso())
    .run();
  return json({ success: true, inserted: (res.meta.changes ?? 0) > 0 });
}
