/**
 * Prints made in the web editor ("Ảnh đã ghép") are kept with the session on the server,
 * so every device sees them, the studio admin's too. The full-size PNG goes up as it is,
 * through the same upload as a print order. A print that could not be sent yet waits in
 * this browser (uploads.ts) and goes up the next time the gallery is opened here.
 */

import { apiSend } from "./flow";
import { composedRecords, removeComposed } from "./uploads";

export type UploadedPrint = { objectKey: string; shareUrl: string };

/** Asset id prefix of web prints on the server (booth collages never use it). */
export const WEB_COMPOSED_PREFIX = "web-";

export function isWebComposed(asset: { asset_id: string }) {
  return asset.asset_id.startsWith(WEB_COMPOSED_PREFIX);
}

function galleryPath(token: string) {
  return `/v1/public/gallery/${encodeURIComponent(token)}`;
}

async function sha256(blob: Blob) {
  const hash = await crypto.subtle.digest("SHA-256", await blob.arrayBuffer());
  return Array.from(new Uint8Array(hash)).map((byte) => byte.toString(16).padStart(2, "0")).join("");
}

/** Upload a print PNG to the studio; `onStep` follows the progress (step 0–2 of 3). */
export async function uploadPrintFile(
  token: string,
  blob: Blob,
  fileName: string,
  onStep?: (detail: string, step: number) => void,
): Promise<UploadedPrint> {
  onStep?.("Chuẩn bị ảnh in", 0);
  const checksum = await sha256(blob);
  onStep?.("Xin quyền tải ảnh", 1);
  const prepared = await apiSend<{ upload_url: string; object_key: string; share_url?: string }>(
    `${galleryPath(token)}/prints/prepare`,
    {
      file_name: fileName,
      content_type: blob.type || "image/png",
      size_bytes: blob.size,
      checksum_sha256: checksum,
    },
  );
  onStep?.("Tải ảnh in lên studio", 2);
  const upload = await fetch(prepared.upload_url, {
    method: "PUT",
    headers: { "content-type": blob.type || "image/png" },
    body: blob,
  });
  if (!upload.ok) throw new Error("Không tải được ảnh in lên máy chủ.");
  return { objectKey: prepared.object_key, shareUrl: prepared.share_url || "" };
}

/** List an uploaded print in the session's "Ảnh đã ghép". Sending the same `id` twice keeps one. */
export async function registerComposed(token: string, id: string, objectKey: string, fileName: string, createdAt?: string) {
  await apiSend(`${galleryPath(token)}/composed`, { id, object_key: objectKey, file_name: fileName, created_at: createdAt });
}

export async function deleteComposed(token: string, assetId: string) {
  const response = await fetch(`${galleryPath(token)}/composed/${encodeURIComponent(assetId)}`, {
    method: "DELETE",
    credentials: "include",
    cache: "no-store",
  });
  if (!response.ok) throw new Error("Không xóa được ảnh ghép.");
}

export function composedFileName(name: string, createdAt: string) {
  return `${name.replace(/[^\w.-]+/g, "-")}-${createdAt.slice(0, 10)}.png`;
}

const syncing = new Map<string, Promise<number>>();

/**
 * Send the prints still waiting in this browser, oldest first, and drop each local copy
 * once the server lists it. Stops at the first failure (tried again on the next visit).
 * Resolves with how many went up.
 */
export function syncComposed(token: string, scope: string): Promise<number> {
  if (!token) return Promise.resolve(0);
  const known = syncing.get(scope);
  if (known) return known;
  const job = (async () => {
    let sent = 0;
    for (const record of await composedRecords(scope)) {
      // The print endpoint takes PNG only; older JPEG entries stay in this browser.
      if (record.blob.type && record.blob.type !== "image/png") continue;
      try {
        const fileName = composedFileName(record.name, record.createdAt);
        const { objectKey } = await uploadPrintFile(token, record.blob, fileName);
        await registerComposed(token, record.id, objectKey, fileName, record.createdAt);
        await removeComposed(record.id).catch(() => undefined);
        sent++;
      } catch {
        break;
      }
    }
    return sent;
  })();
  syncing.set(scope, job);
  void job.finally(() => syncing.delete(scope));
  return job;
}
