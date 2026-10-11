"use client";

import { ArrowLeft, ArrowRight, ChevronLeft, ChevronRight, Download, Layers3, Loader2, Maximize2, Trash2, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import {
  type CaptureAsset,
  type FlowContext,
  FlowSteps,
  assetsEndpoint,
  flowHref,
  flowParams,
  readFlowContext,
  triggerDownload,
} from "../../compose/flow";
import { WEB_COMPOSED_PREFIX, deleteComposed, isWebComposed, syncComposed } from "../../compose/composedPrints";
import { useSessionPhotos } from "../../compose/sessionPhotos";
import { Thumb } from "../../compose/thumbs";
import { type ComposedImage, loadComposed, removeComposed, uploadScope } from "../../compose/uploads";

/** A print still kept only in this browser (not sent to the server yet). */
const LOCAL_PREFIX = "composed-";

/** A print made in the editor, shaped like a gallery photo so the shared tile can show it. */
function composedAsset(item: ComposedImage): CaptureAsset {
  const day = item.createdAt.slice(0, 10);
  return {
    asset_id: `${LOCAL_PREFIX}${item.id}`,
    kind: "collage",
    // The same file the print step downloads: full-size PNG (older entries may be JPEG).
    file_name: `${item.name.replace(/[^\w.-]+/g, "-")}-${day}.${item.type === "image/jpeg" ? "jpg" : "png"}`,
    content_type: item.type || "image/png",
    size_bytes: item.size,
    photo_index: 0,
    committed_at: item.createdAt,
    url: item.url,
    thumbnail_url: item.url,
    preview_url: item.url,
    source: "upload",
  };
}

/** Made in the web editor: kept in this browser or on the server. */
function isGuestPrint(asset: CaptureAsset) {
  return asset.asset_id.startsWith(LOCAL_PREFIX) || isWebComposed(asset);
}

function label(asset: CaptureAsset, index: number) {
  return isGuestPrint(asset) ? `Ảnh ghép ${index + 1}` : `Ảnh ghép máy chụp ${index + 1}`;
}

export default function ComposedPage() {
  const [ctx, setCtx] = useState<FlowContext | null>(null);
  const [local, setLocal] = useState<ComposedImage[]>([]);
  const [localLoading, setLocalLoading] = useState(true);
  /** Server prints deleted on this page, hidden until the list is read again. */
  const [removed, setRemoved] = useState<string[]>([]);
  const [error, setError] = useState("");
  const [active, setActive] = useState<number | null>(null);
  const urls = useRef<string[]>([]);

  const readLocal = useCallback((next: FlowContext) => loadComposed(uploadScope(next)).then((items) => {
    urls.current.forEach((url) => URL.revokeObjectURL(url));
    urls.current = items.map((item) => item.url);
    setLocal(items);
  }), []);

  useEffect(() => {
    const next = readFlowContext();
    setCtx(next);
    void readLocal(next).finally(() => setLocalLoading(false));
    return () => {
      urls.current.forEach((url) => URL.revokeObjectURL(url));
      urls.current = [];
    };
  }, [readLocal]);

  // Every print of the session, from any device: the web editor's and the booth's collages.
  const endpoint = useMemo(() => ctx ? assetsEndpoint(ctx) : "", [ctx]);
  const session = useSessionPhotos(endpoint);
  const { reload, refreshLinks } = session;
  const token = ctx?.token || "";

  // Prints kept here before they could be sent go up now, so the studio sees them too.
  useEffect(() => {
    if (!ctx?.token) return;
    void syncComposed(ctx.token, uploadScope(ctx)).then((sent) => {
      if (sent === 0) return;
      void readLocal(ctx);
      void reload();
    });
  }, [ctx, readLocal, reload]);

  const items = useMemo(() => {
    const collages = session.assets.filter((asset) => asset.kind === "collage" && !removed.includes(asset.asset_id));
    // A print sent but whose browser copy is not dropped yet shows once (same id on both).
    const sent = new Set(collages.filter(isWebComposed).map((asset) => asset.asset_id.slice(WEB_COMPOSED_PREFIX.length)));
    const unsent = local.filter((item) => !sent.has(item.id)).map(composedAsset);
    // The guest's own prints first, newest first; then the booth's.
    const mine = [...unsent, ...collages.filter(isWebComposed)]
      .sort((a, b) => b.committed_at.localeCompare(a.committed_at));
    return [...mine, ...collages.filter((asset) => !isWebComposed(asset))];
  }, [local, removed, session.assets]);
  const loading = localLoading || session.loading;
  const activeAsset = active === null ? null : items[active] ?? null;
  const sessionParams = ctx ? flowParams(ctx) : {};
  const galleryHref = flowHref("/gallery", sessionParams);
  const framesHref = flowHref("/compose/frames", sessionParams);

  useEffect(() => {
    if (active === null) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setActive(null);
      if (event.key === "ArrowLeft") setActive((current) => current === null ? null : Math.max(0, current - 1));
      if (event.key === "ArrowRight") setActive((current) => current === null ? null : Math.min(items.length - 1, current + 1));
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [active, items.length]);

  /** Saves the original. Server links older than ~90 min (page left open) are re-read first. */
  const download = async (asset: CaptureAsset, index: number) => {
    let target = asset;
    if (asset.source !== "upload" && !session.linksFresh()) {
      const list = await session.freshAssets();
      target = list.find((item) => item.asset_id === asset.asset_id) ?? asset;
    }
    triggerDownload(target.url, target.file_name || `${label(target, index)}.png`);
  };

  const remove = async (asset: CaptureAsset) => {
    setActive(null);
    setError("");
    if (asset.asset_id.startsWith(LOCAL_PREFIX)) {
      const id = asset.asset_id.slice(LOCAL_PREFIX.length);
      setLocal((current) => current.filter((item) => item.id !== id));
      try {
        await removeComposed(id);
      } catch {
        // Already gone from this browser.
      }
      return;
    }
    setRemoved((current) => [...current, asset.asset_id]);
    try {
      await deleteComposed(token, asset.asset_id);
    } catch (err) {
      setRemoved((current) => current.filter((id) => id !== asset.asset_id));
      setError((err as Error).message);
    }
  };

  return (
    <main className="gallery-shell has-flow-bar">
      <FlowSteps current={0} reach={() => undefined} />

      <header className="compose-header compose-header-row">
        <a className="gallery-icon-button" href={galleryHref} title="Quay lại ảnh của bạn">
          <ArrowLeft size={18} />
        </a>
        <div className="compose-header-title">
          <h1>Ảnh đã ghép</h1>
          <small>{items.length} ảnh</small>
        </div>
        <span aria-hidden="true" />
      </header>

      {error || (session.error && items.length === 0) ? <div className="inline-message">{error || session.error?.message}</div> : null}

      {loading ? <div className="gallery-frame-status"><Loader2 size={18} /> Đang tải ảnh</div> : null}

      {!loading && items.length === 0 ? (
        <div className="empty-state gallery-empty">
          <Layers3 size={28} />
          <strong>Chưa có ảnh ghép</strong>
        </div>
      ) : null}

      <section className="photo-grid" aria-label="Ảnh đã ghép">
        {items.map((asset, index) => {
          const name = label(asset, index);
          // Server prints are removed through the guest link only (not the staff view).
          const removable = asset.asset_id.startsWith(LOCAL_PREFIX) || (isWebComposed(asset) && Boolean(token));
          return (
            <article className="photo-tile" key={asset.asset_id}>
              <button aria-label={`Xem ${name}`} className="photo-tile-open" onClick={() => setActive(index)} type="button">
                <Thumb asset={asset} eager={index < 4} onError={asset.source === "upload" ? undefined : refreshLinks} token={token || undefined} />
              </button>
              <div className="photo-tile-actions">
                <button aria-label={`Xem ${name}`} onClick={() => setActive(index)} type="button">
                  <Maximize2 size={16} />
                  <span>Xem</span>
                </button>
                <button aria-label={`Tải ${name}`} onClick={() => void download(asset, index)} type="button">
                  <Download size={16} />
                  <span>Tải</span>
                </button>
              </div>
              {removable ? (
                <button aria-label={`Xóa ${name}`} className="photo-tile-remove" onClick={() => remove(asset)} title="Xóa ảnh ghép" type="button">
                  <Trash2 size={16} />
                </button>
              ) : null}
            </article>
          );
        })}
      </section>

      <div className="flow-bar">
        <p aria-live="polite" className="flow-count"><strong>{items.length}</strong><span>ảnh ghép</span></p>
        <a className="primary-action" href={framesHref}>
          Ghép ảnh mới
          <ArrowRight size={18} />
        </a>
      </div>

      {activeAsset ? (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label={label(activeAsset, active ?? 0)}>
          <button className="lightbox-close" onClick={() => setActive(null)} type="button" title="Đóng"><X size={22} /></button>
          <button className="lightbox-nav prev" disabled={active === 0} onClick={() => setActive((active ?? 0) - 1)} type="button" title="Ảnh trước"><ChevronLeft size={24} /></button>
          <figure>
            {/* The print itself, at full quality: preview_url can be the small grid copy. */}
            <img
              alt={label(activeAsset, active ?? 0)}
              decoding="async"
              onError={activeAsset.source === "upload" ? undefined : refreshLinks}
              src={activeAsset.url}
            />
            <figcaption>
              <span>{label(activeAsset, active ?? 0)}</span>
              <button onClick={() => void download(activeAsset, active ?? 0)} type="button"><Download size={18} />Tải về</button>
            </figcaption>
          </figure>
          <button className="lightbox-nav next" disabled={active === items.length - 1} onClick={() => setActive((active ?? 0) + 1)} type="button" title="Ảnh sau"><ChevronRight size={24} /></button>
        </div>
      ) : null}
    </main>
  );
}
