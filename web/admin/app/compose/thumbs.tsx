"use client";

/**
 * Small display copies of photos. The booth uploads full-size photos only (≈2.5 MB,
 * 24 MP each), and a grid of those makes phones crawl: every tile downloads and
 * decodes the whole photo. Here each photo is fetched once, shrunk off-screen, one or
 * two at a time, and shown from a small blob. For booth photos the small copy is
 * stored back to the gallery, so the next visit (and the next step of the flow) gets
 * it straight from the server.
 */

import { useEffect, useRef, useState } from "react";
import type { CaptureAsset } from "./flow";

/** Width of a generated thumbnail: sharp in a two-column phone grid at 3x. */
const THUMB_WIDTH = 720;
const THUMB_QUALITY = 0.82;
/** Width of the copy the editor shows in a slot; the print still uses the original. */
const SCREEN_WIDTH = 1600;
const SCREEN_QUALITY = 0.9;
/** Photos shrunk at the same time; more just competes for the phone's memory. */
const CONCURRENCY = 2;

const made = new Map<string, Promise<string>>();
const screens = new Map<string, Promise<string>>();
const waiting: Array<() => void> = [];
let running = 0;

function schedule<T>(job: () => Promise<T>): Promise<T> {
  return new Promise<T>((resolve, reject) => {
    const run = () => {
      running++;
      job().then(resolve, reject).finally(() => {
        running--;
        waiting.shift()?.();
      });
    };
    if (running < CONCURRENCY) run();
    else waiting.push(run);
  });
}

function loadElement(blob: Blob): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(blob);
    const image = new Image();
    image.onload = () => { URL.revokeObjectURL(url); resolve(image); };
    image.onerror = () => { URL.revokeObjectURL(url); reject(new Error("decode failed")); };
    image.src = url;
  });
}

/** Decode at reduced size where the browser can (no full 24 MP bitmap), else draw down. */
async function shrink(blob: Blob, targetWidth = THUMB_WIDTH, quality = THUMB_QUALITY): Promise<Blob> {
  let source: ImageBitmap | HTMLImageElement;
  try {
    source = await createImageBitmap(blob, { resizeWidth: targetWidth, resizeQuality: "medium" });
  } catch {
    source = await loadElement(blob);
  }
  const width = Math.min(targetWidth, source.width);
  const height = Math.max(1, Math.round(source.height * (width / source.width)));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("no canvas");
  ctx.drawImage(source, 0, 0, width, height);
  if ("close" in source) source.close();
  return new Promise((resolve, reject) => canvas.toBlob(
    (out) => (out ? resolve(out) : reject(new Error("encode failed"))), "image/jpeg", quality));
}

/** Store the small copy with the gallery; the first browser to make one wins. */
function storeThumbnail(token: string, asset: CaptureAsset, blob: Blob) {
  void fetch(`/v1/public/gallery/${encodeURIComponent(token)}/thumbnails/${encodeURIComponent(asset.asset_id)}`, {
    method: "PUT",
    headers: { "content-type": "image/jpeg" },
    body: blob,
  }).catch(() => undefined);
}

/** True when `thumbnail_url` already points at something small. */
function hasSmallCopy(asset: CaptureAsset) {
  return asset.kind === "video" || asset.has_thumbnail === true;
}

/** Object URL of a small copy of the photo (made once per page and photo). */
export function thumbnailFor(asset: CaptureAsset, token?: string): Promise<string> {
  const known = made.get(asset.asset_id);
  if (known) return known;
  const job = schedule(async () => {
    const response = await fetch(asset.url);
    if (!response.ok) throw new Error("download failed");
    const small = await shrink(await response.blob());
    if (token && asset.source !== "upload" && (asset.kind === "photo" || asset.kind === "collage")) storeThumbnail(token, asset, small);
    return URL.createObjectURL(small);
  });
  made.set(asset.asset_id, job);
  job.catch(() => made.delete(asset.asset_id));
  return job;
}

/**
 * Object URL of a screen-size copy (SCREEN_WIDTH) for the editor: a 24 MP photo in each
 * of a dozen slots would decode to over a gigabyte on a phone.
 */
export function screenCopyFor(asset: CaptureAsset): Promise<string> {
  const known = screens.get(asset.asset_id);
  if (known) return known;
  const job = schedule(async () => {
    const response = await fetch(asset.preview_url || asset.url);
    if (!response.ok) throw new Error("download failed");
    return URL.createObjectURL(await shrink(await response.blob(), SCREEN_WIDTH, SCREEN_QUALITY));
  });
  screens.set(asset.asset_id, job);
  job.catch(() => screens.delete(asset.asset_id));
  return job;
}

/**
 * A photo tile image that never puts the full-size photo in the grid. The small copy
 * is only made once the tile is near the screen.
 */
export function Thumb({ asset, token, eager = false, onError }: {
  asset: CaptureAsset;
  token?: string;
  eager?: boolean;
  /** The image failed to load, most likely an expired link: lets the page re-read the list. */
  onError?: () => void;
}) {
  const ref = useRef<HTMLImageElement | null>(null);
  const direct = hasSmallCopy(asset) ? asset.thumbnail_url || asset.preview_url || asset.url : "";
  const [near, setNear] = useState(eager);
  const [src, setSrc] = useState(direct);

  useEffect(() => {
    if (near || direct) return;
    const node = ref.current;
    if (!node || !("IntersectionObserver" in window)) {
      setNear(true);
      return;
    }
    const observer = new IntersectionObserver(([entry]) => {
      if (entry.isIntersecting) {
        setNear(true);
        observer.disconnect();
      }
    }, { rootMargin: "600px 0px" });
    observer.observe(node);
    return () => observer.disconnect();
  }, [direct, near]);

  useEffect(() => {
    if (direct) {
      setSrc(direct);
      return;
    }
    if (!near) return;
    let live = true;
    thumbnailFor(asset, token)
      .then((url) => { if (live) setSrc(url); })
      // Could not shrink it (old browser, odd file): show the photo itself.
      .catch(() => { if (live) setSrc(asset.preview_url || asset.url); });
    return () => { live = false; };
  }, [asset, direct, near, token]);

  return <img alt="" decoding="async" draggable={false} onError={onError} ref={ref} src={src || undefined} />;
}
