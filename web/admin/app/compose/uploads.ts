/**
 * Guest uploads, kept in this browser's IndexedDB per capture session so a photo added
 * on any step (gallery, photo picker, editor) is still there on the next page and
 * after a reload. Blob URLs die with the page, so every page re-creates them from here.
 */

import type { CaptureAsset } from "./flow";

const DB_NAME = "selfbooth-uploads";
const STORE = "files";
/** Prints the guest made in the editor ("Ảnh đã ghép"), per session like the uploads. */
const COMPOSED_STORE = "composed";
const KEEP_DAYS = 7;
export const UPLOAD_PREFIX = "upload-";

type StoredUpload = {
  id: string;
  scope: string;
  name: string;
  type: string;
  size: number;
  createdAt: string;
  blob: Blob;
};

export function uploadScope(ctx: { token?: string; machineId?: string; sessionId?: string }) {
  if (ctx.token) return `t:${ctx.token}`;
  return ctx.machineId && ctx.sessionId ? `${ctx.machineId}/${ctx.sessionId}` : "local";
}

let dbPromise: Promise<IDBDatabase> | null = null;

function openDb(): Promise<IDBDatabase> {
  if (dbPromise) return dbPromise;
  dbPromise = new Promise((resolve, reject) => {
    const request = indexedDB.open(DB_NAME, 2);
    request.onupgradeneeded = () => {
      const db = request.result;
      for (const name of [STORE, COMPOSED_STORE]) {
        if (db.objectStoreNames.contains(name)) continue;
        const store = db.createObjectStore(name, { keyPath: "id" });
        store.createIndex("scope", "scope");
        store.createIndex("createdAt", "createdAt");
      }
    };
    request.onsuccess = () => resolve(request.result);
    request.onerror = () => {
      dbPromise = null;
      reject(request.error ?? new Error("Trình duyệt không cho lưu ảnh"));
    };
  });
  return dbPromise;
}

function run<T>(mode: IDBTransactionMode, work: (store: IDBObjectStore) => IDBRequest<T> | void, storeName = STORE): Promise<T | undefined> {
  return openDb().then((db) => new Promise<T | undefined>((resolve, reject) => {
    const tx = db.transaction(storeName, mode);
    const request = work(tx.objectStore(storeName));
    tx.oncomplete = () => resolve(request ? request.result : undefined);
    tx.onerror = () => reject(tx.error ?? new Error("Không lưu được ảnh"));
    tx.onabort = () => reject(tx.error ?? new Error("Bộ nhớ trình duyệt đã đầy"));
  }));
}

function toAsset(record: StoredUpload, index: number): CaptureAsset {
  const url = URL.createObjectURL(record.blob);
  return {
    asset_id: `${UPLOAD_PREFIX}${record.id}`,
    kind: "upload",
    file_name: record.name,
    content_type: record.type,
    size_bytes: record.size,
    photo_index: index + 1,
    committed_at: record.createdAt,
    url,
    thumbnail_url: url,
    preview_url: url,
    source: "upload",
  };
}

/** Uploads for one session, oldest first, with fresh object URLs (caller revokes them). */
export async function loadUploads(scope: string): Promise<CaptureAsset[]> {
  try {
    const records = await run<StoredUpload[]>("readonly", (store) => store.index("scope").getAll(scope));
    return (records ?? [])
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
      .map(toAsset);
  } catch {
    return [];
  }
}

/** Persist files for a session and return them as assets. Throws if storage is unavailable. */
export async function saveUploads(scope: string, files: File[], startIndex = 0): Promise<CaptureAsset[]> {
  const now = Date.now();
  const records: StoredUpload[] = files.map((file, index) => ({
    id: crypto.randomUUID(),
    scope,
    name: file.name,
    type: file.type || "image/jpeg",
    size: file.size,
    // Spread timestamps so a multi-file pick keeps its order.
    createdAt: new Date(now + index).toISOString(),
    blob: file,
  }));
  await run("readwrite", (store) => {
    records.forEach((record) => store.put(record));
  });
  return records.map((record, index) => toAsset(record, startIndex + index));
}

export async function removeUpload(assetId: string) {
  if (!assetId.startsWith(UPLOAD_PREFIX)) return;
  await run("readwrite", (store) => store.delete(assetId.slice(UPLOAD_PREFIX.length)));
}

/**
 * Re-create URLs for uploaded assets carried over from an earlier page.
 * Assets that are no longer stored are dropped.
 */
export async function reviveUploads(assets: CaptureAsset[]): Promise<CaptureAsset[]> {
  const ids = assets.filter((asset) => asset.asset_id.startsWith(UPLOAD_PREFIX));
  if (ids.length === 0) return assets;
  let records: Array<StoredUpload | undefined> = [];
  try {
    records = await Promise.all(ids.map((asset) =>
      run<StoredUpload>("readonly", (store) => store.get(asset.asset_id.slice(UPLOAD_PREFIX.length)))));
  } catch {
    records = [];
  }
  const byId = new Map(records.filter((r): r is StoredUpload => Boolean(r)).map((r) => [`${UPLOAD_PREFIX}${r.id}`, r]));
  return assets.flatMap((asset, index) => {
    if (!asset.asset_id.startsWith(UPLOAD_PREFIX)) return [asset];
    const record = byId.get(asset.asset_id);
    return record ? [{ ...toAsset(record, index), photo_index: asset.photo_index }] : [];
  });
}

/** Drop uploads older than KEEP_DAYS so the browser store does not grow forever. */
export async function pruneUploads() {
  const cutoff = new Date(Date.now() - KEEP_DAYS * 24 * 60 * 60 * 1000).toISOString();
  for (const storeName of [STORE, COMPOSED_STORE]) {
    try {
      await run("readwrite", (store) => {
        const request = store.index("createdAt").openCursor(IDBKeyRange.upperBound(cutoff));
        request.onsuccess = () => {
          const cursor = request.result;
          if (!cursor) return;
          cursor.delete();
          cursor.continue();
        };
      }, storeName);
    } catch {
      // Storage unavailable: nothing to prune.
    }
  }
}

type StoredComposed = {
  id: string;
  scope: string;
  name: string;
  width: number;
  height: number;
  createdAt: string;
  blob: Blob;
};

export type ComposedImage = Omit<StoredComposed, "blob" | "scope"> & { url: string; size: number; type: string };

/**
 * Keep a print the guest made until it is on the server (composedPrints.ts), so it still
 * shows on the "Ảnh đã ghép" page if sending fails or the page closes first. Returns its id.
 */
export async function saveComposed(scope: string, blob: Blob, meta: { name: string; width: number; height: number }) {
  const record: StoredComposed = { id: crypto.randomUUID(), scope, createdAt: new Date().toISOString(), blob, ...meta };
  await run("readwrite", (store) => { store.put(record); }, COMPOSED_STORE);
  return record.id;
}

/** This session's prints still kept in the browser, oldest first, with their files. */
export async function composedRecords(scope: string): Promise<Array<Omit<StoredComposed, "scope">>> {
  try {
    const records = await run<StoredComposed[]>("readonly", (store) => store.index("scope").getAll(scope), COMPOSED_STORE);
    return (records ?? [])
      .sort((a, b) => a.createdAt.localeCompare(b.createdAt))
      .map(({ scope: _scope, ...rest }) => rest);
  } catch {
    return [];
  }
}

/** This session's prints, newest first, with fresh object URLs (caller revokes them). */
export async function loadComposed(scope: string): Promise<ComposedImage[]> {
  try {
    const records = await run<StoredComposed[]>("readonly", (store) => store.index("scope").getAll(scope), COMPOSED_STORE);
    return (records ?? [])
      .sort((a, b) => b.createdAt.localeCompare(a.createdAt))
      .map(({ blob, scope: _scope, ...rest }) => ({ ...rest, url: URL.createObjectURL(blob), size: blob.size, type: blob.type }));
  } catch {
    return [];
  }
}

export async function countComposed(scope: string): Promise<number> {
  try {
    return (await run<number>("readonly", (store) => store.index("scope").count(scope), COMPOSED_STORE)) ?? 0;
  } catch {
    return 0;
  }
}

export async function removeComposed(id: string) {
  await run("readwrite", (store) => store.delete(id), COMPOSED_STORE);
}
