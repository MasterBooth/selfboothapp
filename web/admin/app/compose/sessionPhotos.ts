"use client";

/**
 * Every photo of a capture session, for the gallery and the photo picker.
 *
 * All pages are read one after another (the first shows as soon as it arrives), so a guest
 * never stops at the first page. While the server says the booth is still sending, the
 * first page is re-read for the totals and the list is re-read when they grow. Signed
 * links last 2–3 h; the list is re-read before handing out links older than that, or when
 * an image fails to load.
 */

import { useCallback, useEffect, useRef, useState } from "react";
import { type ApiError, type CaptureAsset, type GalleryPayload, apiJson, isJsonAsset } from "./flow";

/** Largest page the API serves. */
const PAGE_SIZE = 100;
/** Re-check while the booth is sending: quickly at first, slower when nothing changes. */
const POLL_FIRST_MS = 4000;
const POLL_MAX_MS = 15000;
/** Stop checking after this long, whatever the server says. */
const POLL_TOTAL_MS = 30 * 60 * 1000;
/** Links are signed for at least 2 h; read them again well before that. */
const LINKS_FRESH_MS = 90 * 60 * 1000;
/** After an image fails, do not re-read the list more often than this. */
const ERROR_REFRESH_MS = 60 * 1000;

function captures(data: GalleryPayload): CaptureAsset[] {
  return data.assets.filter((asset) => !isJsonAsset(asset)).map((asset) => ({ ...asset, source: "capture" as const }));
}

function byOrder(a: CaptureAsset, b: CaptureAsset) {
  return (a.photo_index - b.photo_index) || a.committed_at.localeCompare(b.committed_at) || a.asset_id.localeCompare(b.asset_id);
}

/** Add new photos and take fresh links; a photo whose links did not change keeps its object, so its tile does not reload. */
function merge(current: CaptureAsset[], incoming: CaptureAsset[]) {
  const byId = new Map(current.map((asset) => [asset.asset_id, asset]));
  let changed = false;
  for (const asset of incoming) {
    const known = byId.get(asset.asset_id);
    if (known && known.url === asset.url && known.thumbnail_url === asset.thumbnail_url && known.preview_url === asset.preview_url) continue;
    byId.set(asset.asset_id, asset);
    changed = true;
  }
  return changed ? [...byId.values()].sort(byOrder) : current;
}

export type SessionPhotos = {
  /** Booth photos, collages and videos in shooting order (no manifest). */
  assets: CaptureAsset[];
  /** Everything listed / photos only, over all pages (from the server once known). */
  totalItems: number;
  totalPhotos: number;
  /** The first page has not arrived yet. */
  loading: boolean;
  /** Every page has been read. */
  complete: boolean;
  /** The server says the booth may still be sending photos. */
  receiving: boolean;
  studioName: string;
  error: ApiError | null;
  /** Read every page again (fresh links, photos added since). */
  reload: () => Promise<CaptureAsset[]>;
  /** True while the links in `assets` are safe to hand to a download right away. */
  linksFresh: () => boolean;
  /** The list with links that are safe to use, re-read first if they are getting old. */
  freshAssets: () => Promise<CaptureAsset[]>;
  /** An image failed to load (most likely an expired link): re-read the list, at most once a minute. */
  refreshLinks: () => void;
};

export function useSessionPhotos(endpoint: string): SessionPhotos {
  const [assets, setAssets] = useState<CaptureAsset[]>([]);
  const [totals, setTotals] = useState({ items: 0, photos: 0 });
  const [loading, setLoading] = useState(true);
  const [complete, setComplete] = useState(false);
  const [receiving, setReceiving] = useState(false);
  const [studioName, setStudioName] = useState("");
  const [error, setError] = useState<ApiError | null>(null);
  /** The list as last applied, readable right away (state lags a render behind). */
  const listRef = useRef<CaptureAsset[]>([]);
  const readingRef = useRef<Promise<CaptureAsset[]> | null>(null);
  /** When every page was last read; 0 = never. */
  const fullReadAt = useRef(0);
  const errorRefreshAt = useRef(0);

  const apply = useCallback((data: GalleryPayload) => {
    const next = merge(listRef.current, captures(data));
    if (next !== listRef.current) {
      listRef.current = next;
      setAssets(next);
    }
    if (data.studio?.name) setStudioName(data.studio.name);
    setTotals({ items: data.total_items ?? next.length, photos: data.total_photos ?? next.filter((asset) => asset.kind === "photo").length });
    setReceiving(Boolean(data.session?.receiving));
  }, []);

  const fetchPage = useCallback((cursor: string | null) => {
    const params = new URLSearchParams({ limit: String(PAGE_SIZE) });
    if (cursor) params.set("cursor", cursor);
    return apiJson<GalleryPayload>(`${endpoint}?${params}`);
  }, [endpoint]);

  /** Read every page in order; a second call while one is running shares it. */
  const reload = useCallback(() => {
    if (!endpoint) return Promise.resolve(listRef.current);
    if (readingRef.current) return readingRef.current;
    const run = (async () => {
      setError(null);
      try {
        let cursor: string | null = null;
        const seen = new Set<string>();
        do {
          const data: GalleryPayload = await fetchPage(cursor);
          apply(data);
          setLoading(false);
          cursor = data.next_cursor && !seen.has(data.next_cursor) ? data.next_cursor : null;
          if (cursor) seen.add(cursor);
        } while (cursor);
        fullReadAt.current = Date.now();
        setComplete(true);
      } catch (err) {
        setError(err as ApiError);
        setLoading(false);
      } finally {
        readingRef.current = null;
      }
      return listRef.current;
    })();
    readingRef.current = run;
    return run;
  }, [apply, endpoint, fetchPage]);

  useEffect(() => {
    if (endpoint) void reload();
    else setLoading(false);
  }, [endpoint, reload]);

  // While the booth is sending: re-read the first page for the totals, the rest when they grow.
  useEffect(() => {
    if (!receiving || !endpoint) return;
    let timer = 0;
    let delay = POLL_FIRST_MS;
    let stopped = false;
    let paused = false;
    const startedAt = Date.now();

    const tick = async () => {
      if (stopped) return;
      if (document.hidden) {
        paused = true;
        return;
      }
      const before = listRef.current.length;
      try {
        const data = await fetchPage(null);
        if (stopped) return;
        apply(data);
        if ((data.total_items ?? 0) > listRef.current.length) await reload();
        if (!data.session?.receiving) return;
      } catch {
        // Network hiccup: try again later.
      }
      if (stopped || Date.now() - startedAt > POLL_TOTAL_MS) {
        if (!stopped) setReceiving(false);
        return;
      }
      delay = listRef.current.length > before ? POLL_FIRST_MS : Math.min(POLL_MAX_MS, Math.round(delay * 1.5));
      timer = window.setTimeout(tick, delay);
    };
    const onVisible = () => {
      if (!document.hidden && paused && !stopped) {
        paused = false;
        void tick();
      }
    };
    document.addEventListener("visibilitychange", onVisible);
    timer = window.setTimeout(tick, delay);
    return () => {
      stopped = true;
      window.clearTimeout(timer);
      document.removeEventListener("visibilitychange", onVisible);
    };
  }, [apply, endpoint, fetchPage, receiving, reload]);

  const linksFresh = useCallback(() => fullReadAt.current > 0 && Date.now() - fullReadAt.current < LINKS_FRESH_MS, []);

  const freshAssets = useCallback(
    () => (linksFresh() ? Promise.resolve(listRef.current) : reload()),
    [linksFresh, reload],
  );

  const refreshLinks = useCallback(() => {
    const now = Date.now();
    if (now - errorRefreshAt.current < ERROR_REFRESH_MS || now - fullReadAt.current < ERROR_REFRESH_MS) return;
    errorRefreshAt.current = now;
    void reload();
  }, [reload]);

  return {
    assets,
    totalItems: Math.max(totals.items, assets.length),
    totalPhotos: totals.photos,
    loading,
    complete: complete && assets.length >= totals.items,
    receiving,
    studioName,
    error,
    reload,
    linksFresh,
    freshAssets,
    refreshLinks,
  };
}
