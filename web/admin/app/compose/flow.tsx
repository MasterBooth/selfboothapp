"use client";

import { Check } from "lucide-react";
import { useEffect, useState } from "react";
import type { CSSProperties } from "react";
import { useGuestBranding } from "../brand";

export type CaptureAsset = {
  asset_id: string;
  kind: string;
  file_name: string;
  content_type: string;
  size_bytes: number;
  photo_index: number;
  committed_at: string;
  url: string;
  thumbnail_url: string;
  preview_url: string;
  source?: "capture" | "upload";
  /** False: the booth sent no thumbnail and `thumbnail_url` is the full photo. */
  has_thumbnail?: boolean;
};

/** `group`: the card / strip of the frame the slot belongs to, as set in the admin. */
export type FrameSlot = { x: number; y: number; width: number; height: number; group?: number };

export type FrameTemplate = {
  frame_id: string;
  name: string;
  slots: number;
  slotRects: FrameSlot[];
  width: number;
  height: number;
  image_url?: string;
  thumbnail_url?: string;
  preview_url?: string;
};

export type ApiError = Error & { status?: number; code?: string };

export type GalleryPayload = {
  success: boolean;
  studio?: { id?: string; name?: string };
  /**
   * Present on the public gallery. `receiving`: the server's call on whether the booth may
   * still be sending photos (the booth's own counts can be wrong).
   */
  session?: { status: string; asset_sync_status: string; expected_photos: number; photos_count: number; receiving?: boolean };
  assets: CaptureAsset[];
  next_cursor: string | null;
  /** Totals over every page (photos only / everything listed). */
  total_photos?: number;
  total_items?: number;
};

export type ComposePayload = {
  studioName: string;
  /** Public gallery token from the booth QR (guest flow). */
  token?: string;
  machineId?: string;
  sessionId?: string;
  frame: FrameTemplate;
  assets: CaptureAsset[];
  createdAt: string;
};

export const COMPOSE_KEY = "selfbooth.compose";
export const MAX_UPLOAD_FILES = 200;
export const MAX_UPLOAD_BYTES = 50 * 1024 * 1024;

export async function apiJson<T>(path: string): Promise<T> {
  const response = await fetch(path, { credentials: "include", cache: "no-store" });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    // A booked guest's gallery older than 24 h: the gallery page asks for the phone number.
    const locked = /^\/v1\/public\/gallery\/([^/?]+)/.exec(path);
    if (data.error === "gallery_locked" && locked && window.location.pathname !== "/gallery") {
      window.location.href = `/gallery?t=${locked[1]}`;
    }
    const err = new Error(data.message || data.error || "Không thể tải dữ liệu") as ApiError;
    err.status = response.status;
    err.code = data.error;
    throw err;
  }
  return data as T;
}

export async function apiSend<T>(path: string, body: Record<string, unknown>): Promise<T> {
  const response = await fetch(path, {
    method: "POST",
    credentials: "include",
    cache: "no-store",
    headers: { "content-type": "application/json" },
    body: JSON.stringify(body),
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = new Error(data.message || data.error || "Không thể gửi dữ liệu") as ApiError;
    err.status = response.status;
    err.code = data.error;
    throw err;
  }
  return data as T;
}

export function assetLabel(asset: CaptureAsset, index: number) {
  if (asset.source === "upload") return asset.file_name || `Ảnh tải lên ${index + 1}`;
  if (asset.kind === "photo") return `Ảnh ${asset.photo_index || index + 1}`;
  if (asset.kind === "collage") return "Ảnh ghép";
  if (asset.kind === "video") return "Video";
  return asset.file_name || asset.kind;
}

export function isJsonAsset(asset: CaptureAsset) {
  const name = asset.file_name.toLowerCase();
  const type = asset.content_type.toLowerCase();
  return asset.kind === "manifest" || name.endsWith(".json") || type.includes("json");
}

export function normalizeFrame(raw: Record<string, unknown>, index: number): FrameTemplate | null {
  const frameId = String(raw.frame_id || raw.id || raw.asset_id || "");
  if (!frameId) return null;
  const slotSource = raw.slots ?? raw.slot_count ?? raw.photo_slots ?? raw.holes;
  const slotRects = Array.isArray(slotSource)
    ? slotSource.map((slot) => {
        const item = slot && typeof slot === "object" ? slot as Record<string, unknown> : {};
        const group = Number(item.group);
        return {
          x: Number(item.x),
          y: Number(item.y),
          width: Number(item.width),
          height: Number(item.height),
          ...(item.group !== undefined && Number.isInteger(group) ? { group } : {}),
        };
      }).filter((slot) => [slot.x, slot.y, slot.width, slot.height].every(Number.isFinite) && slot.width > 0 && slot.height > 0)
    : [];
  const slots = slotRects.length || Number(slotSource || raw.slot_count || 1);
  return {
    frame_id: frameId,
    name: String(raw.name || raw.title || `Frame ${index + 1}`),
    slots: Math.max(1, Number.isFinite(slots) ? slots : 1),
    slotRects,
    width: Number(raw.width || 0),
    height: Number(raw.height || 0),
    image_url: typeof raw.image_url === "string" ? raw.image_url : undefined,
    thumbnail_url: typeof raw.thumbnail_url === "string" ? raw.thumbnail_url : undefined,
    preview_url: typeof raw.preview_url === "string" ? raw.preview_url : undefined,
  };
}

/**
 * Which capture session the guest flow is about. Guests arrive from the booth QR with
 * `t` (gallery token, public API); staff from the admin with machine_id + session_id.
 */
export type FlowContext = { token: string; machineId: string; sessionId: string };

export function readFlowContext(): FlowContext {
  const params = new URLSearchParams(window.location.search);
  return {
    token: params.get("t") || "",
    machineId: params.get("machine_id") || "",
    sessionId: params.get("session_id") || "",
  };
}

export function hasSession(ctx: FlowContext) {
  return Boolean(ctx.token || (ctx.machineId && ctx.sessionId));
}

/** Query params that carry the session to the next step. */
export function flowParams(ctx: Pick<FlowContext, "token" | "machineId" | "sessionId">) {
  return ctx.token ? { t: ctx.token } : { machine_id: ctx.machineId, session_id: ctx.sessionId };
}

export function assetsEndpoint(ctx: FlowContext) {
  if (ctx.token) return `/v1/public/gallery/${encodeURIComponent(ctx.token)}`;
  if (ctx.machineId && ctx.sessionId) {
    return `/v1/web/capture-sessions/${encodeURIComponent(ctx.machineId)}/${encodeURIComponent(ctx.sessionId)}/assets`;
  }
  return "";
}

export function libraryEndpoint(ctx: FlowContext, kind: "frames" | "filters") {
  return ctx.token ? `/v1/public/gallery/${encodeURIComponent(ctx.token)}/${kind}` : `/v1/web/${kind}`;
}

export async function fetchFrames(ctx: FlowContext) {
  const data = await apiJson<{ frames?: Record<string, unknown>[]; items?: Record<string, unknown>[] }>(`${libraryEndpoint(ctx, "frames")}?limit=120`);
  const rawFrames = data.frames || data.items || [];
  return rawFrames.map(normalizeFrame).filter((frame): frame is FrameTemplate => Boolean(frame));
}

export function triggerDownload(url: string, filename: string) {
  const anchor = document.createElement("a");
  anchor.href = url;
  anchor.download = filename;
  anchor.target = "_blank";
  anchor.rel = "noreferrer";
  document.body.appendChild(anchor);
  anchor.click();
  anchor.remove();
}

export function flowHref(path: string, params: Record<string, string | undefined>) {
  const query = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value) query.set(key, value);
  }
  const text = query.toString();
  return text ? `${path}?${text}` : path;
}

export const FLOW_STEPS = [
  "Xem ảnh chụp",
  "Chọn frame",
  "Chọn ảnh",
  "Chỉnh sửa",
  "Tạo ảnh in",
  "In ảnh",
] as const;

type FlowStepsProps = {
  current: number;
  /** Returns a link or handler for a step the guest has already passed; undefined keeps it static. */
  reach?: (index: number) => string | (() => void) | undefined;
};

export function FlowSteps({ current, reach }: FlowStepsProps) {
  // Every guest page shows the steps, so this is where the studio's branding is applied.
  const [token, setToken] = useState<string | null>(null);
  useEffect(() => setToken(new URLSearchParams(window.location.search).get("t")), []);
  useGuestBranding(token);
  return (
    <nav className="flow-steps" aria-label="Quy trình ghép ảnh">
      <ol style={{ "--flow-progress": current / (FLOW_STEPS.length - 1), "--flow-count": FLOW_STEPS.length } as CSSProperties}>
        {FLOW_STEPS.map((label, index) => {
          const state = index < current ? "done" : index === current ? "current" : "todo";
          const target = state === "done" ? reach?.(index) : undefined;
          const body = (
            <>
              <span className="flow-dot" aria-hidden="true">
                {state === "done" ? <Check size={14} strokeWidth={3} /> : index + 1}
              </span>
              <span className="flow-label">{label}</span>
            </>
          );
          return (
            <li className={`flow-step is-${state}`} key={label} aria-current={state === "current" ? "step" : undefined}>
              {typeof target === "string" ? (
                <a href={target}>{body}</a>
              ) : typeof target === "function" ? (
                <button onClick={target} type="button">{body}</button>
              ) : (
                <span className="flow-static">{body}</span>
              )}
            </li>
          );
        })}
      </ol>
      <p className="flow-caption">
        <strong>{FLOW_STEPS[current]}</strong>
        <span>{current + 1}/{FLOW_STEPS.length}</span>
      </p>
    </nav>
  );
}
