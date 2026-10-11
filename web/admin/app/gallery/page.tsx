"use client";

import {
  ArrowRight,
  ChevronLeft,
  ChevronRight,
  Download,
  ImageOff,
  Layers3,
  Loader2,
  Maximize2,
  Trash2,
  Upload,
  X,
} from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  type CaptureAsset,
  type FlowContext,
  FlowSteps,
  MAX_UPLOAD_BYTES,
  MAX_UPLOAD_FILES,
  assetLabel,
  assetsEndpoint,
  flowHref,
  flowParams,
  hasSession,
  readFlowContext,
  triggerDownload,
} from "../compose/flow";
import { BrandLogo, useGuestBranding } from "../brand";
import { syncComposed } from "../compose/composedPrints";
import { useSessionPhotos } from "../compose/sessionPhotos";
import { Thumb } from "../compose/thumbs";
import { countComposed, loadUploads, pruneUploads, removeUpload, saveUploads, uploadScope } from "../compose/uploads";

type ProgressState = {
  open: boolean;
  title: string;
  detail: string;
  current: number;
  total: number;
};

export default function GalleryPage() {
  const [ctx, setCtx] = useState<FlowContext | null>(null);
  const [uploadedAssets, setUploadedAssets] = useState<CaptureAsset[]>([]);
  const [composedCount, setComposedCount] = useState(0);
  const [downloadingAll, setDownloadingAll] = useState(false);
  const [uploadNotice, setUploadNotice] = useState("");
  const [error, setError] = useState("");
  const [unlockPhone, setUnlockPhone] = useState("");
  const [unlocking, setUnlocking] = useState(false);
  const [unlockError, setUnlockError] = useState("");
  const [active, setActive] = useState<number | null>(null);
  const [progress, setProgress] = useState<ProgressState>({ open: false, title: "", detail: "", current: 0, total: 0 });
  const localUrls = useRef<string[]>([]);

  useEffect(() => {
    const next = readFlowContext();
    setCtx(next);
    if (!hasSession(next)) {
      setError("Link album không hợp lệ. Hãy quét lại mã QR ở máy chụp.");
    }
    void pruneUploads().then(() => loadUploads(uploadScope(next))).then((stored) => {
      localUrls.current.push(...stored.map((asset) => asset.url));
      setUploadedAssets(stored);
    });
    void countComposed(uploadScope(next)).then(setComposedCount);
  }, []);

  const endpoint = useMemo(() => ctx ? assetsEndpoint(ctx) : "", [ctx]);
  const session = useSessionPhotos(endpoint);
  const { assets, refreshLinks, reload } = session;

  // Prints made here before they could be sent go up now, so the studio sees them too.
  useEffect(() => {
    if (!ctx?.token) return;
    void syncComposed(ctx.token, uploadScope(ctx)).then((sent) => {
      if (sent === 0) return;
      void countComposed(uploadScope(ctx)).then(setComposedCount);
      void reload();
    });
  }, [ctx, reload]);
  const studioName = session.studioName || "BOOTHME";
  /** Masked booking phone when this booked guest's gallery is older than 24 h (needs the phone). */
  const lockedHint = session.error?.code === "gallery_locked" ? session.error.message : "";
  const loadError = session.error && session.error.code !== "gallery_locked" ? session.error.message : "";
  const token = ctx?.token || undefined;
  const branding = useGuestBranding(token);
  const brandName = branding?.name || studioName;

  useEffect(() => {
    document.title = `${studioName} · Ảnh của bạn`;
  }, [studioName]);

  useEffect(() => () => {
    localUrls.current.forEach((url) => URL.revokeObjectURL(url));
    localUrls.current = [];
  }, []);

  // Booth collages live on the "Ảnh đã ghép" page, not in the photo grid.
  const photos = useMemo(() => assets.filter((asset) => asset.kind !== "collage"), [assets]);
  const collageCount = assets.length - photos.length;
  /** Grid photos of the session: the server's total while later pages are still loading. */
  const photoTotal = Math.max(photos.length, session.totalItems - collageCount);
  const galleryAssets = useMemo(() => [...photos, ...uploadedAssets], [photos, uploadedAssets]);

  const activeAsset = active === null ? null : galleryAssets[active];

  // Warm only the next photo; the previous one was already seen.
  useEffect(() => {
    if (active === null) return;
    const next = galleryAssets[active + 1];
    if (next?.preview_url && next.kind !== "video") {
      const img = new Image();
      img.decoding = "async";
      img.src = next.preview_url;
    }
  }, [active, galleryAssets]);

  const moveLightbox = (direction: -1 | 1) => {
    if (active === null) return;
    setActive(Math.min(Math.max(active + direction, 0), galleryAssets.length - 1));
  };

  /** Saves the original. Links older than ~90 min (page left open) are re-read first. */
  const downloadOne = async (asset: CaptureAsset, index: number, silent = false) => {
    if (!silent) setProgress({ open: true, title: "Đang chuẩn bị tải ảnh", detail: assetLabel(asset, index), current: 1, total: 1 });
    let target = asset;
    if (asset.source !== "upload" && !session.linksFresh()) {
      const list = await session.freshAssets();
      target = list.find((item) => item.asset_id === asset.asset_id) ?? asset;
    }
    triggerDownload(target.url, target.file_name || `${assetLabel(target, index)}.jpg`);
    if (!silent) window.setTimeout(() => setProgress((current) => ({ ...current, open: false })), 900);
  };

  const downloadAll = async () => {
    if (downloadingAll) return;
    setDownloadingAll(true);
    setProgress({ open: true, title: "Đang tải ảnh", detail: "Chuẩn bị danh sách ảnh", current: 0, total: Math.max(1, photoTotal + uploadedAssets.length) });
    let allAssets = galleryAssets;
    try {
      // Waits for pages still loading, and takes fresh links if the page was left open.
      const list = await session.freshAssets();
      allAssets = [...list.filter((asset) => asset.kind !== "collage"), ...uploadedAssets];
      allAssets.forEach((asset, index) => {
        window.setTimeout(() => {
          setProgress({ open: true, title: "Đang tải ảnh", detail: assetLabel(asset, index), current: index + 1, total: allAssets.length });
          void downloadOne(asset, index, true);
        }, index * 120);
      });
    } finally {
      window.setTimeout(() => {
        setDownloadingAll(false);
        setProgress((current) => ({ ...current, open: false }));
      }, Math.max(900, allAssets.length * 120 + 500));
    }
  };

  const uploadGuestPhotos = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    // Read the FileList now: the input is cleared right after this call starts.
    const fileCount = files.length;
    setError("");
    setUploadNotice("");
    setProgress({ open: true, title: "Đang lưu ảnh", detail: "Kiểm tra dung lượng và định dạng", current: 0, total: fileCount });
    const incoming = Array.from(files).filter((file) => file.type.startsWith("image/"));
    const remaining = Math.max(0, MAX_UPLOAD_FILES - uploadedAssets.length);
    let skipped = fileCount - incoming.length;
    const valid = incoming.slice(0, remaining).filter((file) => {
      if (file.size <= MAX_UPLOAD_BYTES) return true;
      skipped++;
      return false;
    });
    if (incoming.length > remaining) skipped += incoming.length - remaining;
    let saved: CaptureAsset[] = [];
    try {
      saved = await saveUploads(uploadScope(ctx ?? { token: "", machineId: "", sessionId: "" }), valid, assets.length + uploadedAssets.length);
    } catch {
      setError("Trình duyệt không cho lưu ảnh (có thể đang ở chế độ ẩn danh hoặc bộ nhớ đã đầy).");
    }
    localUrls.current.push(...saved.map((asset) => asset.url));
    if (saved.length > 0) {
      setUploadedAssets((current) => [...current, ...saved]);
      setUploadNotice(`Đã thêm ${saved.length} ảnh.`);
    }
    if (skipped > 0) {
      setError(`Bỏ qua ${skipped} file. Chỉ nhận ảnh, tối đa ${MAX_UPLOAD_FILES} ảnh và mỗi ảnh không quá 50MB.`);
    }
    setProgress({ open: true, title: "Đã lưu ảnh", detail: saved.length > 0 ? `${saved.length} ảnh sẵn sàng để chọn frame` : "Không có ảnh hợp lệ", current: saved.length, total: Math.max(1, fileCount) });
    window.setTimeout(() => setProgress((current) => ({ ...current, open: false })), 1000);
  };

  const deleteUpload = async (asset: CaptureAsset) => {
    const index = galleryAssets.findIndex((item) => item.asset_id === asset.asset_id);
    setUploadedAssets((current) => current.filter((item) => item.asset_id !== asset.asset_id));
    if (active !== null && index >= 0 && active >= index) setActive(null);
    try {
      await removeUpload(asset.asset_id);
    } catch {
      setError("Không xóa được ảnh khỏi bộ nhớ trình duyệt.");
    }
  };

  const sessionParams = ctx ? flowParams(ctx) : {};
  const framesHref = flowHref("/compose/frames", sessionParams);
  const composedHref = flowHref("/gallery/composed", sessionParams);
  const composedTotal = composedCount + collageCount;

  return (
    <main className={lockedHint ? "gallery-shell" : "gallery-shell has-flow-bar"}>
      <FlowSteps current={0} />

      <header className="gallery-header gallery-header-public gallery-brand-header">
        <BrandLogo branding={branding} name={brandName} />
        <div className="gallery-title">
          <span className="eyebrow">Ảnh của bạn</span>
          <h1>{brandName}</h1>
        </div>
      </header>

      {lockedHint ? (
        <section className="gallery-lock" aria-labelledby="gallery-lock-title">
          <h2 id="gallery-lock-title">Xác minh số điện thoại</h2>
          <p>Ảnh của lịch đặt qua web chỉ mở tự do trong 24 giờ. Nhập số điện thoại đã đặt lịch <b>{lockedHint}</b> để xem tiếp.</p>
          <form
            onSubmit={async (event) => {
              event.preventDefault();
              if (!ctx?.token) return;
              setUnlocking(true);
              setUnlockError("");
              try {
                const response = await fetch(`/v1/public/gallery/${encodeURIComponent(ctx.token)}/unlock`, {
                  method: "POST",
                  credentials: "include",
                  headers: { "content-type": "application/json" },
                  body: JSON.stringify({ phone: unlockPhone }),
                });
                const data = await response.json().catch(() => ({}));
                if (!response.ok) throw new Error(data.message || "Không xác minh được");
                void session.reload();
              } catch (err) {
                setUnlockError((err as Error).message);
              } finally {
                setUnlocking(false);
              }
            }}
          >
            <input aria-label="Số điện thoại đã đặt lịch" autoComplete="tel" inputMode="tel" maxLength={20} onChange={(e) => setUnlockPhone(e.target.value)} placeholder="Số điện thoại" required value={unlockPhone} />
            <button className="primary-action" disabled={unlocking} type="submit">{unlocking ? <Loader2 size={18} /> : null}Xem ảnh</button>
          </form>
          {unlockError ? <p className="booking-error" role="alert">{unlockError}</p> : null}
        </section>
      ) : null}

      {lockedHint ? null : <div className="gallery-action-row">
        <label className="gallery-upload-button">
          <Upload size={18} />
          <span>Tải ảnh lên</span>
          <input accept="image/*" aria-label="Tải ảnh lên" multiple onChange={(event) => { uploadGuestPhotos(event.target.files); event.currentTarget.value = ""; }} type="file" />
        </label>
        <button className={downloadingAll ? "gallery-upload-button gallery-download-all is-loading" : "gallery-upload-button gallery-download-all"} disabled={galleryAssets.length === 0 || downloadingAll} onClick={downloadAll} type="button">
          {downloadingAll ? <Loader2 size={18} /> : <Download size={18} />}
          <span>Tải tất cả</span>
        </button>
        <a className="gallery-upload-button gallery-composed-link" href={composedHref}>
          <Layers3 size={18} />
          <span>Ảnh đã ghép</span>
          {composedTotal > 0 ? <b aria-label={`${composedTotal} ảnh`}>{composedTotal}</b> : null}
        </a>
      </div>}

      {error || loadError ? <div className="inline-message">{error || loadError}</div> : null}
      {uploadNotice ? <div className="gallery-note" role="status">{uploadNotice}</div> : null}

      {galleryAssets.length === 0 && !session.loading && !session.receiving && !lockedHint ? (
        <div className="empty-state gallery-empty">
          <ImageOff size={28} />
          <strong>Chưa có ảnh</strong>
        </div>
      ) : null}

      <section className="photo-grid" aria-label="Ảnh trong phiên">
        {galleryAssets.map((asset, index) => {
          const label = assetLabel(asset, index);
          return (
            <article className="photo-tile" key={asset.asset_id}>
              <button aria-label={`Xem ${label}`} className="photo-tile-open" onClick={() => setActive(index)} type="button">
                {asset.kind === "video" ? (
                  <video preload="none" src={asset.preview_url || asset.url} />
                ) : (
                  <Thumb asset={asset} eager={index < 4} onError={asset.source === "upload" ? undefined : refreshLinks} token={token} />
                )}
              </button>
              <div className="photo-tile-actions">
                <button aria-label={`Xem ${label}`} onClick={() => setActive(index)} type="button">
                  <Maximize2 size={16} />
                  <span>Xem</span>
                </button>
                <button aria-label={`Tải ${label}`} onClick={() => void downloadOne(asset, index)} type="button">
                  <Download size={16} />
                  <span>Tải</span>
                </button>
              </div>
              {asset.source === "upload" ? (
                <button aria-label={`Xóa ${label}`} className="photo-tile-remove" onClick={() => deleteUpload(asset)} title="Xóa ảnh đã tải lên" type="button">
                  <Trash2 size={16} />
                </button>
              ) : null}
            </article>
          );
        })}
      </section>

      {!endpoint || session.error ? null : session.loading || !session.complete ? (
        <div className="gallery-frame-status">
          <Loader2 size={18} /> Đang tải ảnh{session.loading ? "" : ` ${photos.length}/${photoTotal}`}
        </div>
      ) : session.receiving ? (
        <div className="gallery-frame-status gallery-syncing" role="status"><Loader2 size={18} /> Đang nhận ảnh từ máy chụp</div>
      ) : null}

      {lockedHint ? null : (
        <div className="flow-bar">
          <p aria-live="polite" className="flow-count"><strong>{photoTotal + uploadedAssets.length}</strong><span>ảnh</span></p>
          <a className="primary-action" href={framesHref}>
            Chọn frame
            <ArrowRight size={18} />
          </a>
        </div>
      )}

      {progress.open ? (
        <div className="progress-dialog" role="dialog" aria-modal="true" aria-label={progress.title}>
          <div className="progress-panel">
            <Loader2 size={24} />
            <h2>{progress.title}</h2>
            <p>{progress.detail}</p>
            <progress max={progress.total || 1} value={progress.current} />
            <span>{progress.current}/{progress.total || 1}</span>
          </div>
        </div>
      ) : null}

      {activeAsset ? (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label={assetLabel(activeAsset, active ?? 0)}>
          <button className="lightbox-close" onClick={() => setActive(null)} type="button" title="Đóng"><X size={22} /></button>
          <button className="lightbox-nav prev" disabled={active === 0} onClick={() => moveLightbox(-1)} type="button" title="Ảnh trước"><ChevronLeft size={24} /></button>
          <figure>
            {activeAsset.kind === "video" ? (
              <video controls src={activeAsset.preview_url || activeAsset.url} />
            ) : (
              <img
                alt={assetLabel(activeAsset, active ?? 0)}
                decoding="async"
                onError={activeAsset.source === "upload" ? undefined : refreshLinks}
                src={activeAsset.preview_url || activeAsset.url}
              />
            )}
            <figcaption>
              <span>{assetLabel(activeAsset, active ?? 0)}</span>
              <button onClick={() => void downloadOne(activeAsset, active ?? 0)} type="button"><Download size={18} />Tải gốc</button>
            </figcaption>
          </figure>
          <button className="lightbox-nav next" disabled={active === galleryAssets.length - 1} onClick={() => moveLightbox(1)} type="button" title="Ảnh sau"><ChevronRight size={24} /></button>
        </div>
      ) : null}
    </main>
  );
}
