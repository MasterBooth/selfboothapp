"use client";

import { ArrowLeft, ArrowRight, ChevronLeft, ChevronRight, Heart, ImageOff, Layers3, Loader2, Upload, X } from "lucide-react";
import { useEffect, useMemo, useRef, useState } from "react";
import {
  type ApiError,
  type CaptureAsset,
  type FlowContext,
  type ComposePayload,
  type FrameTemplate,
  COMPOSE_KEY,
  FlowSteps,
  MAX_UPLOAD_BYTES,
  MAX_UPLOAD_FILES,
  assetLabel,
  assetsEndpoint,
  fetchFrames,
  flowHref,
  flowParams,
  readFlowContext,
} from "../flow";
import { isWebComposed } from "../composedPrints";
import { useSessionPhotos } from "../sessionPhotos";
import { Thumb } from "../thumbs";
import { loadUploads, saveUploads, uploadScope } from "../uploads";

export default function ComposePhotosPage() {
  const [ctx, setCtx] = useState<FlowContext | null>(null);
  const [frameId, setFrameId] = useState("");
  const [frame, setFrame] = useState<FrameTemplate | null>(null);
  const [frameLoading, setFrameLoading] = useState(true);
  const [uploadedAssets, setUploadedAssets] = useState<CaptureAsset[]>([]);
  const [selectedIds, setSelectedIds] = useState<string[]>([]);
  const [uploadNotice, setUploadNotice] = useState("");
  const [error, setError] = useState("");
  /** Photo open in the lightbox. */
  const [viewing, setViewing] = useState<number | null>(null);
  const localUrls = useRef<string[]>([]);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const next = readFlowContext();
    setCtx(next);
    setFrameId(params.get("frame_id") || "");
    if (!params.get("frame_id")) setFrameLoading(false);
    void loadUploads(uploadScope(next)).then((stored) => {
      localUrls.current.push(...stored.map((asset) => asset.url));
      setUploadedAssets(stored);
    });
  }, []);

  useEffect(() => () => {
    localUrls.current.forEach((url) => URL.revokeObjectURL(url));
    localUrls.current = [];
  }, []);

  const endpoint = useMemo(() => ctx ? assetsEndpoint(ctx) : "", [ctx]);
  const session = useSessionPhotos(endpoint);
  const { assets, refreshLinks } = session;
  const studioName = session.studioName || "BOOTHME";
  const shownError = error || session.error?.message || "";

  const sessionParams = ctx ? flowParams(ctx) : {};
  const galleryHref = flowHref("/gallery", sessionParams);
  const framesHref = flowHref("/compose/frames", { ...sessionParams, frame_id: frameId });

  // The guest's own web prints are results, not photos to put in a frame.
  const galleryAssets = useMemo(
    () => [...assets, ...uploadedAssets].filter((asset) => asset.kind !== "video" && !isWebComposed(asset)),
    [assets, uploadedAssets],
  );
  const maxSelectable = frame?.slots || 0;
  const selectedAssets = useMemo(
    () => selectedIds.map((id) => galleryAssets.find((asset) => asset.asset_id === id)).filter((asset): asset is CaptureAsset => Boolean(asset)),
    [galleryAssets, selectedIds],
  );
  const full = maxSelectable > 0 && selectedIds.length >= maxSelectable;

  useEffect(() => {
    if (!frameId || !ctx) return;
    let cancelled = false;
    setFrameLoading(true);
    fetchFrames(ctx)
      .then((frames) => {
        if (cancelled) return;
        const match = frames.find((item) => item.frame_id === frameId) || null;
        setFrame(match);
        if (!match) setError("Không tìm thấy frame đã chọn. Hãy quay lại chọn frame khác.");
      })
      .catch((err) => { if (!cancelled) setError((err as ApiError).message); })
      .finally(() => { if (!cancelled) setFrameLoading(false); });
    return () => { cancelled = true; };
  }, [ctx, frameId]);

  const toggleAsset = (assetId: string) => {
    setSelectedIds((current) => {
      if (current.includes(assetId)) return current.filter((id) => id !== assetId);
      if (maxSelectable && current.length >= maxSelectable) return current;
      return [...current, assetId];
    });
  };

  const uploadGuestPhotos = async (files: FileList | null) => {
    if (!files || files.length === 0) return;
    // Read the FileList now: the input is cleared right after this call starts.
    const fileCount = files.length;
    setError("");
    setUploadNotice("");
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
      setUploadNotice(`Đã lưu ${saved.length} ảnh từ thiết bị.`);
    }
    if (skipped > 0) {
      setError(`Bỏ qua ${skipped} file. Chỉ nhận ảnh, tối đa ${MAX_UPLOAD_FILES} ảnh và mỗi ảnh không quá 50MB.`);
    }
  };

  const goToCompose = async () => {
    if (!frame || selectedAssets.length === 0) return;
    // The editor and the print read these links later: take fresh ones if the page was left open.
    const fresh = new Map((await session.freshAssets()).map((asset) => [asset.asset_id, asset]));
    const payload: ComposePayload = {
      studioName,
      token: ctx?.token,
      machineId: ctx?.machineId,
      sessionId: ctx?.sessionId,
      frame,
      assets: selectedAssets.map((asset) => fresh.get(asset.asset_id) ?? asset),
      createdAt: new Date().toISOString(),
    };
    sessionStorage.setItem(COMPOSE_KEY, JSON.stringify(payload));
    window.location.href = "/compose";
  };

  const reach = (index: number) => index === 0 ? galleryHref : index === 1 ? framesHref : undefined;

  const viewingAsset = viewing === null ? null : galleryAssets[viewing] ?? null;
  const viewingOrder = viewingAsset ? selectedIds.indexOf(viewingAsset.asset_id) : -1;

  useEffect(() => {
    if (viewing === null) return;
    const onKey = (event: KeyboardEvent) => {
      if (event.key === "Escape") setViewing(null);
      if (event.key === "ArrowLeft") setViewing((current) => current === null ? null : Math.max(0, current - 1));
      if (event.key === "ArrowRight") setViewing((current) => current === null ? null : Math.min(galleryAssets.length - 1, current + 1));
    };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [galleryAssets.length, viewing]);

  if (!frameLoading && !frame) {
    return (
      <main className="compose-shell">
        <FlowSteps current={2} reach={reach} />
        <section className="compose-empty">
          <Layers3 size={34} />
          <h1>Chưa chọn frame</h1>
          {shownError ? <p>{shownError}</p> : null}
          <a className="primary-action" href={framesHref}><ArrowLeft size={18} />Chọn frame</a>
        </section>
      </main>
    );
  }

  return (
    <main className="compose-shell has-flow-bar">
      <FlowSteps current={2} reach={reach} />

      <header className="compose-header compose-header-row">
        <a className="gallery-icon-button" href={framesHref} title="Quay lại chọn frame">
          <ArrowLeft size={18} />
        </a>
        <div className="compose-header-title">
          <h1>Chọn ảnh</h1>
          {frame ? <small>{frame.name} · {frame.slots} ô</small> : null}
        </div>
        <label className="gallery-upload-button header-upload" title="Tải ảnh lên">
          <Upload size={18} />
          <span>Tải ảnh lên</span>
          <input accept="image/*" aria-label="Tải ảnh lên" multiple onChange={(event) => { uploadGuestPhotos(event.target.files); event.currentTarget.value = ""; }} type="file" />
        </label>
      </header>

      {shownError ? <div className="inline-message">{shownError}</div> : null}
      {uploadNotice ? <div className="gallery-note" role="status">{uploadNotice}</div> : null}

      {galleryAssets.length === 0 && !session.loading && !session.receiving ? (
        <div className="empty-state gallery-empty">
          <ImageOff size={28} />
          <strong>Chưa có ảnh</strong>
        </div>
      ) : null}

      <section className="photo-grid" aria-label="Ảnh trong phiên">
        {galleryAssets.map((asset, index) => {
          const order = selectedIds.indexOf(asset.asset_id);
          const selected = order >= 0;
          const label = assetLabel(asset, index);
          return (
            <article className={selected ? "photo-tile selected" : "photo-tile"} key={asset.asset_id}>
              <button aria-label={`Xem ${label}`} className="photo-tile-open" onClick={() => setViewing(index)} type="button">
                <Thumb asset={asset} eager={index < 4} onError={asset.source === "upload" ? undefined : refreshLinks} token={ctx?.token || undefined} />
              </button>
              <button
                aria-label={selected ? `Bỏ chọn ${label} (ô ${order + 1})` : `Chọn ${label}`}
                aria-pressed={selected}
                className="photo-tile-heart"
                disabled={!selected && full}
                onClick={() => toggleAsset(asset.asset_id)}
                type="button"
              >
                <Heart size={18} fill={selected ? "currentColor" : "none"} strokeWidth={2.25} />
                {selected ? <small>{order + 1}</small> : null}
              </button>
            </article>
          );
        })}
      </section>

      {!endpoint || session.error ? null : session.loading || !session.complete ? (
        <div className="gallery-frame-status photo-pick-status">
          <Loader2 size={18} /> Đang tải ảnh{session.loading ? "" : ` ${assets.length}/${session.totalItems}`}
        </div>
      ) : session.receiving ? (
        <div className="gallery-frame-status photo-pick-status gallery-syncing" role="status"><Loader2 size={18} /> Đang nhận ảnh từ máy chụp</div>
      ) : null}

      {viewingAsset ? (
        <div className="lightbox" role="dialog" aria-modal="true" aria-label={assetLabel(viewingAsset, viewing ?? 0)}>
          <button className="lightbox-close" onClick={() => setViewing(null)} type="button" title="Đóng"><X size={22} /></button>
          <button className="lightbox-nav prev" disabled={viewing === 0} onClick={() => setViewing((viewing ?? 0) - 1)} type="button" title="Ảnh trước"><ChevronLeft size={24} /></button>
          <figure>
            <img
              alt={assetLabel(viewingAsset, viewing ?? 0)}
              onError={viewingAsset.source === "upload" ? undefined : refreshLinks}
              src={viewingAsset.preview_url || viewingAsset.url}
            />
            <figcaption>
              <span>{assetLabel(viewingAsset, viewing ?? 0)}</span>
              <button
                aria-pressed={viewingOrder >= 0}
                disabled={viewingOrder < 0 && full}
                onClick={() => toggleAsset(viewingAsset.asset_id)}
                type="button"
              >
                <Heart size={18} fill={viewingOrder >= 0 ? "currentColor" : "none"} />
                {viewingOrder >= 0 ? `Ô ${viewingOrder + 1}` : "Chọn"}
              </button>
            </figcaption>
          </figure>
          <button className="lightbox-nav next" disabled={viewing === galleryAssets.length - 1} onClick={() => setViewing((viewing ?? 0) + 1)} type="button" title="Ảnh sau"><ChevronRight size={24} /></button>
        </div>
      ) : null}

      <div className="flow-bar">
        <p aria-live="polite">
          <strong>{selectedIds.length}/{maxSelectable || "–"}</strong>
          <span>{full ? "Đã đủ ảnh" : "ảnh đã chọn"}</span>
        </p>
        {selectedIds.length > 0 ? (
          <button className="text-action" onClick={() => setSelectedIds([])} type="button">Bỏ chọn</button>
        ) : null}
        <button className="primary-action" disabled={!frame || selectedAssets.length === 0} onClick={() => void goToCompose()} type="button">
          Ghép &amp; chỉnh sửa
          <ArrowRight size={18} />
        </button>
      </div>
    </main>
  );
}
