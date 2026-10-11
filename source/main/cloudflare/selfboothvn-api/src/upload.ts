// Upload ảnh/video lên R2 + xem lại qua /media.
//
//   POST /v1/uploads/presign  (machine) {object_key, content_type} -> {upload_url, public_url}
//   PUT  /v1/upload/object?...   (URL có chữ ký, hạn 15')  body = file -> ghi R2 + session_photos
//   GET  /v1/media/<object_key>  (công khai, hỗ trợ Range)
//
// Key bắt buộc: studio/<hwid của token>/<session_id>/<file...>. Worker ghi thẳng R2 qua
// binding nên không cần R2 API key ở đâu cả.

import { Env, HttpError, hmacHex, int, isSafeId, json, nowIso, randomToken, readJson, str, timingSafeEqual, toHex, corsHeaders } from "./http";
import { requireMachine } from "./auth";

const UPLOAD_URL_TTL_SECONDS = 900;
const MEDIA_CACHE_CONTROL = "public, max-age=31536000, immutable";
/** Signed media URLs only change once per this many seconds (see signedMediaUrl). */
const SIGNED_URL_BUCKET_SECONDS = 3600;
const MAX_KEY_LENGTH = 512;
const MAX_PREPARE_ASSETS = 50;
export const STORAGE_ROOT = "studio";

// Chặn path traversal, ký tự điều khiển, backslash, đoạn rỗng.
export function isSafeObjectKey(key: string): boolean {
  if (!key || key.length > MAX_KEY_LENGTH) return false;
  if (key.startsWith("/") || key.includes("\\") || key.includes("//")) return false;
  if (/[\u0000-\u001f\u007f]/.test(key)) return false;
  return key.split("/").every((seg) => seg !== "" && seg !== "." && seg !== "..");
}

function photoKind(key: string): string {
  const parts = key.split("/");
  const file = parts[parts.length - 1].toLowerCase();
  if (parts[3] === "photos") return "photo";
  if (file === "photos.json") return "manifest";
  if (file.startsWith("collage.")) return "collage";
  if (file.startsWith("video.")) return "video";
  return "other";
}

function signaturePayload(key: string, exp: number, ct: string, machineId: string, studioId: string): string {
  return [key, exp, ct, machineId, studioId].join("\n");
}

function assetSignaturePayload(key: string, exp: number, ct: string, machineId: string, studioId: string, assetId: string): string {
  return ["asset-v1", key, exp, ct, machineId, studioId, assetId].join("\n");
}

function mediaSignaturePayload(key: string, exp: number): string {
  return ["media-v1", key, exp].join("\n");
}

function hexToArrayBuffer(hex: string): ArrayBuffer | undefined {
  if (!/^[0-9a-f]{64}$/i.test(hex)) return undefined;
  const bytes = new Uint8Array(32);
  for (let i = 0; i < bytes.length; i++) bytes[i] = Number.parseInt(hex.slice(i * 2, i * 2 + 2), 16);
  return bytes.buffer;
}

function checksumHex(obj: R2Object | null): string {
  const sha = obj?.checksums?.sha256;
  if (!sha) return "";
  if (typeof sha === "string") return sha.toLowerCase();
  return toHex(sha);
}

function safeFileName(v: unknown): string {
  const name = str(v, 180).replace(/\\/g, "/").split("/").pop() ?? "";
  return (name || "asset.bin").replace(/[^A-Za-z0-9._-]/g, "_").slice(0, 180);
}

function safeKind(v: unknown): string {
  const kind = str(v, 20) || "other";
  return ["photo", "collage", "video", "manifest", "thumbnail", "preview", "other"].includes(kind)
    ? kind
    : "other";
}

function assertChecksum(v: unknown): string {
  const checksum = str(v, 80).toLowerCase();
  if (checksum && !/^[0-9a-f]{64}$/.test(checksum)) throw new HttpError(400, "invalid_checksum");
  return checksum;
}

function assetObjectKey(hwid: string, sessionId: string, assetId: string, kind: string, fileName: string, photoIndex: number): string {
  if (kind === "manifest") return `${STORAGE_ROOT}/${hwid}/${sessionId}/photos.json`;
  const folder = kind === "photo" ? "photos" : kind === "thumbnail" ? "thumbnails" : kind === "preview" ? "previews" : "assets";
  const order = String(Math.max(0, photoIndex)).padStart(4, "0");
  return `${STORAGE_ROOT}/${hwid}/${sessionId}/${folder}/${order}_${assetId}_${fileName}`;
}

export async function signedMediaUrl(env: Env, origin: string, objectKey: string, ttlSeconds = 600): Promise<string> {
  const secret = (env.UPLOAD_SIGNING_SECRET ?? "").trim();
  if (!secret) throw new HttpError(500, "upload_signing_not_configured");
  // Round the expiry up to the hour: every call within that hour returns the same URL, so
  // browsers reuse their cached copy (media is served immutable) instead of re-downloading
  // each photo whenever the gallery is re-read. Links stay valid for ttl to ttl + 1h.
  const exp = Math.ceil((Math.floor(Date.now() / 1000) + ttlSeconds) / SIGNED_URL_BUCKET_SECONDS) * SIGNED_URL_BUCKET_SECONDS;
  const sig = await hmacHex(secret, mediaSignaturePayload(objectKey, exp));
  const encoded = objectKey.split("/").map(encodeURIComponent).join("/");
  return `${origin}/v1/media/${encoded}?exp=${exp}&sig=${sig}`;
}

export async function ensureGalleryToken(env: Env, machineId: string, sessionId: string): Promise<string> {
  const current = await env.DB.prepare(
    "SELECT gallery_token FROM capture_sessions WHERE machine_id = ? AND session_id = ?")
    .bind(machineId, sessionId).first<{ gallery_token: string | null }>();
  if (current?.gallery_token) return current.gallery_token;
  const token = randomToken("gal_");
  await env.DB.prepare("UPDATE capture_sessions SET gallery_token = ?, updated_at = ? WHERE machine_id = ? AND session_id = ?")
    .bind(token, nowIso(), machineId, sessionId).run();
  return token;
}

async function verifyMediaSignature(env: Env, key: string, url: URL): Promise<boolean> {
  const secret = (env.UPLOAD_SIGNING_SECRET ?? "").trim();
  const exp = Number(url.searchParams.get("exp") ?? 0);
  const sig = url.searchParams.get("sig") ?? "";
  if (!secret || !sig || !(exp > 0)) return false;
  if (Math.floor(Date.now() / 1000) > exp) return false;
  const expected = await hmacHex(secret, mediaSignaturePayload(key, exp));
  return timingSafeEqual(sig, expected);
}

export async function handlePresign(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requireMachine(req, env);
  const secret = (env.UPLOAD_SIGNING_SECRET ?? "").trim();
  if (!secret) throw new HttpError(500, "upload_signing_not_configured");

  const b = await readJson(req);
  const objectKey = str(b.object_key, MAX_KEY_LENGTH);
  const contentType = str(b.content_type, 100) || "application/octet-stream";
  if (!isSafeObjectKey(objectKey)) throw new HttpError(400, "invalid_object_key");
  const parts = objectKey.split("/");
  if (parts.length < 4 || parts[0] !== STORAGE_ROOT || !isSafeId(parts[2])) {
    throw new HttpError(400, "invalid_object_key");
  }
  if (parts[1] !== caller.hwid) throw new HttpError(403, "object_key_prefix_mismatch");

  const exp = Math.floor(Date.now() / 1000) + UPLOAD_URL_TTL_SECONDS;
  const sig = await hmacHex(secret, signaturePayload(objectKey, exp, contentType, caller.machineId, caller.studioId));
  const q = new URLSearchParams({
    key: objectKey, exp: String(exp), ct: contentType, m: caller.machineId, s: caller.studioId, sig,
  });
  const encodedKey = parts.map(encodeURIComponent).join("/");
  return json({
    success: true,
    upload_url: `${url.origin}/v1/upload/object?${q.toString()}`,
    public_url: `${url.origin}/v1/media/${encodedKey}`,
    object_key: objectKey,
    expires_at: new Date(exp * 1000).toISOString(),
  });
}

export async function handleUploadObject(req: Request, env: Env, url: URL): Promise<Response> {
  const secret = (env.UPLOAD_SIGNING_SECRET ?? "").trim();
  if (!secret) throw new HttpError(500, "upload_signing_not_configured");

  const p = url.searchParams;
  const key = p.get("key") ?? "";
  const exp = Number(p.get("exp") ?? 0);
  const ct = p.get("ct") ?? "";
  const machineId = p.get("m") ?? "";
  const studioId = p.get("s") ?? "";
  const assetId = p.get("a") ?? "";
  const sig = p.get("sig") ?? "";
  if (!isSafeObjectKey(key) || !ct || !sig || !machineId || !studioId || !(exp > 0)) {
    throw new HttpError(400, "invalid_upload_url");
  }
  if (Math.floor(Date.now() / 1000) > exp) throw new HttpError(403, "upload_url_expired");
  const expected = assetId
    ? await hmacHex(secret, assetSignaturePayload(key, exp, ct, machineId, studioId, assetId))
    : await hmacHex(secret, signaturePayload(key, exp, ct, machineId, studioId));
  if (!timingSafeEqual(sig, expected)) throw new HttpError(403, "invalid_signature");

  const reqType = (req.headers.get("content-type") ?? "").split(";")[0].trim();
  if (reqType !== ct) throw new HttpError(400, "content_type_mismatch");
  if (!req.body) throw new HttpError(400, "empty_body");
  if (!req.headers.get("content-length")) throw new HttpError(411, "length_required");

  const length = Number(req.headers.get("content-length") ?? 0);
  if (assetId) {
    const asset = await env.DB.prepare(
      `SELECT size_bytes, checksum_sha256, status FROM session_assets
        WHERE asset_id = ? AND object_key = ? AND machine_id = ? AND studio_id = ?`)
      .bind(assetId, key, machineId, studioId).first<{ size_bytes: number; checksum_sha256: string; status: string }>();
    if (!asset) throw new HttpError(404, "asset_not_prepared");
    if (asset.status === "committed") return json({ success: true, object_key: key, size_bytes: asset.size_bytes, already_committed: true });
    if (Number(asset.size_bytes) !== length) throw new HttpError(400, "size_mismatch");
  }

  const prepared = assetId
    ? await env.DB.prepare(
      "SELECT checksum_sha256 FROM session_assets WHERE asset_id = ? AND object_key = ? AND machine_id = ? AND studio_id = ?")
      .bind(assetId, key, machineId, studioId).first<{ checksum_sha256: string }>()
    : null;
  const checksum = prepared?.checksum_sha256 ?? "";
  const obj = await env.MEDIA.put(key, req.body, {
    httpMetadata: { contentType: ct },
    customMetadata: assetId ? { asset_id: assetId, checksum_sha256: checksum } : undefined,
    ...(checksum ? { sha256: hexToArrayBuffer(checksum) } : {}),
  } as R2PutOptions);
  if (!obj) throw new HttpError(500, "upload_failed");

  if (assetId) {
    await env.DB.prepare(
      `UPDATE session_assets SET status = 'uploaded', uploaded_size_bytes = ?, r2_checksum_sha256 = ?,
          uploaded_at = ?, updated_at = ?, error_code = ''
        WHERE asset_id = ? AND object_key = ? AND machine_id = ? AND studio_id = ?`)
      .bind(obj.size, checksumHex(obj), nowIso(), nowIso(), assetId, key, machineId, studioId).run();
    return json({ success: true, object_key: key, asset_id: assetId, etag: obj.httpEtag, size_bytes: obj.size });
  }

  // Ghi metadata ảnh phiên (server xác nhận object đã có trên R2). Upload lại cùng key
  // -> cập nhật kích thước/thời điểm, không nhân bản bản ghi.
  await env.DB.prepare(
    `INSERT INTO session_photos (object_key, studio_id, machine_id, session_id, kind, content_type, size_bytes, uploaded_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?)
     ON CONFLICT(object_key) DO UPDATE SET content_type = excluded.content_type,
       size_bytes = excluded.size_bytes, uploaded_at = excluded.uploaded_at`)
    .bind(key, studioId, machineId, key.split("/")[2], photoKind(key), ct, obj.size, nowIso()).run();

  return json({ success: true, object_key: key, etag: obj.httpEtag, size_bytes: obj.size });
}

export async function handlePrepareAssets(req: Request, env: Env, url: URL, sessionId: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const b = await readJson(req);
  const assets = Array.isArray(b.assets) ? b.assets.slice(0, MAX_PREPARE_ASSETS) : [];
  if (assets.length === 0) throw new HttpError(400, "assets_required");

  const secret = (env.UPLOAD_SIGNING_SECRET ?? "").trim();
  if (!secret) throw new HttpError(500, "upload_signing_not_configured");
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO capture_sessions (machine_id, session_id, studio_id, status, status_version, photos_count, expected_photos, created_at, updated_at, gallery_token)
     VALUES (?, ?, ?, 'capturing', 0, 0, 0, ?, ?, ?)
     ON CONFLICT(machine_id, session_id) DO UPDATE SET updated_at = excluded.updated_at`)
    .bind(caller.machineId, sessionId, caller.studioId, now, now, randomToken("gal_")).run();
  await ensureGalleryToken(env, caller.machineId, sessionId);

  const prepared: Array<Record<string, unknown>> = [];
  const stmts: D1PreparedStatement[] = [];
  for (const raw of assets) {
    const item = raw && typeof raw === "object" ? raw as Record<string, unknown> : {};
    const assetId = str(item.asset_id, 100);
    if (!isSafeId(assetId, 8, 100)) throw new HttpError(400, "invalid_asset_id");
    const kind = safeKind(item.kind);
    const fileName = safeFileName(item.file_name);
    const contentType = str(item.content_type, 100) || "application/octet-stream";
    const sizeBytes = int(item.size_bytes);
    if (sizeBytes <= 0) throw new HttpError(400, "invalid_size");
    const checksum = assertChecksum(item.checksum_sha256);
    const photoIndex = int(item.photo_index);
    const objectKey = assetObjectKey(caller.hwid, sessionId, assetId, kind, fileName, photoIndex);
    const exp = Math.floor(Date.now() / 1000) + UPLOAD_URL_TTL_SECONDS;
    const sig = await hmacHex(secret, assetSignaturePayload(objectKey, exp, contentType, caller.machineId, caller.studioId, assetId));
    const uploadUrl = `${url.origin}/v1/upload/object?${new URLSearchParams({
      key: objectKey, exp: String(exp), ct: contentType, m: caller.machineId, s: caller.studioId, a: assetId, sig,
    }).toString()}`;
    const expiresAt = new Date(exp * 1000).toISOString();
    stmts.push(env.DB.prepare(
      `INSERT INTO session_assets (asset_id, machine_id, session_id, studio_id, object_key, kind, file_name,
          content_type, size_bytes, checksum_sha256, photo_index, status, upload_expires_at, created_at, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, 'prepared', ?, ?, ?)
       ON CONFLICT(machine_id, session_id, asset_id) DO UPDATE SET
          object_key = excluded.object_key,
          kind = excluded.kind,
          file_name = excluded.file_name,
          content_type = excluded.content_type,
          size_bytes = excluded.size_bytes,
          checksum_sha256 = excluded.checksum_sha256,
          photo_index = excluded.photo_index,
          upload_expires_at = excluded.upload_expires_at,
          updated_at = excluded.updated_at
        WHERE session_assets.status <> 'committed'`)
      .bind(assetId, caller.machineId, sessionId, caller.studioId, objectKey, kind, fileName, contentType,
            sizeBytes, checksum, photoIndex, expiresAt, now, now));
    prepared.push({ asset_id: assetId, object_key: objectKey, upload_url: uploadUrl, expires_at: expiresAt, status: "prepared" });
  }
  await env.DB.batch(stmts);
  // An asset already committed (e.g. a thumbnail a guest's browser stored first) is
  // reported as such with its stored key, so the booth can mark it done instead of
  // uploading to a key that row does not have. The upload URL stays for older apps.
  const ids = prepared.map((item) => String(item.asset_id));
  const stored = await env.DB.prepare(
    `SELECT asset_id, object_key FROM session_assets
      WHERE machine_id = ? AND session_id = ? AND status = 'committed' AND asset_id IN (${ids.map(() => "?").join(",")})`)
    .bind(caller.machineId, sessionId, ...ids).all<{ asset_id: string; object_key: string }>();
  const committedKeys = new Map((stored.results ?? []).map((row) => [row.asset_id, row.object_key]));
  for (const item of prepared) {
    const key = committedKeys.get(String(item.asset_id));
    if (key) Object.assign(item, { status: "committed", object_key: key });
  }
  return json({ success: true, assets: prepared }, 201, { "cache-control": "no-store" });
}

export async function handleCommitAssets(req: Request, env: Env, sessionId: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const b = await readJson(req);
  const assets = Array.isArray(b.assets) ? b.assets.slice(0, MAX_PREPARE_ASSETS) : [];
  if (assets.length === 0) throw new HttpError(400, "assets_required");

  const committed: Array<Record<string, unknown>> = [];
  const missing: string[] = [];
  for (const raw of assets) {
    const assetId = str((raw as Record<string, unknown>)?.asset_id, 100);
    if (!isSafeId(assetId, 8, 100)) throw new HttpError(400, "invalid_asset_id");
    const asset = await env.DB.prepare(
      `SELECT asset_id, object_key, kind, content_type, size_bytes, checksum_sha256, photo_index, status
         FROM session_assets
        WHERE asset_id = ? AND machine_id = ? AND session_id = ? AND studio_id = ?`)
      .bind(assetId, caller.machineId, sessionId, caller.studioId).first<Record<string, string | number>>();
    if (!asset) throw new HttpError(404, "asset_not_found");
    const obj = await env.MEDIA.head(String(asset.object_key));
    if (!obj) {
      missing.push(assetId);
      await env.DB.prepare(
        "UPDATE session_assets SET status = 'prepared', error_code = 'object_missing', updated_at = ? WHERE asset_id = ? AND machine_id = ? AND session_id = ?")
        .bind(nowIso(), assetId, caller.machineId, sessionId).run();
      continue;
    }
    if (obj.size !== Number(asset.size_bytes)) {
      await env.DB.prepare(
        "UPDATE session_assets SET status = 'failed', error_code = 'size_mismatch', updated_at = ? WHERE asset_id = ? AND machine_id = ? AND session_id = ?")
        .bind(nowIso(), assetId, caller.machineId, sessionId).run();
      throw new HttpError(409, "size_mismatch");
    }
    const expectedChecksum = String(asset.checksum_sha256 ?? "");
    const storedChecksum = checksumHex(obj) || String(obj.customMetadata?.checksum_sha256 ?? "");
    if (expectedChecksum && storedChecksum && expectedChecksum !== storedChecksum.toLowerCase()) {
      await env.DB.prepare(
        "UPDATE session_assets SET status = 'failed', error_code = 'checksum_mismatch', updated_at = ? WHERE asset_id = ? AND machine_id = ? AND session_id = ?")
        .bind(nowIso(), assetId, caller.machineId, sessionId).run();
      throw new HttpError(409, "checksum_mismatch");
    }
    const now = nowIso();
    const stmts: D1PreparedStatement[] = [
      env.DB.prepare(
        `UPDATE session_assets SET status = 'committed', uploaded_size_bytes = ?, r2_checksum_sha256 = ?,
            committed_at = ?, updated_at = ?, error_code = ''
          WHERE asset_id = ? AND machine_id = ? AND session_id = ? AND studio_id = ?`)
        .bind(obj.size, storedChecksum, now, now, assetId, caller.machineId, sessionId, caller.studioId),
    ];
    // session_photos lists the session's own files; display copies (thumbnail / preview) are
    // not among them, and its kind CHECK would reject them.
    if (asset.kind !== "thumbnail" && asset.kind !== "preview") {
      stmts.push(env.DB.prepare(
        `INSERT INTO session_photos (object_key, studio_id, machine_id, session_id, kind, content_type, size_bytes, uploaded_at)
         VALUES (?, ?, ?, ?, ?, ?, ?, ?)
         ON CONFLICT(object_key) DO UPDATE SET content_type = excluded.content_type,
           size_bytes = excluded.size_bytes, uploaded_at = excluded.uploaded_at`)
        .bind(String(asset.object_key), caller.studioId, caller.machineId, sessionId,
              String(asset.kind) as string, String(asset.content_type), obj.size, now));
    }
    await env.DB.batch(stmts);
    committed.push({ asset_id: assetId, status: "committed", object_key: asset.object_key, size_bytes: obj.size });
  }
  await refreshAssetSyncStatus(env, caller.machineId, caller.studioId, sessionId);
  return json({ success: true, assets: committed, missing }, 200, { "cache-control": "no-store" });
}

async function refreshAssetSyncStatus(env: Env, machineId: string, studioId: string, sessionId: string): Promise<void> {
  const expected = await env.DB.prepare(
    "SELECT asset_id FROM session_expected_assets WHERE machine_id = ? AND session_id = ? AND studio_id = ?")
    .bind(machineId, sessionId, studioId).all<{ asset_id: string }>();
  const ids = (expected.results ?? []).map((row) => row.asset_id);
  if (ids.length === 0) return;
  const committed = await env.DB.prepare(
    `SELECT COUNT(*) AS count FROM session_assets
      WHERE machine_id = ? AND session_id = ? AND studio_id = ? AND status = 'committed'
        AND asset_id IN (${ids.map(() => "?").join(",")})`)
    .bind(machineId, sessionId, studioId, ...ids).first<{ count: number }>();
  const syncStatus = Number(committed?.count ?? 0) === ids.length ? "synced" : "partial";
  await env.DB.prepare(
    "UPDATE capture_sessions SET asset_sync_status = ?, updated_at = ? WHERE machine_id = ? AND session_id = ? AND studio_id = ?")
    .bind(syncStatus, nowIso(), machineId, sessionId, studioId).run();
}

export async function handleFinalizeAssets(req: Request, env: Env, sessionId: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const b = await readJson(req);
  const expected = Array.isArray(b.expected_asset_ids) ? b.expected_asset_ids.map((v) => str(v, 100)).filter((v) => isSafeId(v, 8, 100)).slice(0, 1000) : [];
  const now = nowIso();
  const rows = await env.DB.prepare(
    `SELECT asset_id, status FROM session_assets WHERE machine_id = ? AND session_id = ?`)
    .bind(caller.machineId, sessionId).all<{ asset_id: string; status: string }>();
  const committedIds = new Set((rows.results ?? []).filter((row) => row.status === "committed").map((row) => row.asset_id));
  const committedExpected = expected.filter((assetId) => committedIds.has(assetId)).length;
  const syncStatus = expected.length === 0 ? "unknown" : (committedExpected === expected.length ? "synced" : "partial");
  // Status and photo counts belong to PUT /v1/machine/sessions/:id, which checks
  // status_version. Finalize only fills them in when it creates the row.
  const stmts: D1PreparedStatement[] = [
    env.DB.prepare(
      `INSERT INTO capture_sessions (machine_id, session_id, studio_id, event_id, operation_mode, status,
         status_version, photos_count, expected_photos, started_at, ended_at, created_at, updated_at,
         expected_asset_ids, asset_sync_status, finalized_at, gallery_token)
       VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
       ON CONFLICT(machine_id, session_id) DO UPDATE SET
         expected_asset_ids = excluded.expected_asset_ids,
         asset_sync_status = excluded.asset_sync_status,
         finalized_at = excluded.finalized_at,
         updated_at = excluded.updated_at`)
      .bind(caller.machineId, sessionId, caller.studioId, int(b.event_id), str(b.operation_mode, 20),
            str(b.status, 40) || "finished", int(b.status_version), int(b.photos_count),
            int(b.expected_photos, expected.length), str(b.started_at, 40) || null,
            str(b.ended_at, 40) || now, now, now, JSON.stringify(expected), syncStatus, now, randomToken("gal_")),
  ];
  for (const assetId of expected) {
    stmts.push(env.DB.prepare(
      `INSERT OR IGNORE INTO session_expected_assets (machine_id, session_id, asset_id, studio_id, expected_at)
       VALUES (?, ?, ?, ?, ?)`)
      .bind(caller.machineId, sessionId, assetId, caller.studioId, now));
  }
  await env.DB.batch(stmts);
  await ensureGalleryToken(env, caller.machineId, sessionId);
  return handleReconcileAssets(req, env, sessionId);
}

export async function handleReconcileAssets(req: Request, env: Env, sessionId: string): Promise<Response> {
  const caller = await requireMachine(req, env);
  if (!isSafeId(sessionId, 1, 100)) throw new HttpError(400, "invalid_session_id");
  const expected = await env.DB.prepare(
    `SELECT e.asset_id, COALESCE(a.status, 'missing') AS status, a.object_key, a.kind, a.photo_index
       FROM session_expected_assets e
       LEFT JOIN session_assets a
         ON a.machine_id = e.machine_id AND a.session_id = e.session_id AND a.asset_id = e.asset_id
      WHERE e.machine_id = ? AND e.session_id = ? AND e.studio_id = ?
      ORDER BY COALESCE(a.photo_index, 999999), e.asset_id`)
    .bind(caller.machineId, sessionId, caller.studioId).all<Record<string, string | number>>();
  const rows = expected.results ?? [];
  return json({
    success: true,
    committed: rows.filter((r) => r.status === "committed"),
    pending: rows.filter((r) => r.status !== "committed" && r.status !== "missing"),
    missing: rows.filter((r) => r.status === "missing").map((r) => r.asset_id),
  }, 200, { "cache-control": "no-store" });
}

export async function handleMedia(req: Request, env: Env, url: URL, ctx?: ExecutionContext): Promise<Response> {
  let key: string;
  try {
    key = decodeURIComponent(url.pathname.replace(/^\/v1\/media\/?/, "").replace(/^\/media\/?/, ""));
  } catch {
    throw new HttpError(400, "invalid_object_key");
  }
  if (!isSafeObjectKey(key)) throw new HttpError(400, "invalid_object_key");

  const protectedAsset = await env.DB.prepare("SELECT 1 FROM session_assets WHERE object_key = ? LIMIT 1")
    .bind(key).first();
  if (protectedAsset && !await verifyMediaSignature(env, key, url)) {
    throw new HttpError(403, "media_signature_required");
  }

  // Session photos never change once committed. After the signature check they are served
  // from Cloudflare's edge cache, keyed by object key (not by the hourly signed URL), so a
  // 20 MB original is read from R2 once per data centre instead of on every view. Only
  // verified session assets use it: a key without a session_assets row never reaches the cache.
  const rangeHeader = req.headers.get("range");
  const edgeCache = protectedAsset && req.method === "GET" ? caches.default : null;
  const cacheKey = `${url.origin}/v1/media-cache/${key.split("/").map(encodeURIComponent).join("/")}`;
  if (edgeCache) {
    const hit = await edgeCache.match(rangeHeader ? new Request(cacheKey, { headers: { range: rangeHeader } }) : cacheKey);
    if (hit) return hit;
  }

  const obj = await env.MEDIA.get(key, rangeHeader ? { range: req.headers } : undefined);
  if (!obj) throw new HttpError(404, "media_not_found");

  const headers = new Headers(corsHeaders);
  obj.writeHttpMetadata(headers);
  headers.set("etag", obj.httpEtag);
  headers.set("accept-ranges", "bytes");
  headers.set("cache-control", MEDIA_CACHE_CONTROL);

  let status = 200;
  const r = obj.range as { offset?: number; length?: number; suffix?: number } | undefined;
  if (rangeHeader && r) {
    const offset = r.suffix !== undefined ? Math.max(0, obj.size - r.suffix) : (r.offset ?? 0);
    const length = r.suffix !== undefined ? Math.min(r.suffix, obj.size) : (r.length ?? obj.size - offset);
    status = 206;
    headers.set("content-range", `bytes ${offset}-${offset + length - 1}/${obj.size}`);
    headers.set("content-length", String(length));
  } else {
    headers.set("content-length", String(obj.size));
  }
  const body = req.method === "HEAD" || !("body" in obj) ? null : (obj as R2ObjectBody).body;
  const response = new Response(body, { status, headers });
  // A partial (206) response cannot be stored; the next full read fills the cache.
  if (edgeCache && status === 200 && body && ctx) ctx.waitUntil(edgeCache.put(cacheKey, response.clone()));
  return response;
}
