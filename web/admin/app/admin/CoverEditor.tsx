"use client";

/**
 * Framing a room cover: drag to move, slider / wheel / pinch to zoom, inside a fixed 3:2 frame —
 * the same 3:2 the booking page shows in the room list and on the room page, previewed live
 * beside the editor with the booking page's own components. Saving makes the framed copy
 * guests load; the original stays untouched on the server, so the cover can be reframed later.
 */

import { ChevronRight, Loader2, Maximize, Minus, Plus, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, KeyboardEvent, PointerEvent } from "react";

/** Fractions of the original photo. */
export type CoverCrop = { x: number; y: number; w: number; h: number };

/** Width : height of every cover surface (admin card, booking room row, room page). */
export const COVER_ASPECT = 3 / 2;
/** Long side of the framed copy guests load. */
const COVER_DISPLAY_WIDTH = 1600;
const MAX_ZOOM = 4;

type View = { zoom: number; cx: number; cy: number };

/** The crop a view gives on a W×H photo: the largest 3:2 box at zoom 1, smaller as it zooms in. */
function cropFor(view: View, width: number, height: number): CoverCrop {
  const baseW = width / height > COVER_ASPECT ? height * COVER_ASPECT : width;
  const baseH = baseW / COVER_ASPECT;
  const w = baseW / view.zoom;
  const h = baseH / view.zoom;
  const x = Math.min(Math.max(view.cx * width - w / 2, 0), width - w);
  const y = Math.min(Math.max(view.cy * height - h / 2, 0), height - h);
  return { x: x / width, y: y / height, w: w / width, h: h / height };
}

/** Inverse of cropFor, to reopen the editor on a saved framing. */
function viewFor(crop: CoverCrop, width: number, height: number): View {
  const baseW = width / height > COVER_ASPECT ? height * COVER_ASPECT : width;
  const zoom = Math.min(MAX_ZOOM, Math.max(1, baseW / (crop.w * width)));
  return { zoom, cx: crop.x + crop.w / 2, cy: crop.y + crop.h / 2 };
}

/** Places the whole photo so that `crop` fills a 3:2 box exactly (any box size). */
export function cropImageStyle(crop: CoverCrop): CSSProperties {
  return {
    position: "absolute",
    left: `${(-crop.x / crop.w) * 100}%`,
    top: `${(-crop.y / crop.h) * 100}%`,
    width: `${100 / crop.w}%`,
    height: `${100 / crop.h}%`,
    maxWidth: "none",
    objectFit: "fill",
  };
}

async function framedCopy(image: HTMLImageElement, crop: CoverCrop): Promise<Blob> {
  const sw = crop.w * image.naturalWidth;
  const sh = crop.h * image.naturalHeight;
  // Never upscale: a small photo keeps its own pixels.
  const width = Math.max(1, Math.round(Math.min(COVER_DISPLAY_WIDTH, sw)));
  const height = Math.max(1, Math.round(width / COVER_ASPECT));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Trình duyệt không hỗ trợ cắt ảnh");
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(image, crop.x * image.naturalWidth, crop.y * image.naturalHeight, sw, sh, 0, 0, width, height);
  const encode = (type: string) => new Promise<Blob | null>((resolve) => canvas.toBlob(resolve, type, 0.9));
  const webp = await encode("image/webp");
  if (webp && webp.type === "image/webp") return webp;
  const jpeg = await encode("image/jpeg");
  if (!jpeg) throw new Error("Không tạo được ảnh bìa");
  return jpeg;
}

export type CoverEditorProps = {
  /** Object URL of a newly picked file, or the stored original when reframing. */
  src: string;
  initialCrop?: CoverCrop | null;
  roomName: string;
  capacity: string;
  /** "Từ 99.000 ₫ · 3 gói" / "Chưa có gói", as the booking page will print it. */
  priceLine: string;
  busy: boolean;
  /** Lỗi khi lưu (hiện trong hộp, vì trang phía sau bị che). */
  error?: string;
  onCancel: () => void;
  onSave: (crop: CoverCrop, display: Blob) => void;
};

export function CoverEditor({ src, initialCrop, roomName, capacity, priceLine, busy, error, onCancel, onSave }: CoverEditorProps) {
  const dialog = useRef<HTMLDialogElement | null>(null);
  const stage = useRef<HTMLDivElement | null>(null);
  const image = useRef<HTMLImageElement | null>(null);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const gesture = useRef<{ view: View; x: number; y: number; distance: number } | null>(null);
  const [size, setSize] = useState<{ width: number; height: number } | null>(null);
  const [view, setView] = useState<View>({ zoom: 1, cx: 0.5, cy: 0.5 });
  const [failed, setFailed] = useState(false);
  const [dragging, setDragging] = useState(false);
  const [saving, setSaving] = useState(false);

  useEffect(() => {
    const node = dialog.current;
    if (node && !node.open) node.showModal();
    return () => node?.close();
  }, []);

  const crop = useMemo(() => (size ? cropFor(view, size.width, size.height) : null), [size, view]);

  const onLoad = () => {
    const img = image.current;
    if (!img) return;
    const next = { width: img.naturalWidth, height: img.naturalHeight };
    setSize(next);
    setView(initialCrop ? viewFor(initialCrop, next.width, next.height) : { zoom: 1, cx: 0.5, cy: 0.5 });
  };

  /** Keeps the centre where the frame can actually reach, so a drag never "sticks" past the edge. */
  const settle = useCallback((next: View): View => {
    if (!size) return next;
    const zoom = Math.min(MAX_ZOOM, Math.max(1, next.zoom));
    const c = cropFor({ ...next, zoom }, size.width, size.height);
    return { zoom, cx: c.x + c.w / 2, cy: c.y + c.h / 2 };
  }, [size]);

  const zoomTo = (zoom: number) => setView((current) => settle({ ...current, zoom }));

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (!crop) return;
    event.currentTarget.setPointerCapture(event.pointerId);
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    const points = [...pointers.current.values()];
    const distance = points.length > 1 ? Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y) : 0;
    const mid = points.length > 1 ? { x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2 } : points[0];
    gesture.current = { view, x: mid.x, y: mid.y, distance };
    setDragging(true);
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const start = gesture.current;
    const box = stage.current?.getBoundingClientRect();
    if (!start || !box || !size || !pointers.current.has(event.pointerId)) return;
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    const points = [...pointers.current.values()];
    const mid = points.length > 1 ? { x: (points[0].x + points[1].x) / 2, y: (points[0].y + points[1].y) / 2 } : points[0];
    let zoom = start.view.zoom;
    if (points.length > 1 && start.distance > 0) {
      zoom = start.view.zoom * (Math.hypot(points[0].x - points[1].x, points[0].y - points[1].y) / start.distance);
    }
    // The frame shows crop.w of the photo across box.width: one pixel of drag = crop.w / box.width.
    const c = cropFor({ ...start.view, zoom }, size.width, size.height);
    setView(settle({
      zoom,
      cx: start.view.cx - ((mid.x - start.x) / box.width) * c.w,
      cy: start.view.cy - ((mid.y - start.y) / box.height) * c.h,
    }));
  };

  const onPointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    pointers.current.delete(event.pointerId);
    // A finger lifted mid-pinch: carry on from here with the one left.
    const rest = [...pointers.current.values()];
    gesture.current = rest.length ? { view, x: rest[0].x, y: rest[0].y, distance: 0 } : null;
    if (!rest.length) setDragging(false);
  };

  // Wheel zooms the photo, not the dialog: React's wheel listener is passive, so attach our own.
  useEffect(() => {
    const node = stage.current;
    if (!node || !size) return;
    const onWheel = (event: globalThis.WheelEvent) => {
      event.preventDefault();
      const factor = event.deltaY < 0 ? 1.08 : 1 / 1.08;
      setView((current) => settle({ ...current, zoom: current.zoom * factor }));
    };
    node.addEventListener("wheel", onWheel, { passive: false });
    return () => node.removeEventListener("wheel", onWheel);
  }, [settle, size]);

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    if (!crop) return;
    const step = event.shiftKey ? 0.1 : 0.02;
    const moves: Record<string, [number, number]> = { ArrowLeft: [-1, 0], ArrowRight: [1, 0], ArrowUp: [0, -1], ArrowDown: [0, 1] };
    if (moves[event.key]) {
      event.preventDefault();
      const [dx, dy] = moves[event.key];
      setView((current) => settle({ ...current, cx: current.cx + dx * step * crop.w, cy: current.cy + dy * step * crop.h }));
    } else if (event.key === "+" || event.key === "=") {
      event.preventDefault();
      zoomTo(view.zoom * 1.1);
    } else if (event.key === "-") {
      event.preventDefault();
      zoomTo(view.zoom / 1.1);
    }
  };

  const save = async () => {
    if (!crop || !image.current) return;
    setSaving(true);
    try {
      onSave(crop, await framedCopy(image.current, crop));
    } finally {
      setSaving(false);
    }
  };

  const working = busy || saving;
  const framed = crop ? <img alt="" draggable={false} src={src} style={cropImageStyle(crop)} /> : null;

  return (
    <dialog
      aria-labelledby="cover-editor-title"
      className="cover-editor"
      onCancel={(event) => { event.preventDefault(); if (!working) onCancel(); }}
      ref={dialog}
    >
      <header className="cover-editor-head">
        <div>
          <h2 id="cover-editor-title">Ảnh bìa · {roomName}</h2>
          <p>Kéo để di chuyển, cuộn hoặc chụm hai ngón để phóng to.</p>
        </div>
        <button aria-label="Đóng" className="cover-icon-button" disabled={working} onClick={onCancel} type="button"><X size={18} /></button>
      </header>

      <div className="cover-editor-body">
        <section className="cover-editor-work" aria-label="Khung ảnh bìa">
          <div
            aria-label="Khung ảnh bìa: kéo để di chuyển, phím mũi tên để dịch, + và − để phóng to"
            className={dragging ? "cover-stage is-dragging" : "cover-stage"}
            onKeyDown={onKeyDown}
            onPointerCancel={onPointerEnd}
            onPointerDown={onPointerDown}
            onPointerMove={onPointerMove}
            onPointerUp={onPointerEnd}
            ref={stage}
            role="application"
            tabIndex={0}
          >
            {/* Hidden loader: gives the natural size and the pixels for the framed copy. */}
            <img alt="" className="cover-stage-source" crossOrigin="anonymous" onError={() => setFailed(true)} onLoad={onLoad} ref={image} src={src} />
            {framed}
            {crop ? <span aria-hidden="true" className="cover-stage-grid" /> : null}
            {!crop && !failed ? <span className="cover-stage-state" role="status"><Loader2 className="spin" size={22} />Đang mở ảnh</span> : null}
            {failed ? <span className="cover-stage-state is-error" role="alert">Không mở được ảnh. Hãy chọn ảnh khác.</span> : null}
          </div>

          <div className="cover-zoom">
            <button aria-label="Thu nhỏ" className="cover-icon-button" disabled={!crop || view.zoom <= 1} onClick={() => zoomTo(view.zoom / 1.2)} type="button"><Minus size={16} /></button>
            <input
              aria-label="Phóng to"
              aria-valuetext={`${Math.round(view.zoom * 100)}%`}
              disabled={!crop}
              max={MAX_ZOOM}
              min={1}
              onChange={(event) => zoomTo(Number(event.target.value))}
              step={0.01}
              type="range"
              value={view.zoom}
            />
            <button aria-label="Phóng to" className="cover-icon-button" disabled={!crop || view.zoom >= MAX_ZOOM} onClick={() => zoomTo(view.zoom * 1.2)} type="button"><Plus size={16} /></button>
            <output className="cover-zoom-value">{Math.round(view.zoom * 100)}%</output>
            <button className="text-action" disabled={!crop} onClick={() => setView({ zoom: 1, cx: 0.5, cy: 0.5 })} type="button"><Maximize size={15} />Vừa khung</button>
          </div>
        </section>

        <section className="cover-preview" aria-labelledby="cover-preview-title">
          <h3 id="cover-preview-title">Xem trước trang đặt lịch</h3>
          <figure className="cover-preview-surface">
            <figcaption>Danh sách phòng</figcaption>
            <div className="room-row cover-preview-row">
              <span className="room-row-cover cover-framed">{framed}</span>
              <span className="room-row-text">
                <strong>{roomName}</strong>
                {capacity ? <small>{capacity}</small> : null}
                <span className="room-row-price">{priceLine}</span>
              </span>
              <ChevronRight aria-hidden="true" className="room-row-go" size={20} />
            </div>
          </figure>
          <figure className="cover-preview-surface">
            <figcaption>Trang phòng</figcaption>
            <div className="room-detail">
              <div className="room-hero cover-framed">{framed}</div>
              <h2>{roomName}</h2>
              {capacity ? <p className="room-detail-capacity">{capacity}</p> : null}
            </div>
          </figure>
        </section>
      </div>

      <footer className="cover-editor-foot">
        {error ? <p className="cover-editor-error" role="alert">{error}</p> : null}
        <button className="text-action" disabled={working} onClick={onCancel} type="button">Hủy</button>
        <button className="primary-action" disabled={!crop || working} onClick={save} type="button">
          {working ? <Loader2 className="spin" size={16} /> : null}
          Lưu ảnh bìa
        </button>
      </footer>
    </dialog>
  );
}
