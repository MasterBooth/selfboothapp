"use client";

/**
 * "Tải tất cả" on iPhone / iPad. Safari lets one tap start one download (the rest are
 * blocked) and puts downloads in Files, not Photos. The share sheet saves straight to
 * Photos, but `navigator.share` must run inside a tap — so originals are fetched first,
 * a batch at a time, and each batch is handed to the share sheet when the guest taps.
 */

import { type CaptureAsset, assetLabel } from "../compose/flow";

/** Kept small enough that a batch of full-size originals does not crash the Safari tab. */
const BATCH_FILES = 20;
const BATCH_BYTES = 120 * 1024 * 1024;
const PARALLEL = 3;

export function isIos() {
  if (typeof navigator === "undefined") return false;
  const ua = navigator.userAgent;
  // iPadOS reports itself as a Mac; touch gives it away.
  return /iP(hone|ad|od)/.test(ua) || (/Macintosh/.test(ua) && navigator.maxTouchPoints > 1);
}

/** The browser can hand image files to the share sheet (iOS 15+ Safari; not most in-app browsers). */
export function canShareFiles() {
  if (typeof navigator === "undefined" || !navigator.share || !navigator.canShare) return false;
  try {
    return navigator.canShare({ files: [new File([new Uint8Array(1)], "test.jpg", { type: "image/jpeg" })] });
  } catch {
    return false;
  }
}

/** Assets split into share batches by count and size (a batch always has at least one). */
export function shareBatches(assets: CaptureAsset[]) {
  const batches: CaptureAsset[][] = [];
  let current: CaptureAsset[] = [];
  let bytes = 0;
  for (const asset of assets) {
    const size = asset.size_bytes || 0;
    if (current.length > 0 && (current.length >= BATCH_FILES || bytes + size > BATCH_BYTES)) {
      batches.push(current);
      current = [];
      bytes = 0;
    }
    current.push(asset);
    bytes += size;
  }
  if (current.length > 0) batches.push(current);
  return batches;
}

function fileName(asset: CaptureAsset, index: number) {
  if (asset.file_name) return asset.file_name;
  const ext = asset.kind === "video" ? "mp4" : asset.content_type.includes("png") ? "png" : "jpg";
  return `${assetLabel(asset, index)}.${ext}`;
}

/**
 * The originals of one batch as files, untouched (no re-encode). Files that fail to load or
 * that the share sheet would refuse are counted in `failed`.
 */
export async function fetchBatch(
  batch: CaptureAsset[],
  firstIndex: number,
  signal: AbortSignal,
  onFile: () => void,
): Promise<{ files: File[]; failed: number }> {
  const files: (File | null)[] = new Array(batch.length).fill(null);
  let next = 0;
  const worker = async () => {
    while (next < batch.length) {
      const at = next++;
      const asset = batch[at];
      try {
        const response = await fetch(asset.url, { signal });
        if (!response.ok) throw new Error("download failed");
        const blob = await response.blob();
        const file = new File([blob], fileName(asset, firstIndex + at), { type: blob.type || asset.content_type || "image/jpeg" });
        if (navigator.canShare({ files: [file] })) files[at] = file;
      } catch (err) {
        if (signal.aborted) throw err;
      }
      onFile();
    }
  };
  await Promise.all(Array.from({ length: Math.min(PARALLEL, batch.length) }, worker));
  const ready = files.filter((file): file is File => file !== null);
  return { files: ready, failed: batch.length - ready.length };
}
