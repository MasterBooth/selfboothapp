"use client";

import {
  ArrowLeft,
  ArrowRight,
  Check,
  ChevronLeft,
  ChevronRight,
  Download,
  FlipHorizontal2,
  ImageIcon,
  ImagePlus,
  Link2,
  Loader2,
  Minus,
  Move,
  Palette,
  Plus,
  Printer,
  RotateCcw,
  RotateCw,
  Scan,
  X,
  ZoomIn,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { ChangeEvent, KeyboardEvent, PointerEvent } from "react";
import {
  type CaptureAsset,
  type ComposePayload,
  COMPOSE_KEY,
  FlowSteps,
  MAX_UPLOAD_BYTES,
  apiJson,
  apiSend,
  flowHref,
  flowParams,
  libraryEndpoint,
  triggerDownload,
} from "./flow";
import {
  type FrameRect,
  type SlotTransform,
  DEFAULT_TRANSFORM,
  FILL_BLEED,
  MAX_ZOOM,
  SOFT_EDGE,
  clampTransform,
  drawSlot,
  featherMask,
  fillBox,
  frameGroups,
  initialSlotAssets,
  minZoom,
  normalizeAngle,
  panLimits,
  photoTransform,
  slotLayout,
} from "./layout";
import { RotateDial } from "./rotate";
import { type FilterItem, canvasToBlob, filteredCanvas, loadImageElement, loadLut } from "./lut";
import { Thumb, screenCopyFor } from "./thumbs";
import { reviveUploads, removeComposed, saveComposed, saveUploads, uploadScope } from "./uploads";
import { type UploadedPrint, registerComposed, uploadPrintFile } from "./composedPrints";

type ProgressState = { open: boolean; title: string; detail: string; current: number; total: number };
type PrintOutput = { url: string; width: number; height: number; fileName: string; blob: Blob };
type LinkState = "idle" | "copying" | "copied" | "manual";
type Size = { width: number; height: number };
type Tool = "photo" | "filter" | "zoom" | "move" | "rotate";
type Geometry = { width: number; height: number; left: number; top: number };

/** Indexes into FLOW_STEPS: 3 Chỉnh sửa · 4 Tạo ảnh in · 5 In ảnh. */
type Stage = 3 | 4 | 5;

const TOOLS: Array<{ id: Tool; label: string; icon: typeof ImageIcon }> = [
  { id: "photo", label: "Ảnh", icon: ImageIcon },
  { id: "filter", label: "Bộ lọc", icon: Palette },
  { id: "zoom", label: "Zoom", icon: ZoomIn },
  { id: "move", label: "Di chuyển", icon: Move },
  { id: "rotate", label: "Xoay", icon: RotateCw },
];

/** Long side of the filtered photo used on screen; the print render filters at full need. */
const PREVIEW_MAX_SIDE = 1600;
/** Breathing room around the slot being edited, as a fraction of its longer side. */
const SLOT_PADDING = 0.1;
/** Breathing room around the group on screen. */
const GROUP_PADDING = 0.02;
/** Box each group thumbnail is fitted into, in px. */
const THUMB_BOX = { width: 56, height: 72 };

function previewKey(asset: CaptureAsset, filterId: string) {
  return `${asset.asset_id}|${filterId}`;
}

/**
 * Where to place the whole frame (frame units: height 1, width = ratio) so that
 * `region` fills `box`, centred. Returns the frame's on-screen size and offset.
 */
function fitRegion(region: FrameRect, box: Size, ratio: number, padding: number): Geometry | null {
  if (!box.width || !box.height) return null;
  const sx = region.x * ratio;
  const sy = region.y;
  const sw = region.width * ratio;
  const sh = region.height;
  const pad = padding * Math.max(sw, sh);
  const rx = Math.max(0, sx - pad);
  const ry = Math.max(0, sy - pad);
  const rw = Math.min(ratio, sx + sw + pad) - rx;
  const rh = Math.min(1, sy + sh + pad) - ry;
  const scale = Math.min(box.width / rw, box.height / rh);
  return {
    width: ratio * scale,
    height: scale,
    left: box.width / 2 - (rx + rw / 2) * scale,
    top: box.height / 2 - (ry + rh / 2) * scale,
  };
}

export default function ComposePage() {
  const [payload, setPayload] = useState<ComposePayload | null>(null);
  const [loaded, setLoaded] = useState(false);
  const [assets, setAssets] = useState<CaptureAsset[]>([]);
  const [slotImages, setSlotImages] = useState<Array<CaptureAsset | null>>([]);
  const [transforms, setTransforms] = useState<SlotTransform[]>([]);
  const [slotFilters, setSlotFilters] = useState<Array<string | null>>([]);
  const [filters, setFilters] = useState<FilterItem[]>([]);
  const [filtered, setFiltered] = useState<Record<string, string>>({});
  const [filtering, setFiltering] = useState<Record<string, boolean>>({});
  /** asset_id → screen-size copy (see screenCopyFor). */
  const [screens, setScreens] = useState<Record<string, string>>({});
  const [activeGroup, setActiveGroup] = useState(0);
  /** The slot being edited; null shows the whole group. */
  const [editSlot, setEditSlot] = useState<number | null>(null);
  const [tool, setTool] = useState<Tool>("photo");
  const [stage, setStage] = useState<Stage>(3);
  const [output, setOutput] = useState<PrintOutput | null>(null);
  const [frameSize, setFrameSize] = useState<Size | null>(null);
  const [viewBox, setViewBox] = useState<Size>({ width: 0, height: 0 });
  const [imageSizes, setImageSizes] = useState<Record<string, Size>>({});
  const [error, setError] = useState("");
  const [progress, setProgress] = useState<ProgressState>({ open: false, title: "", detail: "", current: 0, total: 0 });
  const [printQueued, setPrintQueued] = useState(false);
  const [linkState, setLinkState] = useState<LinkState>("idle");
  const [shareLink, setShareLink] = useState("");
  const uploadedPrint = useRef<{ blob: Blob; done: Promise<UploadedPrint> } | null>(null);
  const localUrls = useRef<string[]>([]);
  const viewRef = useRef<HTMLDivElement | null>(null);
  const pointers = useRef(new Map<number, { x: number; y: number }>());
  const gesture = useRef<{ slot: number; rect: DOMRect; pinchDistance: number; pinchZoom: number } | null>(null);
  const tap = useRef<{ id: number; x: number; y: number } | null>(null);

  useEffect(() => {
    const raw = sessionStorage.getItem(COMPOSE_KEY);
    setLoaded(true);
    if (!raw) return;
    try {
      const next = JSON.parse(raw) as ComposePayload;
      const slots = next.frame.slotRects.slice(0, Math.max(1, next.frame.slots));
      const ratio = next.frame.width && next.frame.height ? next.frame.width / next.frame.height : 4 / 5;
      setPayload({ ...next, frame: { ...next.frame, slotRects: slots } });
      if (next.frame.width && next.frame.height) setFrameSize({ width: next.frame.width, height: next.frame.height });
      setTransforms(slots.map(() => DEFAULT_TRANSFORM));
      setSlotFilters(slots.map(() => null));
      // Uploaded photos arrive with blob URLs from the previous page, which are dead now.
      void reviveUploads(next.assets).then((revived) => {
        localUrls.current.push(...revived.filter((asset) => asset.source === "upload").map((asset) => asset.url));
        setAssets(revived);
        setSlotImages(initialSlotAssets(slots.length, frameGroups(slots, ratio), revived));
        if (revived.length < next.assets.length) setError("Một số ảnh tải lên không còn trong bộ nhớ trình duyệt, hãy chọn lại.");
      });
    } catch {
      setError("Không mở được dữ liệu ghép frame.");
    }
    let saved: Partial<ComposePayload> = {};
    try {
      saved = JSON.parse(raw || "{}") as ComposePayload;
    } catch {
      // Reported above.
    }
    const filterCtx = { token: saved.token || "", machineId: saved.machineId || "", sessionId: saved.sessionId || "" };
    apiJson<{ filters?: FilterItem[] }>(libraryEndpoint(filterCtx, "filters"))
      .then((data) => setFilters(data.filters ?? []))
      .catch(() => setFilters([]));
  }, []);

  useEffect(() => () => {
    localUrls.current.forEach((url) => URL.revokeObjectURL(url));
    localUrls.current = [];
  }, []);

  useEffect(() => {
    const node = viewRef.current;
    if (!node) return;
    const observer = new ResizeObserver(([entry]) => setViewBox({ width: entry.contentRect.width, height: entry.contentRect.height }));
    observer.observe(node);
    return () => observer.disconnect();
  }, [payload, stage]);

  const frame = payload?.frame ?? null;
  /** Full-size frame PNG: only fetched to render the print. */
  const frameUrl = frame?.image_url || frame?.preview_url || frame?.thumbnail_url || "";
  /** Small preview for the screen (the full A4 PNG is ~110 MB once decoded on a phone). */
  const frameDisplayUrl = frame?.preview_url || frame?.thumbnail_url || frameUrl;
  const frameRatio = frameSize ? frameSize.width / frameSize.height : 4 / 5;

  // Bring the full frame PNG (up to ~20 MB) into the browser cache while the guest edits, so
  // rendering the print does not wait for it. Only the bytes: decoded it would hold ~110 MB.
  useEffect(() => {
    if (!frameUrl || frameUrl === frameDisplayUrl) return;
    const controller = new AbortController();
    fetch(frameUrl, { signal: controller.signal }).then((response) => response.arrayBuffer()).catch(() => undefined);
    return () => controller.abort();
  }, [frameDisplayUrl, frameUrl]);
  const slotCount = frame?.slotRects.length ?? 0;
  const filledCount = slotImages.filter(Boolean).length;
  const filterById = useMemo(() => new Map(filters.map((filter) => [filter.id, filter])), [filters]);

  const { groups } = useMemo(() => frameGroups(frame?.slotRects ?? [], frameRatio), [frame, frameRatio]);
  /** Every slot in editing order: group by group, reading order inside each. */
  const slotOrder = useMemo(() => groups.flatMap((group) => group.slots), [groups]);
  const slotPlace = useMemo(() => {
    const place = new Map<number, { group: number; position: number }>();
    groups.forEach((group, g) => group.slots.forEach((slot, p) => place.set(slot, { group: g, position: p })));
    return place;
  }, [groups]);
  const group = groups[Math.min(activeGroup, groups.length - 1)] ?? groups[0];

  const slotName = (index: number) => {
    const place = slotPlace.get(index);
    if (!place) return `Ô ${index + 1}`;
    return groups.length > 1 ? `Nhóm ${place.group + 1} · Ô ${place.position + 1}` : `Ô ${place.position + 1}`;
  };

  /** Real-pixel aspect of a slot (slot rects are fractions of the frame). */
  const slotAspect = useCallback((index: number) => {
    const slot = frame?.slotRects[index];
    if (!slot) return 1;
    return (slot.width * frameRatio) / slot.height;
  }, [frame, frameRatio]);

  const imageAspect = useCallback((asset: CaptureAsset | null) => {
    const size = asset ? imageSizes[asset.asset_id] : undefined;
    return size ? size.width / size.height : null;
  }, [imageSizes]);

  const activeAsset = editSlot !== null ? slotImages[editSlot] ?? null : null;
  const activeAspect = imageAspect(activeAsset);
  const activeTransform = (editSlot !== null && transforms[editSlot]) || DEFAULT_TRANSFORM;
  const activeMinZoom = activeAspect && editSlot !== null ? minZoom(slotAspect(editSlot), activeAspect, activeTransform.rotate) : 1;
  const activeLimits = activeAspect && editSlot !== null ? panLimits(slotAspect(editSlot), activeAspect, activeTransform.zoom, activeTransform.rotate) : { x: 0, y: 0 };
  const activeFilterId = editSlot !== null ? slotFilters[editSlot] ?? null : null;

  const sessionParams = flowParams({ token: payload?.token || "", machineId: payload?.machineId || "", sessionId: payload?.sessionId || "" });
  const galleryHref = flowHref("/gallery", sessionParams);
  const framesHref = flowHref("/compose/frames", { ...sessionParams, frame_id: frame?.frame_id });
  const photosHref = flowHref("/compose/photos", { ...sessionParams, frame_id: frame?.frame_id });

  // Build the on-screen filtered copy of every photo that has a filter.
  useEffect(() => {
    slotImages.forEach((asset, index) => {
      const filterId = slotFilters[index];
      const filter = filterId ? filterById.get(filterId) : undefined;
      if (!asset || !filter) return;
      const key = previewKey(asset, filter.id);
      // `key in filtering` covers in-flight, done and failed, so a broken LUT is not retried in a loop.
      if (filtered[key] || key in filtering) return;
      setFiltering((current) => ({ ...current, [key]: true }));
      Promise.all([loadImageElement(asset.preview_url || asset.url), loadLut(filter)])
        .then(([image, lut]) => canvasToBlob(filteredCanvas(image, lut, PREVIEW_MAX_SIDE), "image/jpeg", 0.9))
        .then((blob) => {
          const url = URL.createObjectURL(blob);
          localUrls.current.push(url);
          setFiltered((current) => ({ ...current, [key]: url }));
        })
        .catch(() => setError(`Không áp được bộ lọc "${filter.name}".`))
        .finally(() => setFiltering((current) => ({ ...current, [key]: false })));
    });
  }, [filterById, filtered, filtering, slotFilters, slotImages]);

  // Screen-size copies of the photos in slots (the print still reads the originals).
  useEffect(() => {
    for (const asset of slotImages) {
      if (!asset || screens[asset.asset_id]) continue;
      screenCopyFor(asset)
        .then((url) => setScreens((current) => current[asset.asset_id] ? current : { ...current, [asset.asset_id]: url }))
        .catch(() => setScreens((current) => ({ ...current, [asset.asset_id]: asset.preview_url || asset.url })));
    }
  }, [screens, slotImages]);

  const displaySrc = (index: number) => {
    const asset = slotImages[index];
    if (!asset) return "";
    const filterId = slotFilters[index];
    const url = filterId ? filtered[previewKey(asset, filterId)] : "";
    // Until the screen copy is ready, show the server thumbnail if there is a real one.
    return url || screens[asset.asset_id] || (asset.has_thumbnail ? asset.thumbnail_url : "");
  };

  const discardOutput = () => {
    setOutput((current) => {
      if (current) URL.revokeObjectURL(current.url);
      return null;
    });
  };

  const closeEdit = useCallback(() => {
    setEditSlot(null);
    pointers.current.clear();
    gesture.current = null;
    tap.current = null;
  }, []);

  const goToStage = (next: Stage) => {
    if (next === 3) discardOutput();
    closeEdit();
    setStage(next);
  };

  const reach = (index: number) => {
    if (index === 0) return galleryHref;
    if (index === 1) return framesHref;
    if (index === 2) return photosHref;
    if (index === 3) return () => goToStage(3);
    if (index === 4 && output) return () => goToStage(4);
    return undefined;
  };

  /** Apply a change to one slot's transform, clamped to what that photo allows. */
  const changeTransform = useCallback((index: number, change: (current: SlotTransform) => SlotTransform) => {
    const aspect = imageAspect(slotImages[index] ?? null);
    setTransforms((current) => current.map((item, i) => {
      if (i !== index) return item;
      const next = change(item);
      return aspect ? clampTransform(next, slotAspect(index), aspect) : next;
    }));
  }, [imageAspect, slotAspect, slotImages]);

  const setZoom = (zoom: number) => {
    if (editSlot !== null) changeTransform(editSlot, (t) => ({ ...t, zoom }));
  };

  const rememberSize = (asset: CaptureAsset, image: HTMLImageElement) => {
    if (!image.naturalWidth || !image.naturalHeight || imageSizes[asset.asset_id]) return;
    setImageSizes((current) => ({ ...current, [asset.asset_id]: { width: image.naturalWidth, height: image.naturalHeight } }));
  };

  const openSlot = (index: number, keepTool = false) => {
    setEditSlot(index);
    setActiveGroup(slotPlace.get(index)?.group ?? 0);
    if (!slotImages[index]) setTool("photo");
    else if (!keepTool) setTool("zoom");
  };

  useEffect(() => {
    if (editSlot === null) return;
    const onKey = (event: globalThis.KeyboardEvent) => { if (event.key === "Escape") closeEdit(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [closeEdit, editSlot]);

  const moveEdit = (direction: -1 | 1) => {
    if (editSlot === null || slotOrder.length === 0) return;
    const at = slotOrder.indexOf(editSlot);
    openSlot(slotOrder[(at + direction + slotOrder.length) % slotOrder.length], true);
  };

  /** Slot in the given slot's group that holds this photo, or -1. Groups never reach into each other. */
  const slotInGroupWith = (slot: number, asset: CaptureAsset) => {
    const own = groups[slotPlace.get(slot)?.group ?? 0]?.slots ?? [];
    return own.find((index) => slotImages[index]?.asset_id === asset.asset_id) ?? -1;
  };

  /** Put a photo in the slot being edited. If it already sits in another slot of this group, the two swap. */
  const placeInActiveSlot = (asset: CaptureAsset | null) => {
    if (editSlot === null) return;
    const from = asset ? slotInGroupWith(editSlot, asset) : -1;
    if (from === editSlot) return;
    const nextImages = [...slotImages];
    const nextTransforms = [...transforms];
    const nextFilters = [...slotFilters];
    if (from >= 0) {
      nextImages[from] = slotImages[editSlot];
      nextTransforms[from] = DEFAULT_TRANSFORM;
      nextFilters[from] = slotFilters[editSlot] ?? null;
    }
    nextImages[editSlot] = asset;
    nextTransforms[editSlot] = DEFAULT_TRANSFORM;
    if (from >= 0) nextFilters[editSlot] = slotFilters[from] ?? null;
    setSlotImages(nextImages);
    setTransforms(nextTransforms);
    setSlotFilters(nextFilters);
  };

  const setActiveFilter = (filterId: string | null) => {
    setSlotFilters((current) => current.map((item, index) => index === editSlot ? filterId : item));
  };

  const uploadForSlot = async (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;
    if (!file.type.startsWith("image/") || file.size > MAX_UPLOAD_BYTES) {
      setError("Ảnh tải lên phải là file ảnh nhỏ hơn 50MB.");
      return;
    }
    setError("");
    let asset: CaptureAsset | undefined;
    try {
      [asset] = await saveUploads(uploadScope({ token: payload?.token, machineId: payload?.machineId, sessionId: payload?.sessionId }), [file], assets.length);
    } catch {
      // Storage blocked (private mode): still usable on this page, just not kept.
      const url = URL.createObjectURL(file);
      asset = {
        asset_id: `compose-${crypto.randomUUID()}`,
        kind: "upload",
        file_name: file.name,
        content_type: file.type || "image/jpeg",
        size_bytes: file.size,
        photo_index: assets.length + 1,
        committed_at: new Date().toISOString(),
        url,
        thumbnail_url: url,
        preview_url: url,
        source: "upload",
      };
    }
    localUrls.current.push(asset.url);
    setAssets((current) => [...current, asset]);
    placeInActiveSlot(asset);
  };

  // --- Gestures on the stage while a slot is open: drag / pinch its photo, tap outside closes.
  const handlePointerDown = (event: PointerEvent<HTMLDivElement>) => {
    if (editSlot === null) return;
    const target = (event.target as HTMLElement).closest<HTMLElement>("[data-slot]");
    const onActive = target && Number(target.dataset.slot) === editSlot;
    if (!gesture.current) {
      if (!onActive || !slotImages[editSlot]) {
        tap.current = { id: event.pointerId, x: event.clientX, y: event.clientY };
        return;
      }
      gesture.current = { slot: editSlot, rect: target.getBoundingClientRect(), pinchDistance: 0, pinchZoom: 1 };
    }
    tap.current = null;
    event.currentTarget.setPointerCapture(event.pointerId);
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (pointers.current.size === 2) {
      const [a, b] = Array.from(pointers.current.values());
      gesture.current.pinchDistance = Math.hypot(a.x - b.x, a.y - b.y);
      gesture.current.pinchZoom = transforms[gesture.current.slot]?.zoom ?? 1;
    }
  };

  const handlePointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const active = gesture.current;
    if (!active || !pointers.current.has(event.pointerId)) return;
    const previous = pointers.current.get(event.pointerId)!;
    pointers.current.set(event.pointerId, { x: event.clientX, y: event.clientY });
    if (pointers.current.size >= 2 && active.pinchDistance > 0) {
      const [a, b] = Array.from(pointers.current.values());
      const zoom = active.pinchZoom * (Math.hypot(a.x - b.x, a.y - b.y) / active.pinchDistance);
      changeTransform(active.slot, (t) => ({ ...t, zoom }));
      return;
    }
    const dx = (event.clientX - previous.x) / Math.max(1, active.rect.width);
    const dy = (event.clientY - previous.y) / Math.max(1, active.rect.height);
    changeTransform(active.slot, (t) => ({ ...t, x: t.x + dx, y: t.y + dy }));
  };

  const handlePointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    const pending = tap.current;
    if (pending && pending.id === event.pointerId) {
      tap.current = null;
      if (event.type === "pointerup" && Math.hypot(event.clientX - pending.x, event.clientY - pending.y) < 8) closeEdit();
      return;
    }
    pointers.current.delete(event.pointerId);
    if (pointers.current.size === 1 && gesture.current) gesture.current.pinchDistance = 0;
    if (pointers.current.size === 0) gesture.current = null;
  };

  const handleSlotKey = (event: KeyboardEvent<HTMLDivElement>, index: number) => {
    if (event.key === "Enter" || event.key === " ") {
      event.preventDefault();
      openSlot(index);
    }
  };

  const handleViewKey = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = 0.02;
    const keys: Record<string, (t: SlotTransform) => SlotTransform> = {
      ArrowLeft: (t) => ({ ...t, x: t.x - step }),
      ArrowRight: (t) => ({ ...t, x: t.x + step }),
      ArrowUp: (t) => ({ ...t, y: t.y - step }),
      ArrowDown: (t) => ({ ...t, y: t.y + step }),
      "+": (t) => ({ ...t, zoom: t.zoom + 0.05 }),
      "=": (t) => ({ ...t, zoom: t.zoom + 0.05 }),
      "-": (t) => ({ ...t, zoom: t.zoom - 0.05 }),
      "0": (t) => ({ ...DEFAULT_TRANSFORM, rotate: t.rotate, flip: t.flip }),
      "[": (t) => ({ ...t, rotate: normalizeAngle((t.rotate ?? 0) - 90) }),
      "]": (t) => ({ ...t, rotate: normalizeAngle((t.rotate ?? 0) + 90) }),
    };
    const change = keys[event.key];
    if (!change || editSlot === null) return;
    event.preventDefault();
    changeTransform(editSlot, change);
  };

  const renderPrint = async () => {
    if (!frame || !frameUrl) return;
    setError("");
    closeEdit();
    const total = frame.slotRects.length + 1;
    setProgress({ open: true, title: "Đang tạo ảnh in", detail: "Chuẩn bị ảnh", current: 0, total });
    try {
      const frameImage = await loadImageElement(frameUrl);
      const width = frame.width || frameImage.naturalWidth;
      const height = frame.height || frameImage.naturalHeight;
      const canvas = document.createElement("canvas");
      canvas.width = width;
      canvas.height = height;
      const ctx = canvas.getContext("2d");
      if (!ctx) throw new Error("Trình duyệt không hỗ trợ tạo ảnh in");
      // White under everything, like the booth: an empty slot prints white, not transparent.
      ctx.fillStyle = "#fff";
      ctx.fillRect(0, 0, width, height);

      for (let index = 0; index < frame.slotRects.length; index++) {
        const slot = frame.slotRects[index];
        const asset = slotImages[index];
        if (!asset) continue;
        const filter = slotFilters[index] ? filterById.get(slotFilters[index]!) : undefined;
        setProgress({ open: true, title: "Đang tạo ảnh in", detail: filter ? `${slotName(index)} · ${filter.name}` : slotName(index), current: index + 1, total });
        const rect = { x: slot.x * width, y: slot.y * height, width: slot.width * width, height: slot.height * height };
        const image = await loadImageElement(asset.url);
        let source: HTMLImageElement | HTMLCanvasElement = image;
        if (filter) {
          // Filter only as many pixels as the slot will actually print.
          const aspect = image.naturalWidth / image.naturalHeight;
          const layout = slotLayout(rect.width / rect.height, aspect, clampTransform(transforms[index] ?? DEFAULT_TRANSFORM, rect.width / rect.height, aspect));
          const needed = Math.ceil(Math.max(layout.width * rect.width, layout.height * rect.height));
          source = filteredCanvas(image, await loadLut(filter), Math.max(512, needed));
        }
        drawSlot(ctx, source, rect, transforms[index] ?? DEFAULT_TRANSFORM);
      }

      setProgress({ open: true, title: "Đang tạo ảnh in", detail: "Phủ khung frame", current: total, total });
      ctx.drawImage(frameImage, 0, 0, width, height);
      const blob = await canvasToBlob(canvas, "image/png");
      const studioSlug = (payload?.studioName || "gallery").replace(/[^\w.-]+/g, "-");
      // "Ảnh đã ghép" keeps this very file: the same full-size PNG that is downloaded and printed.
      setProgress({ open: true, title: "Đang tạo ảnh in", detail: "Lưu vào ảnh đã ghép", current: total, total });
      let localId = "";
      try {
        localId = await saveComposed(uploadScope({ token: payload?.token, machineId: payload?.machineId, sessionId: payload?.sessionId }), blob, { name: frame.name, width, height });
      } catch {
        // Storage blocked (private mode): the server copy below is the only one.
      }
      discardOutput();
      const next: PrintOutput = {
        url: URL.createObjectURL(blob),
        width,
        height,
        fileName: `${studioSlug}-${frame.name.replace(/[^\w.-]+/g, "-")}.png`,
        blob,
      };
      setOutput(next);
      // Send it to the session now, so the studio admin and other devices see it too. The
      // browser copy is dropped once the server lists it; if sending fails it goes up from
      // the gallery later. Printing and the shared link reuse this same upload.
      const token = payload?.token;
      if (token) {
        const id = localId || crypto.randomUUID();
        void uploadPrint(next, token)
          .then(({ objectKey }) => registerComposed(token, id, objectKey, next.fileName))
          .then(() => (localId ? removeComposed(localId) : undefined))
          .catch(() => undefined);
      }
      setPrintQueued(false);
      setLinkState("idle");
      setShareLink("");
      setStage(4);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setProgress((current) => ({ ...current, open: false }));
    }
  };

  /**
   * Uploads the print PNG once per render; `title` labels the progress dialog (none: in
   * the background, as right after the render).
   */
  const uploadPrint = (target: PrintOutput, token: string, title?: string): Promise<UploadedPrint> => {
    const show = (detail: string, current: number) => {
      if (title) setProgress({ open: true, title, detail, current, total: 3 });
    };
    if (uploadedPrint.current?.blob === target.blob) {
      // Already on its way since the render: wait for it.
      show("Tải ảnh in lên studio", 2);
      return uploadedPrint.current.done;
    }
    const done = uploadPrintFile(token, target.blob, target.fileName, show);
    uploadedPrint.current = { blob: target.blob, done };
    // A failed upload is retried on the next tap.
    done.catch(() => {
      if (uploadedPrint.current?.done === done) uploadedPrint.current = null;
    });
    return done;
  };

  const printNow = async () => {
    if (!output || !payload?.token) {
      setError("Chỉ link album từ QR mới gửi được lệnh in tới máy của studio.");
      return;
    }
    setError("");
    try {
      const uploaded = await uploadPrint(output, payload.token, "Đang gửi lệnh in");
      setProgress({ open: true, title: "Đang gửi lệnh in", detail: "Đưa vào hàng chờ", current: 3, total: 3 });
      await apiSend(`/v1/public/gallery/${encodeURIComponent(payload.token)}/print-jobs`, {
        object_key: uploaded.objectKey,
        file_name: output.fileName,
        content_type: output.blob.type || "image/png",
        copies: 1,
        orientation: "auto",
      });
      setPrintQueued(true);
      setStage(5);
    } catch (err) {
      setError((err as Error).message || "Không gửi được lệnh in.");
    } finally {
      setProgress((current) => ({ ...current, open: false }));
    }
  };

  /** Copies a link to the print PNG, for guests who print at an outside shop (sent over Zalo). */
  const copyLink = async () => {
    if (!output || !payload?.token) {
      setError("Chỉ link album từ QR mới tạo được link ảnh in.");
      return;
    }
    setError("");
    setLinkState("copying");
    const link = uploadPrint(output, payload.token, "Đang tạo link ảnh in").then(({ shareUrl }) => {
      if (!shareUrl) throw new Error("Máy chủ chưa hỗ trợ link ảnh in.");
      return shareUrl;
    });
    // Safari only allows a clipboard write started inside the tap, so hand it the pending link.
    const copied = typeof ClipboardItem !== "undefined" && navigator.clipboard?.write
      ? navigator.clipboard.write([new ClipboardItem({ "text/plain": link.then((url) => new Blob([url], { type: "text/plain" })) })])
      : link.then((url) => navigator.clipboard.writeText(url));
    try {
      await copied.catch(async () => navigator.clipboard.writeText(await link));
      setShareLink(await link);
      setLinkState("copied");
      window.setTimeout(() => setLinkState((current) => current === "copied" ? "idle" : current), 2500);
    } catch {
      try {
        // The browser refused the clipboard: show the link to copy by hand.
        setShareLink(await link);
        setLinkState("manual");
      } catch (err) {
        setError((err as Error).message || "Không tạo được link ảnh in.");
        setLinkState("idle");
      }
    } finally {
      setProgress((current) => ({ ...current, open: false }));
    }
  };

  /**
   * Slots + photos for the frame drawn `stagePx` wide. On the stage, slots of the
   * open group are buttons; while a slot is open only that slot takes gestures.
   * Thumbnails are pictures only.
   */
  const renderSlots = (stagePx: number, mode: "stage" | "thumb") => frame?.slotRects.map((slot, index) => {
    const asset = slotImages[index];
    const aspect = imageAspect(asset);
    const transform = transforms[index] ?? DEFAULT_TRANSFORM;
    const layout = aspect ? slotLayout(slotAspect(index), aspect, transform) : null;
    const slotPx = { width: slot.width * stagePx, height: slot.height * stagePx / frameRatio };
    const blur = Math.max(mode === "thumb" ? 1 : 2, SOFT_EDGE * Math.min(slotPx.width, slotPx.height));
    const bleed = FILL_BLEED * blur;
    const fill = fillBox(slotPx.width, slotPx.height, transform.rotate ?? 0, bleed);
    const mask = layout ? featherMask(layout) : undefined;
    const src = displaySrc(index);
    const place = slotPlace.get(index);
    const selectable = mode === "stage" && editSlot === null && place?.group === activeGroup;
    const editing = mode === "stage" && editSlot === index;
    const busy = mode === "stage" && Boolean(asset && slotFilters[index] && filtering[previewKey(asset, slotFilters[index]!)]);
    return (
      <div
        aria-label={selectable ? `${slotName(index)}${asset ? "" : ", trống"}` : undefined}
        className={`compose-slot${editing ? " active" : ""}${asset ? " filled" : ""}${selectable || editing ? "" : " inert"}`}
        data-slot={editing ? index : undefined}
        key={`${mode}:${index}`}
        onClick={selectable ? () => openSlot(index) : undefined}
        onKeyDown={selectable ? (event) => handleSlotKey(event, index) : undefined}
        role={selectable ? "button" : undefined}
        style={{ left: `${slot.x * 100}%`, top: `${slot.y * 100}%`, width: `${slot.width * 100}%`, height: `${slot.height * 100}%` }}
        tabIndex={selectable ? 0 : undefined}
      >
        {asset ? (
          <>
            {layout?.needsFill ? (
              <img
                alt=""
                className="compose-slot-fill"
                draggable={false}
                src={src || undefined}
                style={{
                  filter: `blur(${blur.toFixed(1)}px)`,
                  left: `${(slotPx.width - fill.width) / 2}px`,
                  top: `${(slotPx.height - fill.height) / 2}px`,
                  width: `${fill.width}px`,
                  height: `${fill.height}px`,
                  transform: layout ? photoTransform(layout) : undefined,
                }}
              />
            ) : null}
            <img
              alt=""
              className="compose-slot-photo"
              draggable={false}
              onLoad={(event) => rememberSize(asset, event.currentTarget)}
              src={src || undefined}
              style={layout ? {
                transform: photoTransform(layout),
                left: `${layout.left * 100}%`,
                top: `${layout.top * 100}%`,
                width: `${layout.width * 100}%`,
                height: `${layout.height * 100}%`,
                maskImage: mask,
                WebkitMaskImage: mask,
                maskComposite: mask?.includes("), linear") ? "intersect" : undefined,
                WebkitMaskComposite: mask?.includes("), linear") ? "source-in" : undefined,
              } : { visibility: "hidden" }}
            />
            {busy ? <span className="compose-slot-busy"><Loader2 size={18} /></span> : null}
          </>
        ) : mode === "stage" ? (
          <span className="compose-slot-empty"><Plus size={18} />{(place?.position ?? index) + 1}</span>
        ) : null}
      </div>
    );
  });

  const spotRect = editSlot !== null ? frame?.slotRects[editSlot] : groups.length > 1 ? group?.region : undefined;
  const geometry = useMemo(() => {
    if (!frame || !group) return null;
    const region = editSlot !== null ? frame.slotRects[editSlot] : group.region;
    return fitRegion(region, viewBox, frameRatio, editSlot !== null ? SLOT_PADDING : GROUP_PADDING);
  }, [editSlot, frame, frameRatio, group, viewBox]);

  if (!loaded) return <main className="compose-shell" />;

  if (!frame || !payload) {
    return (
      <main className="compose-shell">
        <FlowSteps current={3} reach={(index) => index === 0 ? galleryHref : index === 1 ? framesHref : undefined} />
        <section className="compose-empty">
          <ImagePlus size={34} />
          <h1>Chưa có frame để chỉnh sửa</h1>
          {error ? <p>{error}</p> : null}
          <a className="primary-action" href={framesHref}><ArrowLeft size={18} />Chọn frame</a>
        </section>
      </main>
    );
  }

  const percent = Math.round(activeTransform.zoom * 100);
  const editPlace = editSlot !== null ? slotPlace.get(editSlot) : undefined;

  return (
    <main className={`editor-shell${editSlot !== null ? " is-editing" : ""}`}>
      <FlowSteps current={stage} reach={reach} />

      {error ? <div className="inline-message editor-message">{error}</div> : null}

      {stage >= 4 && linkState === "manual" && shareLink ? (
        <div className="share-fallback">
          <label>
            <span>Trình duyệt không cho copy tự động. Giữ vào ô dưới để copy link:</span>
            <input onFocus={(event) => event.currentTarget.select()} readOnly value={shareLink} />
          </label>
          <button aria-label="Đóng" className="gallery-icon-button" onClick={() => setLinkState("idle")} type="button"><X size={18} /></button>
        </div>
      ) : null}

      {stage === 3 && groups.length > 1 && editSlot === null ? (
        <nav className="group-row" aria-label="Nhóm ảnh trong frame">
          {groups.map((item, g) => {
            const regionW = item.region.width * frameRatio;
            const scale = Math.min(THUMB_BOX.width / regionW, THUMB_BOX.height / item.region.height);
            const filled = item.slots.filter((slot) => slotImages[slot]).length;
            const done = filled === item.slots.length;
            return (
              <button
                aria-label={`Nhóm ${g + 1}, ${filled}/${item.slots.length} ô có ảnh`}
                aria-pressed={g === activeGroup}
                className={g === activeGroup ? "group-chip active" : "group-chip"}
                key={g}
                onClick={() => setActiveGroup(g)}
                type="button"
              >
                <span className="group-chip-box" aria-hidden="true">
                  <span className="group-chip-thumb" style={{ width: regionW * scale, height: item.region.height * scale }}>
                    <span
                      className="group-chip-frame"
                      style={{ width: frameRatio * scale, height: scale, left: -item.region.x * frameRatio * scale, top: -item.region.y * scale }}
                    >
                      {renderSlots(frameRatio * scale, "thumb")}
                      <img alt="" className="compose-frame-overlay" draggable={false} src={frameDisplayUrl} />
                    </span>
                  </span>
                </span>
                <span className="group-chip-label">
                  <b>{g + 1}</b>
                  {done ? <Check size={14} strokeWidth={3} /> : <small>{filled}/{item.slots.length}</small>}
                </span>
              </button>
            );
          })}
        </nav>
      ) : null}

      <section className="editor-stage">
        {stage >= 4 && output ? (
          <figure className="print-sheet">
            <img alt={`Ảnh in ${frame.name}`} src={output.url} />
          </figure>
        ) : (
          <div
            aria-label={editSlot !== null ? `Kéo để căn ${slotName(editSlot).toLowerCase()}` : `Nhóm ${activeGroup + 1}`}
            className={editSlot !== null ? "editor-view is-slot" : "editor-view"}
            onKeyDown={editSlot !== null ? handleViewKey : undefined}
            onPointerCancel={handlePointerEnd}
            onPointerDown={handlePointerDown}
            onPointerMove={handlePointerMove}
            onPointerUp={handlePointerEnd}
            ref={viewRef}
            tabIndex={editSlot !== null ? 0 : undefined}
          >
            {geometry ? (
              <div className="editor-frame" style={{ left: geometry.left, top: geometry.top, width: geometry.width, height: geometry.height }}>
                {renderSlots(geometry.width, "stage")}
                <img
                  alt={frame.name}
                  className="compose-frame-overlay"
                  draggable={false}
                  onLoad={(event) => {
                    const image = event.currentTarget;
                    if (!frameSize && image.naturalWidth && image.naturalHeight) setFrameSize({ width: image.naturalWidth, height: image.naturalHeight });
                  }}
                  src={frameDisplayUrl}
                />
                {spotRect ? (
                  <span
                    aria-hidden="true"
                    className={editSlot !== null ? "editor-spot is-slot" : "editor-spot"}
                    style={{
                      left: `${spotRect.x * 100}%`,
                      top: `${spotRect.y * 100}%`,
                      width: `${spotRect.width * 100}%`,
                      height: `${spotRect.height * 100}%`,
                    }}
                  />
                ) : null}
              </div>
            ) : null}
          </div>
        )}
      </section>

      {stage === 3 && editSlot !== null ? (
        <div className="tool-dock" role="group" aria-label={`Chỉnh sửa ${slotName(editSlot)}`}>
          <header className="tool-dock-head">
            <button className="gallery-icon-button" onClick={() => moveEdit(-1)} title="Ô trước" type="button"><ChevronLeft size={18} /></button>
            <div>
              <strong>Ô {(editPlace?.position ?? 0) + 1}<span>/{groups[editPlace?.group ?? 0]?.slots.length ?? slotCount}</span></strong>
              {groups.length > 1 ? <small>Nhóm {(editPlace?.group ?? 0) + 1}</small> : null}
            </div>
            <button className="gallery-icon-button" onClick={() => moveEdit(1)} title="Ô sau" type="button"><ChevronRight size={18} /></button>
            <button className="primary-action tool-dock-done" onClick={closeEdit} type="button"><Check size={18} />Xong</button>
          </header>

          <div className="slot-tools-body">
            {tool === "photo" ? (
              <div className="compose-strip" aria-label="Ảnh cho ô này">
                <label className="compose-strip-upload" title="Tải ảnh từ máy">
                  <ImagePlus size={20} />
                  <span>Thêm</span>
                  <input accept="image/*" onChange={uploadForSlot} type="file" />
                </label>
                {activeAsset ? (
                  <button className="compose-strip-remove" onClick={() => { placeInActiveSlot(null); setTool("photo"); }} title="Bỏ ảnh khỏi ô" type="button">
                    <X size={20} />
                    <span>Bỏ</span>
                  </button>
                ) : null}
                {assets.map((asset) => {
                  const usedAt = slotInGroupWith(editSlot, asset);
                  const current = usedAt === editSlot;
                  return (
                    <button
                      aria-label={usedAt >= 0 ? `${asset.file_name || "Ảnh"}, đang ở ${slotName(usedAt).toLowerCase()}` : asset.file_name || "Ảnh"}
                      aria-pressed={current}
                      className={current ? "active" : ""}
                      key={asset.asset_id}
                      onClick={() => placeInActiveSlot(asset)}
                      type="button"
                    >
                      <Thumb asset={asset} token={payload.token || undefined} />
                      {usedAt >= 0 ? <span>{(slotPlace.get(usedAt)?.position ?? usedAt) + 1}</span> : null}
                    </button>
                  );
                })}
              </div>
            ) : null}

            {tool === "filter" && activeAsset ? (
              <div className="filter-row" aria-label="Bộ lọc màu">
                <button aria-pressed={!activeFilterId} className={!activeFilterId ? "active" : ""} onClick={() => setActiveFilter(null)} type="button">
                  <span className="filter-row-thumb"><Thumb asset={activeAsset} eager token={payload.token || undefined} /></span>
                  <span>Gốc</span>
                </button>
                {filters.map((filter) => {
                  const selected = activeFilterId === filter.id;
                  const busy = selected ? filtering[previewKey(activeAsset, filter.id)] : false;
                  return (
                    <button aria-pressed={selected} className={selected ? "active" : ""} key={filter.id} onClick={() => setActiveFilter(filter.id)} type="button">
                      <span className="filter-row-thumb">
                        {filter.thumbnail_url ? <img alt="" loading="lazy" src={filter.thumbnail_url} /> : <Palette size={20} />}
                        {busy ? <Loader2 className="filter-row-busy" size={18} /> : null}
                      </span>
                      <span>{filter.name}</span>
                    </button>
                  );
                })}
                {filters.length === 0 ? <p className="slot-tools-hint">Chưa có bộ lọc.</p> : null}
              </div>
            ) : null}

            {tool === "zoom" && activeAsset ? (
              <div className="slot-tool-control">
                <div className="compose-zoom-head">
                  <strong>{percent}%</strong>
                  <button className="text-action" disabled={activeTransform.zoom === 1 && activeTransform.x === 0 && activeTransform.y === 0} onClick={() => editSlot !== null && changeTransform(editSlot, (t) => ({ ...t, zoom: 1, x: 0, y: 0 }))} type="button">
                    <Scan size={16} />Vừa ô
                  </button>
                </div>
                <div className="compose-zoom-row">
                  <button aria-label="Thu nhỏ" disabled={activeTransform.zoom <= activeMinZoom + 0.001} onClick={() => setZoom(activeTransform.zoom - 0.1)} type="button"><Minus size={18} /></button>
                  <input aria-label="Mức zoom" max={MAX_ZOOM} min={activeMinZoom} onChange={(event) => setZoom(Number(event.target.value))} step={0.01} type="range" value={activeTransform.zoom} />
                  <button aria-label="Phóng to" disabled={activeTransform.zoom >= MAX_ZOOM} onClick={() => setZoom(activeTransform.zoom + 0.1)} type="button"><Plus size={18} /></button>
                </div>
              </div>
            ) : null}

            {tool === "move" && activeAsset ? (
              <div className="slot-tool-control">
                <label className="move-row">
                  <span>Ngang</span>
                  <input
                    aria-label="Di chuyển trái phải"
                    disabled={activeLimits.x < 0.001}
                    max={activeLimits.x}
                    min={-activeLimits.x}
                    onChange={(event) => editSlot !== null && changeTransform(editSlot, (t) => ({ ...t, x: Number(event.target.value) }))}
                    step={0.001}
                    type="range"
                    value={activeTransform.x}
                  />
                </label>
                <label className="move-row">
                  <span>Dọc</span>
                  <input
                    aria-label="Di chuyển lên xuống"
                    disabled={activeLimits.y < 0.001}
                    max={activeLimits.y}
                    min={-activeLimits.y}
                    onChange={(event) => editSlot !== null && changeTransform(editSlot, (t) => ({ ...t, y: Number(event.target.value) }))}
                    step={0.001}
                    type="range"
                    value={activeTransform.y}
                  />
                </label>
                <button className="text-action move-center" disabled={activeTransform.x === 0 && activeTransform.y === 0} onClick={() => editSlot !== null && changeTransform(editSlot, (t) => ({ ...t, x: 0, y: 0 }))} type="button">Căn giữa</button>
              </div>
            ) : null}

            {tool === "rotate" && activeAsset && editSlot !== null ? (
              <div className="rotate-tool">
                <RotateDial
                  onChange={(degrees) => changeTransform(editSlot, (t) => ({ ...t, rotate: degrees }))}
                  value={activeTransform.rotate ?? 0}
                />
                <div className="rotate-actions">
                  <button aria-label="Xoay trái 90 độ" onClick={() => changeTransform(editSlot, (t) => ({ ...t, rotate: normalizeAngle((t.rotate ?? 0) - 90) }))} type="button">
                    <RotateCcw size={18} />90°
                  </button>
                  <button aria-label="Xoay phải 90 độ" onClick={() => changeTransform(editSlot, (t) => ({ ...t, rotate: normalizeAngle((t.rotate ?? 0) + 90) }))} type="button">
                    <RotateCw size={18} />90°
                  </button>
                  <button
                    aria-pressed={Boolean(activeTransform.flip)}
                    className={activeTransform.flip ? "active" : ""}
                    onClick={() => changeTransform(editSlot, (t) => ({ ...t, flip: !t.flip }))}
                    type="button"
                  >
                    <FlipHorizontal2 size={18} />Lật
                  </button>
                  <button disabled={!activeTransform.rotate} onClick={() => changeTransform(editSlot, (t) => ({ ...t, rotate: 0 }))} type="button">
                    <Scan size={18} />0°
                  </button>
                </div>
              </div>
            ) : null}
          </div>

          <nav className="slot-tools-tabs" aria-label="Công cụ chỉnh sửa">
            {TOOLS.map((item) => {
              const Icon = item.icon;
              return (
                <button
                  aria-pressed={tool === item.id}
                  className={tool === item.id ? "active" : ""}
                  disabled={item.id !== "photo" && !activeAsset}
                  key={item.id}
                  onClick={() => setTool(item.id)}
                  type="button"
                >
                  <Icon size={20} />
                  <span>{item.label}</span>
                </button>
              );
            })}
          </nav>
        </div>
      ) : (
        <div className="flow-bar editor-bar">
          {stage === 3 ? (
            <>
              <p aria-live="polite"><strong>{filledCount}/{slotCount}</strong><span>ô có ảnh</span></p>
              <button className="primary-action" disabled={filledCount === 0 || progress.open} onClick={renderPrint} type="button">
                Tạo ảnh in
                <ArrowRight size={18} />
              </button>
            </>
          ) : (
            <>
              <button className="gallery-icon-button" disabled={!output} onClick={() => output && triggerDownload(output.url, output.fileName)} title="Tải ảnh in" type="button">
                <Download size={18} />
              </button>
              <button
                aria-label={linkState === "copied" ? "Đã copy link ảnh in" : "Copy link ảnh in"}
                className={`share-action${linkState === "copied" ? " is-done" : ""}`}
                disabled={!output || progress.open || linkState === "copying"}
                onClick={copyLink}
                title="Copy link ảnh in để gửi tiệm in qua Zalo"
                type="button"
              >
                {linkState === "copied" ? <Check size={18} /> : <Link2 size={18} />}
                <span>{linkState === "copied" ? "Đã copy" : "Copy link"}</span>
              </button>
              <button className="primary-action" disabled={!output || progress.open || printQueued} onClick={printNow} type="button">
                <Printer size={18} />
                {printQueued ? "Đã gửi tới máy in" : stage === 4 ? "In ảnh" : "Gửi lại"}
              </button>
            </>
          )}
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
    </main>
  );
}
