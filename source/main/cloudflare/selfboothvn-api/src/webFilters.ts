// Studio colour-filter library (3D LUT .cube + thumbnail) for the browser admin and
// the guest photo editor.
//
//   GET    /v1/web/filters          list active filters (signed cube + thumbnail URLs)
//   POST   /v1/web/filters          multipart: file (.cube), name, thumbnail (image, optional)
//   PATCH  /v1/web/filters/:id      multipart or JSON: name and/or thumbnail
//   DELETE /v1/web/filters/:id

import { Env, HttpError, isSafeId, json, newId, nowIso, readJson, str } from "./http";
import { requirePermission } from "./webAuth";
import { READ_FILTERS } from "./permissions";
import { signedMediaUrl } from "./upload";

const FILTER_STORAGE_ROOT = "filters";
const MAX_CUBE_BYTES = 16 * 1024 * 1024;
const MAX_THUMB_BYTES = 2 * 1024 * 1024;
const MAX_FILTERS = 200;
const THUMB_TYPES: Record<string, string> = { "image/jpeg": "jpg", "image/png": "png", "image/webp": "webp" };

const FILTER_COLUMNS = `id, name, cube_object_key, cube_size_bytes, lut_size, thumbnail_object_key,
  sort_order, status, created_at, updated_at`;

/** Validate a .cube file: needs LUT_3D_SIZE N and exactly N³ "r g b" rows. Returns N. */
function validateCube(text: string): number {
  let size = 0;
  let rows = 0;
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const upper = line.slice(0, 12).toUpperCase();
    if (upper.startsWith("LUT_3D_SIZE")) {
      size = Number(line.split(/\s+/)[1]);
      continue;
    }
    if (upper.startsWith("LUT_1D_SIZE")) throw new HttpError(400, "cube_1d_not_supported", "Chỉ hỗ trợ LUT 3D (.cube)");
    if (/^[A-Z_]/i.test(line)) continue; // TITLE, DOMAIN_MIN, DOMAIN_MAX, ...
    const parts = line.split(/\s+/);
    if (parts.length < 3 || !parts.slice(0, 3).every((v) => Number.isFinite(Number(v)))) {
      throw new HttpError(400, "invalid_cube", "File .cube có dòng dữ liệu không hợp lệ");
    }
    rows++;
  }
  if (!Number.isInteger(size) || size < 2 || size > 128) {
    throw new HttpError(400, "invalid_cube", "File .cube thiếu hoặc sai LUT_3D_SIZE");
  }
  if (rows !== size ** 3) {
    throw new HttpError(400, "invalid_cube", `File .cube cần ${size ** 3} dòng màu, đang có ${rows}`);
  }
  return size;
}

function readThumbnail(value: unknown): File | null {
  if (!(value instanceof File) || value.size === 0) return null;
  if (!THUMB_TYPES[value.type]) throw new HttpError(400, "thumbnail_type_invalid", "Thumbnail phải là JPG, PNG hoặc WebP");
  if (value.size > MAX_THUMB_BYTES) throw new HttpError(400, "thumbnail_too_large", "Thumbnail tối đa 2MB");
  return value;
}

async function putThumbnail(env: Env, studioId: string, filterId: string, file: File): Promise<string> {
  // Versioned key so browsers and booths never show a cached old thumbnail.
  const key = `${FILTER_STORAGE_ROOT}/${studioId}/${filterId}/thumb-${Date.now()}.${THUMB_TYPES[file.type]}`;
  await env.MEDIA.put(key, await file.arrayBuffer(), {
    httpMetadata: { contentType: file.type },
    customMetadata: { studio_id: studioId, filter_id: filterId },
  });
  return key;
}

async function filterRowToJson(env: Env, origin: string, row: Record<string, string | number | null>) {
  const thumbKey = row.thumbnail_object_key ? String(row.thumbnail_object_key) : "";
  return {
    id: String(row.id),
    name: String(row.name),
    lut_size: Number(row.lut_size || 0),
    cube_size_bytes: Number(row.cube_size_bytes || 0),
    cube_object_key: String(row.cube_object_key),
    thumbnail_object_key: thumbKey,
    sort_order: Number(row.sort_order || 0),
    status: String(row.status || "active"),
    created_at: String(row.created_at || ""),
    updated_at: String(row.updated_at || ""),
    cube_url: await signedMediaUrl(env, origin, String(row.cube_object_key), 3600),
    thumbnail_url: thumbKey ? await signedMediaUrl(env, origin, thumbKey, 3600) : "",
  };
}

async function loadFilter(env: Env, studioId: string, filterId: string) {
  return env.DB.prepare(`SELECT ${FILTER_COLUMNS} FROM studio_filters WHERE id = ? AND studio_id = ?`)
    .bind(filterId, studioId).first<Record<string, string | number | null>>();
}

/** Active filters of one studio; shared by the admin and the public gallery. */
export async function listStudioFilters(env: Env, origin: string, studioId: string) {
  const rows = await env.DB.prepare(
    `SELECT ${FILTER_COLUMNS} FROM studio_filters
      WHERE studio_id = ? AND status = 'active'
      ORDER BY sort_order ASC, created_at ASC`)
    .bind(studioId).all<Record<string, string | number | null>>();
  return Promise.all((rows.results ?? []).map((row) => filterRowToJson(env, origin, row)));
}

export async function handleWebFilters(req: Request, env: Env, url: URL): Promise<Response> {
  const caller = await requirePermission(req, env, ...(req.method === "GET" ? READ_FILTERS : ["filters.upload"]));
  if (req.method === "GET") {
    const filters = await listStudioFilters(env, url.origin, caller.studioId);
    return json({ success: true, filters }, 200, { "cache-control": "no-store" });
  }

  const count = await env.DB.prepare("SELECT COUNT(*) AS n FROM studio_filters WHERE studio_id = ? AND status = 'active'")
    .bind(caller.studioId).first<{ n: number }>();
  if (Number(count?.n ?? 0) >= MAX_FILTERS) throw new HttpError(409, "filter_limit", `Tối đa ${MAX_FILTERS} bộ lọc`);

  const form = await req.formData();
  const file = form.get("file");
  if (!(file instanceof File) || file.size === 0) throw new HttpError(400, "cube_file_required", "Chọn file .cube");
  if (!/\.cube$/i.test(file.name)) throw new HttpError(400, "cube_extension", "Bộ lọc phải là file .cube");
  if (file.size > MAX_CUBE_BYTES) throw new HttpError(400, "cube_too_large", "File .cube tối đa 16MB");
  const text = await file.text();
  const lutSize = validateCube(text);
  const thumbnail = readThumbnail(form.get("thumbnail"));
  const name = str(form.get("name"), 80) || file.name.replace(/\.cube$/i, "") || "Bộ lọc";

  const id = newId();
  const cubeKey = `${FILTER_STORAGE_ROOT}/${caller.studioId}/${id}/filter.cube`;
  await env.MEDIA.put(cubeKey, text, {
    httpMetadata: { contentType: "text/plain; charset=utf-8" },
    customMetadata: { studio_id: caller.studioId, filter_id: id },
  });
  const thumbKey = thumbnail ? await putThumbnail(env, caller.studioId, id, thumbnail) : null;
  const order = await env.DB.prepare("SELECT COALESCE(MAX(sort_order), 0) + 1 AS n FROM studio_filters WHERE studio_id = ?")
    .bind(caller.studioId).first<{ n: number }>();
  const now = nowIso();
  await env.DB.prepare(
    `INSERT INTO studio_filters (id, studio_id, name, cube_object_key, cube_size_bytes, lut_size,
                                 thumbnail_object_key, sort_order, status, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 'active', ?, ?)`)
    .bind(id, caller.studioId, name, cubeKey, file.size, lutSize, thumbKey, Number(order?.n ?? 1), now, now).run();
  const row = await loadFilter(env, caller.studioId, id);
  return json({ success: true, filter: await filterRowToJson(env, url.origin, row!) }, 201);
}

export async function handleWebFilterDetail(req: Request, env: Env, url: URL, filterId: string): Promise<Response> {
  const caller = await requirePermission(req, env, req.method === "DELETE" ? "filters.delete" : "filters.edit");
  if (!isSafeId(filterId, 8, 64)) throw new HttpError(400, "invalid_filter_id");
  const current = await loadFilter(env, caller.studioId, filterId);
  if (!current) throw new HttpError(404, "filter_not_found");

  if (req.method === "DELETE") {
    const keys = [String(current.cube_object_key), current.thumbnail_object_key ? String(current.thumbnail_object_key) : ""].filter(Boolean);
    await Promise.all(keys.map((key) => env.MEDIA.delete(key)));
    await env.DB.prepare("DELETE FROM studio_filters WHERE id = ? AND studio_id = ?").bind(filterId, caller.studioId).run();
    return json({ success: true });
  }

  let name = "";
  let thumbnail: File | null = null;
  if ((req.headers.get("content-type") || "").includes("multipart/form-data")) {
    const form = await req.formData();
    name = str(form.get("name"), 80);
    thumbnail = readThumbnail(form.get("thumbnail"));
  } else {
    name = str((await readJson(req)).name, 80);
  }
  if (!name && !thumbnail) throw new HttpError(400, "nothing_to_update");

  let thumbKey: string | null = null;
  if (thumbnail) {
    thumbKey = await putThumbnail(env, caller.studioId, filterId, thumbnail);
    if (current.thumbnail_object_key) await env.MEDIA.delete(String(current.thumbnail_object_key));
  }
  await env.DB.prepare(
    `UPDATE studio_filters
        SET name = CASE WHEN ? <> '' THEN ? ELSE name END,
            thumbnail_object_key = COALESCE(?, thumbnail_object_key),
            updated_at = ?
      WHERE id = ? AND studio_id = ?`)
    .bind(name, name, thumbKey, nowIso(), filterId, caller.studioId).run();
  const row = await loadFilter(env, caller.studioId, filterId);
  return json({ success: true, filter: await filterRowToJson(env, url.origin, row!) });
}
