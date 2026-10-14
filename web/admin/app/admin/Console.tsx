"use client";

import {
  Banknote,
  Building2,
  CalendarDays,
  CheckCircle2,
  CheckSquare,
  Crop,
  Copy,
  ExternalLink,
  Eye,
  EyeOff,
  ImagePlus,
  Images,
  KeyRound,
  Layers3,
  Loader2,
  LogOut,
  Monitor,
  Package,
  Palette,
  Pencil,
  Download,
  Link2,
  Plus,
  QrCode,
  Square,
  RefreshCw,
  ShieldCheck,
  Sparkles,
  Ticket,
  Trash2,
  Undo2,
  Upload,
  UserRound,
  Users,
  WifiOff,
  X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, ChangeEvent, FormEvent, ReactNode } from "react";
import { BookingsPanel } from "./BookingsPanel";
import { type CoverCrop, CoverEditor } from "./CoverEditor";
import { Turnstile, useTurnstileSiteKey } from "./Turnstile";
import { money, portalHeaders } from "./api";
import { BrandingPanel } from "./BrandingPanel";
import { DeviceCard, machineName } from "./DeviceCard";
import { copyPending, downloadQr, qrPath } from "./qr";
import { PasswordDialog } from "./PasswordDialog";
import { type AdminUser, type Section, canOpen, displayName, makeCan, roleLabel } from "./permissions";
import { StaffPanel } from "./StaffPanel";
import { type Branding, BrandMark, applyBranding } from "../brand";
import { gutterProbe, withGroups } from "../compose/layout";
import { type FilterItem, loadLut, makeFilterThumbnail, parseCube } from "../compose/lut";

type User = AdminUser;
type Studio = { id: string; name: string };
type AuthSession = { user: User; studio: Studio };
/** Owner admin at `/` (email sign-in) or the staff portal at `/staff` (username sign-in). */
export type Portal = "owner" | "staff";

type Machine = {
  id: string;
  hwid: string;
  device_name: string;
  display_name?: string;
  app_version: string;
  status: string;
  first_seen_at: string;
  last_seen_at: string;
  linked_at: string | null;
};

type Room = {
  id: string;
  name: string;
  description: string;
  capacity: string;
  status: string;
  created_at: string;
  /** Ảnh bìa khách thấy ở trang đặt lịch (bản 3:2 đã căn khung); rỗng = chưa có. */
  cover_url?: string;
  /** Ảnh gốc admin đã chọn (không cắt) + khung đã căn — để căn lại mà không phải chọn lại ảnh. */
  cover_original_url?: string;
  cover_crop?: CoverCrop | null;
};

type RoomDraft = { name: string; capacity: string; description: string };

/** Hộp căn khung ảnh bìa đang mở: ảnh mới chọn (`file`) hoặc ảnh gốc đã lưu (`file` = null). */
type CoverEdit = { room: Room; src: string; file: File | null; crop: CoverCrop | null };

type PhotoPackage = {
  id: string;
  room_id: string;
  room_name?: string;
  name: string;
  minutes: number;
  price_vnd: number;
  description: string;
  status: string;
  created_at: string;
};

type ShootCode = {
  id: string;
  code: string;
  kind: "single" | "reusable";
  minutes: number;
  price_vnd: number;
  status: string;
  created_at: string;
  used_at?: string | null;
  room_name?: string | null;
  package_name?: string | null;
};

type RevenueUse = {
  id: string;
  code: string;
  kind: string;
  minutes: number;
  price_vnd: number;
  used_at: string;
  source: string;
  session_id: string;
  hwid: string;
  device_name: string;
  package_name?: string | null;
  room_name?: string | null;
};

type RevenueSummary = {
  used_codes?: number;
  code_revenue_vnd?: number;
  single_uses?: number;
  reusable_uses?: number;
  local_uses?: number;
};

type CaptureSession = {
  machine_id: string;
  session_id: string;
  gallery_token?: string | null;
  event_id: number;
  operation_mode: string;
  status: string;
  photos_count: number;
  expected_photos: number;
  started_at: string | null;
  ended_at: string | null;
  created_at: string;
  updated_at: string;
  hwid: string;
  device_name: string;
  received_assets: number;
  last_asset_at?: string | null;
  thumbnail_url?: string;
  /** Thứ tự lượt chụp trong ngày (1 = lượt đầu tiên của studio trong ngày đó). */
  day_no?: number;
};

/** Số lượt chụp mỗi lần tải trong Thư viện ảnh. */
const LIBRARY_PAGE_SIZES = [10, 20, 50, 100];

/** `group`: which card / strip of the sheet the slot belongs to (guests edit group by group). */
type FrameSlot = { x: number; y: number; width: number; height: number; group?: number };

/** Group editor state for one frame. `active` is the group a tapped slot moves into. */
type GroupEdit = { frame: StudioFrame; width: number; height: number; slots: Array<FrameSlot & { group: number }>; active: number };

type StudioFrame = {
  id: string;
  name: string;
  width: number;
  height: number;
  slot_count: number;
  slots: FrameSlot[];
  size_bytes: number;
  /** Full-size PNG (print source). */
  image_url: string;
  /** Small copy for screens; equals image_url until the preview exists. */
  preview_url?: string;
  /** False when the API supports previews but this frame has none yet. */
  has_preview?: boolean;
  /** Grid copy (FRAME_THUMB_SIDE); equals preview_url until the thumbnail exists. */
  thumbnail_url?: string;
  /** False when the API supports thumbnails but this frame has none yet. */
  has_thumbnail?: boolean;
  created_at: string;
  updated_at: string;
};

type StudioFilter = FilterItem & { created_at: string; updated_at: string };

type ApiError = Error & { status?: number; code?: string };

/** A delete waiting out its undo window; `ids` are hidden from the lists meanwhile. */
type PendingDelete = { kind: "room" | "package" | "code"; ids: string[]; label: string };
type CodeFilter = "all" | "active" | "used" | "revoked";

/** How long a delete can still be undone before the request goes out. */
const UNDO_MS = 6000;

const codeFilters: Array<{ id: CodeFilter; label: string }> = [
  { id: "all", label: "Tất cả" },
  { id: "active", label: "Sẵn sàng" },
  { id: "used", label: "Đã dùng" },
  { id: "revoked", label: "Đã thu hồi" },
];

const REQUEST_HEADERS = { "content-type": "application/json" };
/** The staff portal remembers whose portal it is, so staff can come back to /staff. */
const PORTAL_STUDIO_KEY = "selfbooth.staff-portal.studio";
const currency = new Intl.NumberFormat("vi-VN", {
  style: "currency",
  currency: "VND",
  maximumFractionDigits: 0,
});

type NavItem = { id: Section; label: string; short: string; icon: typeof Monitor };

/**
 * The rail, grouped by the job: the counter's daily work first, then the studio's setup,
 * then the business. `short` is the label under the icon in the phone tab bar.
 */
const navGroups: Array<{ label: string; items: NavItem[] }> = [
  {
    label: "Vận hành",
    items: [
      { id: "bookings", label: "Đặt lịch", short: "Lịch", icon: CalendarDays },
      { id: "codes", label: "Mã chụp", short: "Mã", icon: Ticket },
      { id: "library", label: "Thư viện ảnh", short: "Ảnh", icon: Images },
    ],
  },
  {
    label: "Thiết lập",
    items: [
      { id: "rooms", label: "Phòng chụp", short: "Phòng", icon: Building2 },
      { id: "packages", label: "Gói chụp", short: "Gói", icon: Package },
      { id: "frames", label: "Thư viện frame", short: "Frame", icon: ImagePlus },
      { id: "filters", label: "Bộ lọc màu", short: "Bộ lọc", icon: Palette },
      { id: "devices", label: "Thiết bị", short: "Máy", icon: Monitor },
    ],
  },
  {
    label: "Studio",
    items: [
      { id: "revenue", label: "Doanh thu", short: "Doanh thu", icon: Banknote },
      { id: "brand", label: "Thương hiệu", short: "Logo", icon: Sparkles },
      { id: "staff", label: "Nhân viên", short: "Nhân viên", icon: Users },
    ],
  },
];
const navItems = navGroups.flatMap((group) => group.items);

async function apiJson<T>(path: string, init: RequestInit = {}): Promise<T> {
  const isForm = typeof FormData !== "undefined" && init.body instanceof FormData;
  const response = await fetch(path, {
    ...init,
    credentials: "include",
    headers: {
      ...portalHeaders(),
      ...(init.body && !isForm ? REQUEST_HEADERS : {}),
      ...(init.headers ?? {}),
    },
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = new Error(data.message || data.error || "Không thể kết nối máy chủ") as ApiError;
    err.status = response.status;
    err.code = data.error;
    throw err;
  }
  return data as T;
}

function formatMoney(value?: number | null) {
  return currency.format(Number(value ?? 0));
}

function formatDate(value?: string | null) {
  if (!value) return "Chưa có dữ liệu";
  const date = new Date(value);
  if (Number.isNaN(date.getTime())) return "Chưa có dữ liệu";
  return new Intl.DateTimeFormat("vi-VN", {
    hour: "2-digit",
    minute: "2-digit",
    day: "2-digit",
    month: "2-digit",
    year: "numeric",
  }).format(date);
}

function deleteRequest(job: PendingDelete, keepalive = false) {
  if (job.kind === "code" && job.ids.length > 1) {
    return apiJson("/v1/web/codes/bulk-delete", { method: "POST", body: JSON.stringify({ ids: job.ids }), keepalive });
  }
  const collection = { room: "rooms", package: "packages", code: "codes" }[job.kind];
  return apiJson(`/v1/web/${collection}/${job.ids[0]}`, { method: "DELETE", keepalive });
}

function sessionKey(session: CaptureSession) {
  return `${session.machine_id}:${session.session_id}`;
}

function machineLabel(machine: Machine) {
  return machineName(machine);
}

function codeStatus(code: ShootCode) {
  if (code.status === "used") return { label: "Đã dùng", tone: "online" };
  if (code.status === "revoked") return { label: "Đã thu hồi", tone: "disabled" };
  return { label: "Sẵn sàng", tone: "idle" };
}

function loadImage(file: Blob): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const url = URL.createObjectURL(file);
    const image = new Image();
    image.onload = () => {
      URL.revokeObjectURL(url);
      resolve(image);
    };
    image.onerror = () => {
      URL.revokeObjectURL(url);
      reject(new Error("Không đọc được file PNG"));
    };
    image.src = url;
  });
}

/** Find the transparent holes of a frame PNG and suggest how they group into cards. */
async function detectFrameSlots(file: Blob): Promise<{ width: number; height: number; slots: Array<FrameSlot & { group: number }> }> {
  const image = await loadImage(file);
  const originalWidth = image.naturalWidth || image.width;
  const originalHeight = image.naturalHeight || image.height;
  if (!originalWidth || !originalHeight) throw new Error("Frame PNG không có kích thước hợp lệ");

  const maxScan = 1400;
  const scale = Math.min(1, maxScan / Math.max(originalWidth, originalHeight));
  const width = Math.max(1, Math.round(originalWidth * scale));
  const height = Math.max(1, Math.round(originalHeight * scale));
  const canvas = document.createElement("canvas");
  canvas.width = width;
  canvas.height = height;
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) throw new Error("Trình duyệt không hỗ trợ phân tích frame");
  ctx.drawImage(image, 0, 0, width, height);
  const pixels = ctx.getImageData(0, 0, width, height).data;
  const total = width * height;
  const visited = new Uint8Array(total);
  const alphaLimit = 24;
  const minArea = Math.max(1200, Math.round(total * 0.01));
  const minSide = Math.max(12, Math.round(Math.min(width, height) * 0.04));
  const slots: FrameSlot[] = [];

  const isTransparent = (index: number) => pixels[index * 4 + 3] <= alphaLimit;
  for (let start = 0; start < total; start++) {
    if (visited[start] || !isTransparent(start)) continue;
    const stack = [start];
    visited[start] = 1;
    let count = 0;
    let minX = width;
    let minY = height;
    let maxX = 0;
    let maxY = 0;
    let touchesEdge = false;
    while (stack.length) {
      const index = stack.pop()!;
      const x = index % width;
      const y = Math.floor(index / width);
      count++;
      if (x < minX) minX = x;
      if (x > maxX) maxX = x;
      if (y < minY) minY = y;
      if (y > maxY) maxY = y;
      if (x === 0 || y === 0 || x === width - 1 || y === height - 1) touchesEdge = true;
      const neighbors = [index - 1, index + 1, index - width, index + width];
      for (const next of neighbors) {
        if (next < 0 || next >= total || visited[next]) continue;
        const nx = next % width;
        if ((next === index - 1 && nx !== x - 1) || (next === index + 1 && nx !== x + 1)) continue;
        if (!isTransparent(next)) continue;
        visited[next] = 1;
        stack.push(next);
      }
    }
    const boxWidth = maxX - minX + 1;
    const boxHeight = maxY - minY + 1;
    if (!touchesEdge && count >= minArea && boxWidth >= minSide && boxHeight >= minSide) {
      slots.push({
        x: minX / width,
        y: minY / height,
        width: boxWidth / width,
        height: boxHeight / height,
      });
    }
  }

  slots.sort((a, b) => (a.y - b.y) || (a.x - b.x));
  if (slots.length === 0) throw new Error("Không tìm thấy vùng đục lỗ trong suốt. Frame cần có lỗ trong suốt nằm bên trong PNG.");
  if (slots.length > MAX_FRAME_SLOTS) throw new Error(`Frame có ${slots.length} ô, tối đa ${MAX_FRAME_SLOTS} ô.`);
  // First guess at the cards on the sheet; the admin corrects it in the group editor.
  const grouped = withGroups(slots, originalWidth / originalHeight, gutterProbe(pixels, width, height));
  return { width: originalWidth, height: originalHeight, slots: grouped };
}

/** Long side of the frame preview guests see on screen; the full PNG stays the print source. */
const FRAME_PREVIEW_SIDE = 1600;
/** Long side of the thumbnail in the guest's frame picker grid: light enough for a dozen on a phone. */
const FRAME_THUMB_SIDE = 720;

/** Small transparent copy of a frame PNG (WebP where the browser can encode it, else PNG). */
async function makeFramePreview(file: Blob, side = FRAME_PREVIEW_SIDE): Promise<Blob> {
  const image = await loadImage(file);
  const scale = Math.min(1, side / Math.max(image.naturalWidth, image.naturalHeight));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(image.naturalWidth * scale));
  canvas.height = Math.max(1, Math.round(image.naturalHeight * scale));
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Trình duyệt không hỗ trợ tạo ảnh xem trước");
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(image, 0, 0, canvas.width, canvas.height);
  return new Promise((resolve, reject) => canvas.toBlob(
    (blob) => (blob ? resolve(blob) : reject(new Error("Không tạo được ảnh xem trước"))), "image/webp", 0.86));
}

async function putFrameCopy(frameId: string, copy: Blob, kind: "preview" | "thumb") {
  const type = copy.type === "image/webp" ? "image/webp" : "image/png";
  await apiJson(`/v1/web/frames/${frameId}/preview${kind === "thumb" ? "?kind=thumb" : ""}`, { method: "PUT", body: copy, headers: { "content-type": type } });
}

/** Thumbnail from any copy of the frame; the preview is enough and far lighter to decode. */
async function uploadFrameThumb(frameId: string, source: Blob) {
  await putFrameCopy(frameId, await makeFramePreview(source, FRAME_THUMB_SIDE), "thumb");
}

/** Preview from the full PNG, then the thumbnail from that preview. */
async function uploadFramePreview(frameId: string, file: Blob) {
  const preview = await makeFramePreview(file);
  await putFrameCopy(frameId, preview, "preview");
  await uploadFrameThumb(frameId, preview);
}

/** Same limit as the API (MAX_FRAME_SLOTS in webStudio.ts). */
const MAX_FRAME_SLOTS = 24;

/** Number groups 0, 1, 2… in the order they first appear reading the sheet, dropping empty ones. */
function compactGroups<T extends FrameSlot & { group: number }>(slots: T[]): T[] {
  const order = slots
    .map((slot, index) => ({ slot, index }))
    .sort((a, b) => (Math.abs(a.slot.y - b.slot.y) > 0.01 ? a.slot.y - b.slot.y : a.slot.x - b.slot.x));
  const renumber = new Map<number, number>();
  for (const { slot } of order) if (!renumber.has(slot.group)) renumber.set(slot.group, renumber.size);
  return slots.map((slot) => ({ ...slot, group: renumber.get(slot.group) ?? 0 }));
}

/** Eight colours cycle through the groups (tokens in globals.css). */
function groupColor(group: number) {
  return `var(--color-group-${(group % 8) + 1})`;
}

function groupCount(slots: FrameSlot[]) {
  return slots.every((slot) => Number.isInteger(slot.group)) ? new Set(slots.map((slot) => slot.group)).size : 0;
}

export function Console({ portal }: { portal: Portal }) {
  const [auth, setAuthState] = useState<AuthSession | null>(null);
  /** The session as last set, readable from callbacks created before it changed. */
  const authRef = useRef<AuthSession | null>(null);
  const setAuth = useCallback((next: AuthSession | null) => {
    authRef.current = next;
    setAuthState(next);
  }, []);
  const can = useMemo(() => makeCan(auth?.user), [auth]);
  const [section, setSection] = useState<Section>("bookings");
  const [machines, setMachines] = useState<Machine[]>([]);
  const [rooms, setRooms] = useState<Room[]>([]);
  /** Phòng đang sửa tại chỗ ("" = không) và bản nháp của nó. */
  const [editingRoom, setEditingRoom] = useState("");
  const [roomDraft, setRoomDraft] = useState<RoomDraft>({ name: "", capacity: "", description: "" });
  /** Phòng đang lưu / tải ảnh bìa ("" = không). */
  const [roomBusy, setRoomBusy] = useState("");
  const [coverEdit, setCoverEdit] = useState<CoverEdit | null>(null);
  const [packages, setPackages] = useState<PhotoPackage[]>([]);
  const [codes, setCodes] = useState<ShootCode[]>([]);
  const [frames, setFrames] = useState<StudioFrame[]>([]);
  const [revenueUses, setRevenueUses] = useState<RevenueUse[]>([]);
  const [revenueSummary, setRevenueSummary] = useState<RevenueSummary>({});
  const [captureSessions, setCaptureSessions] = useState<CaptureSession[]>([]);
  const [libraryCursor, setLibraryCursor] = useState<string | null>(null);
  const [libraryMachine, setLibraryMachine] = useState("");
  const [libraryLimit, setLibraryLimit] = useState(50);
  const [libraryFrom, setLibraryFrom] = useState("");
  const [libraryTo, setLibraryTo] = useState("");
  const [libraryNo, setLibraryNo] = useState("");
  const [selectedFrames, setSelectedFrames] = useState<string[]>([]);
  const [frameNames, setFrameNames] = useState<Record<string, string>>({});
  const [frameBusy, setFrameBusy] = useState(false);
  const [groupEdit, setGroupEdit] = useState<GroupEdit | null>(null);
  const [branding, setBranding] = useState<Branding | null>(null);
  const [filters, setFilters] = useState<StudioFilter[]>([]);
  const [filterNames, setFilterNames] = useState<Record<string, string>>({});
  const [filterBusy, setFilterBusy] = useState(false);
  const [tintThumbnails, setTintThumbnails] = useState(true);
  const [email, setEmail] = useState("");
  /** Staff portal: whose portal this is (from ?studio=, remembered after a sign-in). */
  const [portalStudio, setPortalStudio] = useState<{ id: string; name: string; branding: Branding | null } | null>(null);
  const [portalMissing, setPortalMissing] = useState(false);
  const [passwordOpen, setPasswordOpen] = useState(false);
  const [password, setPassword] = useState("");
  const [showPassword, setShowPassword] = useState(false);
  const [booting, setBooting] = useState(true);
  const [submitting, setSubmitting] = useState(false);
  /** Turnstile: site key ("" = chưa bật, null = đang đọc), token hiện có, tín hiệu cấp token mới.
   *  Chỉ đọc cấu hình khi màn đăng nhập hiện ra, không tốn request lúc đã đăng nhập. */
  const turnstileSiteKey = useTurnstileSiteKey(!auth && !booting);
  const [turnstileToken, setTurnstileToken] = useState("");
  const [turnstileReset, setTurnstileReset] = useState(0);
  const needsHumanCheck = Boolean(turnstileSiteKey);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [copied, setCopied] = useState("");
  const [codeFilter, setCodeFilter] = useState<CodeFilter>("all");
  const [selectedCodes, setSelectedCodes] = useState<string[]>([]);
  const [pendingDelete, setPendingDelete] = useState<PendingDelete | null>(null);
  const pendingRef = useRef<{ job: PendingDelete; timer: number } | null>(null);
  /** Session whose album QR is open; `url` is empty while the link is being made. */
  const [sessionQr, setSessionQr] = useState<{ session: CaptureSession; url: string } | null>(null);

  /**
   * Reads every section this account may open. Each list is its own request: a section the
   * account cannot see is not asked for, and one failing list leaves the others working.
   */
  const loadAll = useCallback(async (session: AuthSession | null = authRef.current) => {
    if (!session) return;
    const allowed = makeCan(session.user);
    const any = (...codes: string[]) => codes.some(allowed);
    setLoading(true);
    setError("");
    const skip = Promise.resolve(null);
    const [machineData, roomData, packageData, codeData, frameData, revenueData, libraryData, filterData, brandData] = await Promise.allSettled([
      any("devices.view", "library.view") ? apiJson<{ machines: Machine[] }>("/v1/web/machines") : skip,
      any("rooms.view", "packages.view", "bookings.view", "codes.view") ? apiJson<{ rooms: Room[] }>("/v1/web/rooms") : skip,
      any("rooms.view", "packages.view", "bookings.view", "codes.view") ? apiJson<{ packages: PhotoPackage[] }>("/v1/web/packages") : skip,
      allowed("codes.view") ? apiJson<{ codes: ShootCode[] }>("/v1/web/codes") : skip,
      allowed("frames.view") ? apiJson<{ frames: StudioFrame[] }>("/v1/web/frames") : skip,
      allowed("revenue.view") ? apiJson<{ summary: RevenueSummary; uses: RevenueUse[] }>("/v1/web/revenue") : skip,
      allowed("library.view") ? apiJson<{ sessions: CaptureSession[]; next_cursor: string | null }>("/v1/web/capture-sessions?limit=50") : skip,
      allowed("filters.view") ? apiJson<{ filters: StudioFilter[] }>("/v1/web/filters") : skip,
      apiJson<{ branding: Branding }>("/v1/web/branding"),
    ]);
    const value = <T,>(result: PromiseSettledResult<T | null>) => (result.status === "fulfilled" ? result.value : null);
    const failed = [machineData, roomData, packageData, codeData, frameData, revenueData, libraryData, filterData]
      .find((result): result is PromiseRejectedResult => result.status === "rejected");
    if (failed) setError((failed.reason as ApiError).message);

    const brand = value(brandData)?.branding ?? null;
    setBranding(brand);
    applyBranding(brand);
    const filterList = value(filterData)?.filters ?? [];
    setFilters(filterList);
    setFilterNames(Object.fromEntries(filterList.map((filter) => [filter.id, filter.name])));
    setMachines(value(machineData)?.machines ?? []);
    setRooms(value(roomData)?.rooms ?? []);
    setPackages(value(packageData)?.packages ?? []);
    const codeList = value(codeData)?.codes ?? [];
    setCodes(codeList);
    setSelectedCodes((current) => current.filter((id) => codeList.some((code) => code.id === id)));
    const frameList = value(frameData)?.frames ?? [];
    setFrames(frameList);
    setFrameNames(Object.fromEntries(frameList.map((frame) => [frame.id, frame.name])));
    setRevenueSummary(value(revenueData)?.summary ?? {});
    setRevenueUses(value(revenueData)?.uses ?? []);
    setCaptureSessions(value(libraryData)?.sessions ?? []);
    setLibraryCursor(value(libraryData)?.next_cursor ?? null);
    setLoading(false);
  }, []);

  /** A staff account on `/` or the owner on `/staff`: each has its own door. */
  const wrongPortal = (user: User) => (portal === "owner" ? user.role !== "owner" : user.role === "owner");

  const restoreSession = useCallback(async () => {
    setBooting(true);
    try {
      const data = await apiJson<{ success: boolean; user: User; studio: Studio }>("/v1/web/auth/me");
      if (portal === "owner" ? data.user.role !== "owner" : data.user.role === "owner") {
        window.location.replace(portal === "owner" ? `/staff?studio=${encodeURIComponent(data.studio.id)}` : "/");
        return;
      }
      const session = { user: data.user, studio: data.studio };
      setAuth(session);
      await loadAll(session);
    } catch {
      setAuth(null);
    } finally {
      setBooting(false);
    }
  }, [loadAll, portal, setAuth]);

  useEffect(() => {
    void restoreSession();
  }, [restoreSession]);

  // Staff portal sign-in screen: the studio comes from the link the owner shared.
  useEffect(() => {
    if (portal !== "staff") return;
    let studioId = new URLSearchParams(window.location.search).get("studio") || "";
    try {
      if (studioId) window.localStorage.setItem(PORTAL_STUDIO_KEY, studioId);
      else studioId = window.localStorage.getItem(PORTAL_STUDIO_KEY) || "";
    } catch {
      // Storage blocked: the link still works, it just is not remembered.
    }
    if (!studioId) {
      setPortalMissing(true);
      return;
    }
    void apiJson<{ studio: { id: string; name: string }; branding: Branding | null }>(`/v1/public/staff-portal/${encodeURIComponent(studioId)}`)
      .then((data) => {
        setPortalStudio({ ...data.studio, branding: data.branding });
        applyBranding(data.branding);
      })
      .catch(() => setPortalMissing(true));
  }, [portal]);

  // A section this account cannot open (or no longer can) falls back to the first it can.
  useEffect(() => {
    if (!auth || canOpen(section, auth.user, can)) return;
    const first = navItems.find((item) => canOpen(item.id, auth.user, can));
    if (first) setSection(first.id);
  }, [auth, can, section]);

  const stats = useMemo(() => {
    const activeCodes = codes.filter((code) => code.status === "active").length;
    return {
      machines: machines.length,
      rooms: rooms.filter((room) => room.status === "active").length,
      activeCodes,
      revenue: Number(revenueSummary.code_revenue_vnd ?? 0),
    };
  }, [codes, machines.length, revenueSummary.code_revenue_vnd, rooms]);

  async function onLogin(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    setSubmitting(true);
    setError("");
    try {
      const data = portal === "owner"
        ? await apiJson<{ success: boolean; user: User; studio: Studio }>("/v1/web/auth/login", {
            method: "POST",
            body: JSON.stringify({ email, password, turnstile_token: turnstileToken }),
          })
        : await apiJson<{ success: boolean; user: User; studio: Studio }>("/v1/web/staff/login", {
            method: "POST",
            body: JSON.stringify({ studio_id: portalStudio?.id, username: email, password, turnstile_token: turnstileToken }),
          });
      if (wrongPortal(data.user)) throw new Error("Tài khoản này đăng nhập ở cổng khác");
      const session = { user: data.user, studio: data.studio };
      setAuth(session);
      setPassword("");
      await loadAll(session);
    } catch (err) {
      setError((err as ApiError).message);
      // Mỗi token Turnstile chỉ dùng một lần: đăng nhập lại cần token mới.
      if (needsHumanCheck) setTurnstileReset((n) => n + 1);
    } finally {
      setSubmitting(false);
    }
  }

  async function onLogout() {
    setSubmitting(true);
    await commitDelete();
    try {
      await apiJson<{ success: boolean }>("/v1/web/auth/logout", { method: "POST" });
    } finally {
      setAuth(null);
      setBranding(null);
      applyBranding(null);
      setMachines([]);
      setRooms([]);
      setPackages([]);
      setCodes([]);
      setSelectedCodes([]);
      setFrames([]);
      setFrameNames({});
      setFilters([]);
      setFilterNames({});
      setSelectedFrames([]);
      setRevenueUses([]);
      setRevenueSummary({});
      setCaptureSessions([]);
      setLibraryCursor(null);
      setSubmitting(false);
    }
  }

  async function copyText(value: string) {
    try {
      await navigator.clipboard.writeText(value);
      setCopied(value);
      window.setTimeout(() => setCopied(""), 1400);
    } catch {
      setCopied("");
    }
  }

  async function createRoom(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    await mutate(event.currentTarget, "/v1/web/rooms", {
      name: form.get("name"),
      capacity: form.get("capacity"),
      description: form.get("description"),
    }, "Đã tạo phòng chụp.");
  }

  async function createPackage(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    await mutate(event.currentTarget, "/v1/web/packages", {
      room_id: form.get("room_id"),
      name: form.get("name"),
      minutes: Number(form.get("minutes")),
      price_vnd: Number(form.get("price_vnd")),
      description: form.get("description"),
    }, "Đã tạo gói chụp. Trang đặt lịch sẽ lấy gói này qua API.");
  }

  async function createCode(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    // React clears event.currentTarget once the handler yields, so keep the form node.
    const formNode = event.currentTarget;
    const form = new FormData(formNode);
    setSubmitting(true);
    setNotice("");
    setError("");
    try {
      const data = await apiJson<{ success: boolean; codes: ShootCode[] }>("/v1/web/codes", {
        method: "POST",
        body: JSON.stringify({
          package_id: form.get("package_id"),
          code: form.get("code"),
          kind: form.get("kind"),
          count: Number(form.get("count") || 1),
          note: form.get("note"),
        }),
      });
      formNode.reset();
      setCodes((current) => [...data.codes, ...current]);
      setCodeFilter((current) => (current === "all" || current === "active" ? current : "all"));
      setNotice(`Đã tạo ${data.codes.length} mã chụp.`);
      void loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setSubmitting(false);
    }
  }

  async function uploadFrame(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formNode = event.currentTarget;
    const form = new FormData(formNode);
    const file = form.get("file");
    if (!(file instanceof File) || !file.name) {
      setError("Chọn file PNG frame.");
      return;
    }
    if (file.type !== "image/png") {
      setError("Frame phải là file PNG trong suốt.");
      return;
    }
    setFrameBusy(true);
    setError("");
    setNotice("");
    try {
      const detected = await detectFrameSlots(file);
      const upload = new FormData();
      upload.set("file", file);
      upload.set("name", String(form.get("name") || file.name.replace(/\.png$/i, "")));
      upload.set("width", String(detected.width));
      upload.set("height", String(detected.height));
      upload.set("slots", JSON.stringify(detected.slots));
      const created = await apiJson<{ success: boolean; frame: StudioFrame }>("/v1/web/frames", { method: "POST", body: upload });
      try {
        await uploadFramePreview(created.frame.id, file);
      } catch {
        // Guests then see the full PNG until the library makes the preview (see backfill below).
      }
      formNode.reset();
      setNotice(`Đã tải frame: ${detected.slots.length} ô, gợi ý ${groupCount(detected.slots)} nhóm. Bấm "Nhóm ô" để kiểm tra lại nhóm.`);
      await loadAll();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setFrameBusy(false);
    }
  }

  function toggleFrame(id: string) {
    setSelectedFrames((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  async function saveFrame(frame: StudioFrame) {
    setFrameBusy(true);
    setError("");
    setNotice("");
    try {
      await apiJson(`/v1/web/frames/${frame.id}`, {
        method: "PATCH",
        body: JSON.stringify({ name: frameNames[frame.id] || frame.name, width: frame.width, height: frame.height, slots: frame.slots }),
      });
      setNotice("Đã cập nhật frame.");
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setFrameBusy(false);
    }
  }

  // Frames uploaded before previews/thumbnails existed: make the missing copies once, in the background.
  const previewTried = useRef(new Set<string>());
  useEffect(() => {
    // Storing a copy is a frame change: only accounts that may upload or edit frames do it.
    if (!can("frames.edit") && !can("frames.upload")) return;
    const missing = frames.filter((frame) =>
      (frame.has_preview === false || frame.has_thumbnail === false) && !previewTried.current.has(frame.id));
    if (missing.length === 0) return;
    missing.forEach((frame) => previewTried.current.add(frame.id));
    let cancelled = false;
    void (async () => {
      let made = 0;
      for (const frame of missing) {
        if (cancelled) return;
        try {
          // Only the thumbnail is missing: shrink the small preview, not the full PNG.
          const thumbOnly = frame.has_preview !== false && Boolean(frame.preview_url);
          const response = await fetch(thumbOnly ? frame.preview_url! : frame.image_url, { credentials: "include" });
          if (!response.ok) continue;
          const blob = await response.blob();
          await (thumbOnly ? uploadFrameThumb(frame.id, blob) : uploadFramePreview(frame.id, blob));
          made++;
        } catch {
          // Try again next time the library loads.
          previewTried.current.delete(frame.id);
        }
      }
      if (made > 0 && !cancelled) {
        const data = await apiJson<{ success: boolean; frames: StudioFrame[] }>("/v1/web/frames").catch(() => null);
        if (data && !cancelled) setFrames(data.frames);
      }
    })();
    return () => { cancelled = true; };
  }, [can, frames]);

  function openGroups(frame: StudioFrame) {
    const ratio = frame.width && frame.height ? frame.width / frame.height : 4 / 5;
    const stored = frame.slots.length > 0 && frame.slots.every((slot) => Number.isInteger(slot.group));
    // Frames uploaded before groups existed get a layout-only first guess.
    const slots = stored ? frame.slots.map((slot) => ({ ...slot, group: slot.group ?? 0 })) : withGroups(frame.slots, ratio);
    setGroupEdit({ frame, width: frame.width, height: frame.height, slots: compactGroups(slots), active: 0 });
  }

  function moveSlotToGroup(index: number) {
    setGroupEdit((current) => current && {
      ...current,
      slots: current.slots.map((slot, i) => i === index ? { ...slot, group: current.active } : slot),
    });
  }

  function newGroup() {
    setGroupEdit((current) => current && { ...current, active: Math.max(-1, ...current.slots.map((slot) => slot.group)) + 1 });
  }

  /** Detect the holes again from the stored PNG: recovers slots and gives a fresh grouping guess. */
  async function redetectGroups() {
    if (!groupEdit) return;
    setFrameBusy(true);
    setError("");
    try {
      const response = await fetch(groupEdit.frame.image_url, { credentials: "include" });
      if (!response.ok) throw new Error("Không tải được ảnh frame");
      const detected = await detectFrameSlots(await response.blob());
      setGroupEdit((current) => current && { ...current, width: detected.width, height: detected.height, slots: compactGroups(detected.slots), active: 0 });
      setNotice(`Đã nhận lại ${detected.slots.length} ô từ ảnh frame.`);
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setFrameBusy(false);
    }
  }

  async function saveGroups() {
    if (!groupEdit) return;
    setFrameBusy(true);
    setError("");
    setNotice("");
    try {
      const { frame, width, height } = groupEdit;
      const slots = compactGroups(groupEdit.slots);
      await apiJson(`/v1/web/frames/${frame.id}`, {
        method: "PATCH",
        body: JSON.stringify({ name: frameNames[frame.id] || frame.name, width, height, slots }),
      });
      setGroupEdit(null);
      setNotice(`Đã lưu ${groupCount(slots)} nhóm cho frame ${frame.name}.`);
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setFrameBusy(false);
    }
  }

  async function deleteFrames(ids: string[]) {
    if (ids.length === 0) return;
    setFrameBusy(true);
    setError("");
    setNotice("");
    try {
      if (ids.length === 1) {
        await apiJson(`/v1/web/frames/${ids[0]}`, { method: "DELETE" });
      } else {
        await apiJson("/v1/web/frames/bulk-delete", { method: "POST", body: JSON.stringify({ ids }) });
      }
      setSelectedFrames([]);
      setNotice(`Đã xóa ${ids.length} frame.`);
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setFrameBusy(false);
    }
  }

  async function uploadFilter(event: FormEvent<HTMLFormElement>) {
    event.preventDefault();
    const formNode = event.currentTarget;
    const form = new FormData(formNode);
    const file = form.get("file");
    const photo = form.get("thumbnail");
    if (!(file instanceof File) || !file.name) {
      setError("Chọn file .cube.");
      return;
    }
    if (!/\.cube$/i.test(file.name)) {
      setError("Bộ lọc phải là file .cube.");
      return;
    }
    setFilterBusy(true);
    setError("");
    setNotice("");
    try {
      const lut = parseCube(await file.text());
      const photoFile = photo instanceof File && photo.size > 0 ? photo : null;
      // No photo: tint the built-in swatch. Photo: tint it unless the admin says it already shows the look.
      const thumbnail = await makeFilterThumbnail(photoFile && !tintThumbnails ? null : lut, photoFile);
      const upload = new FormData();
      upload.set("file", file);
      upload.set("name", String(form.get("name") || file.name.replace(/\.cube$/i, "")));
      upload.set("thumbnail", new File([thumbnail], "thumbnail.jpg", { type: "image/jpeg" }));
      await apiJson("/v1/web/filters", { method: "POST", body: upload });
      formNode.reset();
      setNotice(`Đã thêm bộ lọc (LUT ${lut.size}³).`);
      await loadAll();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setFilterBusy(false);
    }
  }

  async function saveFilterName(filter: StudioFilter) {
    setFilterBusy(true);
    setError("");
    setNotice("");
    try {
      await apiJson(`/v1/web/filters/${filter.id}`, { method: "PATCH", body: JSON.stringify({ name: filterNames[filter.id] || filter.name }) });
      setNotice("Đã đổi tên bộ lọc.");
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setFilterBusy(false);
    }
  }

  async function changeFilterThumbnail(filter: StudioFilter, event: ChangeEvent<HTMLInputElement>) {
    const photo = event.target.files?.[0];
    event.currentTarget.value = "";
    if (!photo) return;
    setFilterBusy(true);
    setError("");
    setNotice("");
    try {
      const lut = tintThumbnails ? await loadLut(filter) : null;
      const thumbnail = await makeFilterThumbnail(lut, photo);
      const upload = new FormData();
      upload.set("thumbnail", new File([thumbnail], "thumbnail.jpg", { type: "image/jpeg" }));
      await apiJson(`/v1/web/filters/${filter.id}`, { method: "PATCH", body: upload });
      setNotice("Đã đổi thumbnail.");
      await loadAll();
    } catch (err) {
      setError((err as Error).message);
    } finally {
      setFilterBusy(false);
    }
  }

  async function deleteFilter(filter: StudioFilter) {
    if (!window.confirm(`Xóa bộ lọc "${filter.name}"?`)) return;
    setFilterBusy(true);
    setError("");
    setNotice("");
    try {
      await apiJson(`/v1/web/filters/${filter.id}`, { method: "DELETE" });
      setNotice("Đã xóa bộ lọc.");
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setFilterBusy(false);
    }
  }

  async function mutate(form: HTMLFormElement, path: string, body: Record<string, unknown>, success: string) {
    setSubmitting(true);
    setNotice("");
    setError("");
    try {
      await apiJson(path, { method: "POST", body: JSON.stringify(body) });
      form.reset();
      setNotice(success);
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setSubmitting(false);
    }
  }

  async function revokeCode(id: string) {
    setSubmitting(true);
    setNotice("");
    setError("");
    try {
      await apiJson(`/v1/web/codes/${id}/revoke`, { method: "POST" });
      setNotice("Đã thu hồi mã.");
      await loadAll();
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setSubmitting(false);
    }
  }

  /** Sends the waiting delete now (a new delete, logout or the undo window ran out). */
  const commitDelete = useCallback(async () => {
    const pending = pendingRef.current;
    if (!pending) return;
    window.clearTimeout(pending.timer);
    pendingRef.current = null;
    const { job } = pending;
    const gone = new Set(job.ids);
    if (job.kind === "room") {
      setRooms((current) => current.filter((room) => !gone.has(room.id)));
      setPackages((current) => current.filter((pkg) => !gone.has(pkg.room_id)));
    } else if (job.kind === "package") {
      setPackages((current) => current.filter((pkg) => !gone.has(pkg.id)));
    } else {
      setCodes((current) => current.filter((code) => !gone.has(code.id)));
      setSelectedCodes((current) => current.filter((id) => !gone.has(id)));
    }
    setPendingDelete((current) => (current === job ? null : current));
    try {
      await deleteRequest(job);
    } catch (err) {
      setError(`Chưa xóa được: ${(err as ApiError).message}`);
      void loadAll();
    }
  }, [loadAll]);

  function scheduleDelete(job: PendingDelete) {
    void commitDelete();
    setNotice("");
    setError("");
    const timer = window.setTimeout(() => void commitDelete(), UNDO_MS);
    pendingRef.current = { job, timer };
    setPendingDelete(job);
  }

  function undoDelete() {
    if (pendingRef.current) window.clearTimeout(pendingRef.current.timer);
    pendingRef.current = null;
    setPendingDelete(null);
  }

  // Closing the tab inside the undo window still deletes.
  useEffect(() => {
    const flush = () => {
      if (pendingRef.current) void deleteRequest(pendingRef.current.job, true).catch(() => undefined);
      pendingRef.current = null;
    };
    window.addEventListener("pagehide", flush);
    return () => window.removeEventListener("pagehide", flush);
  }, []);

  function startEditRoom(room: Room) {
    setEditingRoom(room.id);
    setRoomDraft({ name: room.name, capacity: room.capacity || "", description: room.description || "" });
    setError("");
  }

  function replaceRoom(room: Room) {
    setRooms((current) => current.map((item) => (item.id === room.id ? { ...item, ...room } : item)));
  }

  async function saveRoom(event: FormEvent<HTMLFormElement>, room: Room) {
    event.preventDefault();
    if (!roomDraft.name.trim()) {
      setError("Nhập tên phòng chụp.");
      return;
    }
    setRoomBusy(room.id);
    setError("");
    try {
      const data = await apiJson<{ room: Room }>(`/v1/web/rooms/${room.id}`, { method: "PATCH", body: JSON.stringify(roomDraft) });
      replaceRoom(data.room);
      setEditingRoom("");
      setNotice(`Đã lưu: ${data.room.name}.`);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setRoomBusy("");
    }
  }

  /** Chọn ảnh mới → mở hộp căn khung (chưa tải lên cho tới khi bấm "Lưu ảnh bìa"). */
  function pickRoomCover(event: ChangeEvent<HTMLInputElement>, room: Room) {
    const input = event.currentTarget;
    const file = input.files?.[0];
    input.value = "";
    if (!file) return;
    if (!["image/jpeg", "image/png", "image/webp"].includes(file.type)) {
      setError("Ảnh phòng phải là JPG, PNG hoặc WebP.");
      return;
    }
    if (file.size > 15 * 1024 * 1024) {
      setError("Ảnh phòng tối đa 15MB.");
      return;
    }
    setError("");
    setCoverEdit({ room, src: URL.createObjectURL(file), file, crop: null });
  }

  /** Căn lại khung trên ảnh gốc đã lưu, không phải chọn lại ảnh. */
  function reframeRoomCover(room: Room) {
    if (!room.cover_original_url) return;
    setError("");
    setCoverEdit({ room, src: room.cover_original_url, file: null, crop: room.cover_crop ?? null });
  }

  function closeCoverEditor() {
    setCoverEdit((current) => {
      if (current?.file) URL.revokeObjectURL(current.src);
      return null;
    });
  }

  async function saveRoomCover(crop: CoverCrop, display: Blob) {
    if (!coverEdit) return;
    const { room, file } = coverEdit;
    setRoomBusy(room.id);
    setError("");
    try {
      // Ảnh gốc giữ nguyên (chỉ gửi khi là ảnh mới); khách tải bản 3:2 đã căn khung.
      const form = new FormData();
      if (file) form.append("file", file);
      form.append("display", display, display.type === "image/webp" ? "display.webp" : "display.jpg");
      form.append("crop", JSON.stringify(crop));
      const data = await apiJson<{ room: Room }>(`/v1/web/rooms/${room.id}/cover`, { method: "PUT", body: form });
      replaceRoom(data.room);
      closeCoverEditor();
      setNotice(`Đã lưu ảnh bìa: ${room.name}.`);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setRoomBusy("");
    }
  }

  async function removeRoomCover(room: Room) {
    setRoomBusy(room.id);
    setError("");
    try {
      const data = await apiJson<{ room: Room }>(`/v1/web/rooms/${room.id}/cover`, { method: "DELETE" });
      replaceRoom(data.room);
      setNotice(`Đã gỡ ảnh bìa: ${room.name}.`);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setRoomBusy("");
    }
  }

  function deleteRoom(room: Room) {
    const count = packages.filter((pkg) => pkg.room_id === room.id).length;
    scheduleDelete({ kind: "room", ids: [room.id], label: `Đã xóa phòng ${room.name}${count ? ` và ${count} gói` : ""}` });
  }

  function deletePackage(pkg: PhotoPackage) {
    scheduleDelete({ kind: "package", ids: [pkg.id], label: `Đã xóa gói ${pkg.name}` });
  }

  function deleteCodes(ids: string[]) {
    if (ids.length === 0) return;
    const label = ids.length === 1
      ? `Đã xóa mã ${codes.find((code) => code.id === ids[0])?.code ?? ""}`
      : `Đã xóa ${ids.length} mã`;
    scheduleDelete({ kind: "code", ids, label });
  }

  function toggleCode(id: string) {
    setSelectedCodes((current) => current.includes(id) ? current.filter((item) => item !== id) : [...current, id]);
  }

  /** Guest album link of a session; sessions the booth never linked get a token on first ask. */
  async function galleryLink(session: CaptureSession) {
    if (session.gallery_token) return `${window.location.origin}/gallery?t=${encodeURIComponent(session.gallery_token)}`;
    const data = await apiJson<{ token: string; url: string }>(
      `/v1/web/capture-sessions/${encodeURIComponent(session.machine_id)}/${encodeURIComponent(session.session_id)}/gallery-link`,
      { method: "POST" },
    );
    setCaptureSessions((current) => current.map((item) => sessionKey(item) === sessionKey(session) ? { ...item, gallery_token: data.token } : item));
    return data.url;
  }

  async function copySessionLink(session: CaptureSession) {
    setError("");
    try {
      await copyPending(galleryLink(session));
      setCopied(sessionKey(session));
      window.setTimeout(() => setCopied((current) => current === sessionKey(session) ? "" : current), 1800);
    } catch (err) {
      setError(`Không copy được link: ${(err as Error).message}`);
    }
  }

  async function openSessionQr(session: CaptureSession) {
    setError("");
    setSessionQr({ session, url: "" });
    try {
      const url = await galleryLink(session);
      setSessionQr((current) => current && sessionKey(current.session) === sessionKey(session) ? { session, url } : current);
    } catch (err) {
      setSessionQr(null);
      setError(`Không tạo được QR: ${(err as Error).message}`);
    }
  }

  useEffect(() => {
    if (!sessionQr) return;
    const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") setSessionQr(null); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [sessionQr]);

  async function loadLibrary(next = false) {
    setLoading(true);
    setError("");
    try {
      const params = new URLSearchParams({ limit: String(libraryLimit) });
      if (libraryMachine) params.set("machine_id", libraryMachine);
      if (libraryFrom) params.set("from", libraryFrom);
      if (libraryTo) params.set("to", libraryTo);
      if (Number(libraryNo) > 0) params.set("no", String(Number(libraryNo)));
      if (next && libraryCursor) params.set("cursor", libraryCursor);
      const data = await apiJson<{ success: boolean; sessions: CaptureSession[]; next_cursor: string | null }>(`/v1/web/capture-sessions?${params}`);
      setCaptureSessions((current) => next ? [...current, ...data.sessions] : data.sessions);
      setLibraryCursor(data.next_cursor);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setLoading(false);
    }
  }

  if (booting) {
    return (
      <main className="boot-shell" aria-label="Đang tải admin">
        <div className="brand-mark">BOOTHME</div>
        <div className="loading-line" />
      </main>
    );
  }

  if (!auth) {
    const staffPortal = portal === "staff";
    return (
      <main className={staffPortal ? "login-shell is-staff" : "login-shell"}>
        <section className="login-panel" aria-labelledby="login-title">
          <div className="login-brand">
            {staffPortal && portalStudio ? (
              <BrandMark branding={portalStudio.branding} fallbackName={portalStudio.name} />
            ) : null}
            {staffPortal ? null : <span className="eyebrow">SelfBooth Admin</span>}
            <h1 id="login-title">{staffPortal ? "Cổng nhân viên" : "BOOTHME"}</h1>
            <p>{staffPortal ? "Đăng nhập bằng tài khoản quản lý studio cấp cho bạn." : "Đăng nhập bằng tài khoản studio đã tạo trên app desktop."}</p>
          </div>

          {staffPortal && portalMissing ? (
            <div className="login-missing" role="alert">
              <KeyRound size={20} />
              <p>Mở link cổng nhân viên do quản lý studio gửi để đăng nhập.</p>
            </div>
          ) : (
            <form className="login-form" onSubmit={onLogin}>
              <label>
                {staffPortal ? "Tên đăng nhập" : "Email studio"}
                {staffPortal ? (
                  <input autoCapitalize="none" autoComplete="username" autoCorrect="off" maxLength={32} onChange={(event) => setEmail(event.target.value.toLowerCase())} placeholder="vd: thungan01" required spellCheck={false} value={email} />
                ) : (
                  <input autoCapitalize="none" autoComplete="email" autoCorrect="off" inputMode="email" onChange={(event) => setEmail(event.target.value)} placeholder="studio@example.com" required type="email" value={email} />
                )}
              </label>
              <label>
                Mật khẩu
                <span className="password-field">
                  <input autoComplete="current-password" minLength={8} onChange={(event) => setPassword(event.target.value)} placeholder="Tối thiểu 8 ký tự" required type={showPassword ? "text" : "password"} value={password} />
                  <button
                    aria-label={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                    aria-pressed={showPassword}
                    onClick={() => setShowPassword((current) => !current)}
                    title={showPassword ? "Ẩn mật khẩu" : "Hiện mật khẩu"}
                    type="button"
                  >
                    {showPassword ? <EyeOff size={18} /> : <Eye size={18} />}
                  </button>
                </span>
              </label>
              {turnstileSiteKey ? (
                <Turnstile
                  action={staffPortal ? "staff_login" : "owner_login"}
                  onToken={setTurnstileToken}
                  resetSignal={turnstileReset}
                  siteKey={turnstileSiteKey}
                />
              ) : null}
              <div className="form-message" role="status" aria-live="polite">{error}</div>
              <button
                className="primary-action"
                disabled={submitting || (staffPortal && !portalStudio) || turnstileSiteKey === null || (needsHumanCheck && !turnstileToken)}
                type="submit"
              >
                {submitting ? "Đang kiểm tra" : needsHumanCheck && !turnstileToken ? "Đang xác minh…" : "Đăng nhập"}
              </button>
            </form>
          )}
          <a className="login-switch" href={staffPortal ? "/" : "/staff"}>
            {staffPortal ? "Chủ studio đăng nhập tại đây" : "Nhân viên đăng nhập tại cổng nhân viên"}
          </a>
        </section>
      </main>
    );
  }

  const activeTitle = navItems.find((item) => item.id === section)?.label ?? "";
  const hidden = new Set(pendingDelete?.ids ?? []);
  const visibleRooms = rooms.filter((room) => !hidden.has(room.id));
  const visiblePackages = packages.filter((pkg) => !hidden.has(pkg.id) && !hidden.has(pkg.room_id));
  const liveCodes = codes.filter((code) => !hidden.has(code.id));
  const shownCodes = codeFilter === "all" ? liveCodes : liveCodes.filter((code) => code.status === codeFilter);
  const shownSelected = selectedCodes.filter((id) => shownCodes.some((code) => code.id === id));
  const allShownSelected = shownCodes.length > 0 && shownSelected.length === shownCodes.length;
  const shownGroups = navGroups
    .map((group) => ({ ...group, items: group.items.filter((item) => canOpen(item.id, auth.user, can)) }))
    .filter((group) => group.items.length > 0);

  return (
    <main className="admin-shell">
      <aside className="rail" aria-label="Điều hướng admin">
        <div className="rail-brand"><BrandMark branding={branding} fallbackName={auth.studio.name || "BOOTHME"} /></div>
        <nav className="rail-nav">
          {shownGroups.map((group) => (
            <div className="rail-group" key={group.label} role="group" aria-label={group.label}>
              <span className="rail-group-label">{group.label}</span>
              {group.items.map((item) => {
                const Icon = item.icon;
                return (
                  <button
                    aria-current={section === item.id ? "page" : undefined}
                    className={`rail-item ${section === item.id ? "active" : ""}`}
                    key={item.id}
                    onClick={() => { setSection(item.id); window.scrollTo({ top: 0 }); }}
                    type="button"
                  >
                    <Icon size={18} />
                    <span className="rail-label">{item.label}</span>
                    <span className="rail-label-short">{item.short}</span>
                  </button>
                );
              })}
            </div>
          ))}
        </nav>
      </aside>

      <section className="workspace" aria-labelledby="admin-title">
        <header className="topbar">
          <div>
            <span className="topbar-studio">{auth.studio.name}</span>
            <h1 id="admin-title">{activeTitle}</h1>
          </div>
          <button aria-label="Làm mới dữ liệu" className="topbar-refresh" disabled={loading} onClick={() => void loadAll()} title="Làm mới" type="button">
            <RefreshCw className={loading ? "spin" : undefined} size={18} />
          </button>
          <div className="account-pill">
            {auth.user.role === "owner" ? <ShieldCheck size={18} /> : <UserRound size={18} />}
            <div>
              <strong>{displayName(auth.user)}</strong>
              <span>{roleLabel(auth.user)}{auth.user.role === "owner" ? "" : ` · @${auth.user.username}`}</span>
            </div>
            <button aria-label="Đổi mật khẩu" onClick={() => setPasswordOpen(true)} title="Đổi mật khẩu" type="button">
              <KeyRound size={18} />
            </button>
            <button aria-label="Đăng xuất" onClick={onLogout} title="Đăng xuất" type="button">
              <LogOut size={18} />
            </button>
          </div>
        </header>

        <div className="inline-message" role="status" aria-live="polite">{error || notice}</div>

        {section === "devices" ? (
          <Panel title="Máy đã liên kết" meta={loading ? "Đang tải" : `${machines.length} thiết bị`}>
            {machines.length === 0 ? <Empty icon={<WifiOff size={28} />} title="Chưa có thiết bị" text="Đăng nhập studio trên app desktop để gắn máy với tài khoản này." /> : null}
            <div className="device-grid">
              {machines.map((machine) => (
                <DeviceCard
                  canRename={can("devices.rename")}
                  key={machine.id}
                  machine={machine}
                  onRenamed={(next) => setMachines((current) => current.map((item) => (item.id === next.id ? { ...item, ...next } : item)))}
                />
              ))}
            </div>
          </Panel>
        ) : null}

        {section === "bookings" ? (
          <Panel title="Đặt lịch" meta="Lịch hẹn của khách">
            <BookingsPanel brandName={branding?.name || auth.studio.name} can={can} packages={packages} rooms={rooms} />
          </Panel>
        ) : null}

        {section === "brand" ? (
          <Panel title="Thương hiệu" meta="Logo, tên và màu giao diện">
            <BrandingPanel
              branding={branding}
              onSaved={(next) => { setBranding(next); applyBranding(next); }}
              studioName={auth.studio.name}
            />
          </Panel>
        ) : null}

        {section === "staff" && auth.user.role === "owner" ? (
          <Panel title="Nhân viên" meta="Tài khoản và quyền">
            <StaffPanel studioId={auth.studio.id} studioName={branding?.name || auth.studio.name} />
          </Panel>
        ) : null}

        {section === "rooms" ? (
          <Panel title="Phòng chụp" meta={`${visibleRooms.length} phòng`}>
            {can("rooms.create") ? (
              <form className="admin-form" onSubmit={createRoom}>
                <input name="name" placeholder="Tên phòng chụp" required />
                <input name="capacity" placeholder="Sức chứa / ghi chú ngắn" />
                <input name="description" placeholder="Mô tả hiển thị trên trang đặt lịch" />
                <button className="primary-action" disabled={submitting} type="submit"><Plus size={17} />Tạo phòng</button>
              </form>
            ) : null}
            {visibleRooms.length === 0 ? <Empty icon={<Building2 size={28} />} title="Chưa có phòng" text="Tạo phòng chụp trước, rồi thêm gói chụp cho từng phòng." /> : (
              <p className="room-grid-head">
                <a className="text-action" href={`/booking?studio_id=${encodeURIComponent(auth.studio.id)}`} rel="noreferrer" target="_blank">
                  <ExternalLink size={15} />Xem trang đặt lịch
                </a>
              </p>
            )}
            <div className="room-grid">
              {visibleRooms.map((room) => {
                const roomPackages = visiblePackages.filter((pkg) => pkg.room_id === room.id);
                const fromPrice = roomPackages.length ? Math.min(...roomPackages.map((pkg) => pkg.price_vnd)) : null;
                const busy = roomBusy === room.id;
                const editing = editingRoom === room.id;
                return (
                  <article className={busy ? "room-card is-busy" : "room-card"} key={room.id} aria-busy={busy}>
                    <figure className="room-cover">
                      {room.cover_url ? <img alt={`Ảnh bìa phòng ${room.name}`} decoding="async" loading="lazy" src={room.cover_url} /> : (
                        <span className="room-cover-empty"><ImagePlus size={24} /><small>Chưa có ảnh bìa</small></span>
                      )}
                      {busy ? <span className="room-cover-busy" role="status"><Loader2 className="spin" size={22} /><small>Đang lưu</small></span> : null}
                    </figure>
                    {editing ? (
                      <form className="room-edit" onSubmit={(event) => saveRoom(event, room)}>
                        <label>
                          <span>Tên phòng</span>
                          <input autoFocus maxLength={100} onChange={(e) => setRoomDraft((d) => ({ ...d, name: e.target.value }))} required value={roomDraft.name} />
                        </label>
                        <label>
                          <span>Sức chứa</span>
                          <input maxLength={80} onChange={(e) => setRoomDraft((d) => ({ ...d, capacity: e.target.value }))} placeholder="2–6 người" value={roomDraft.capacity} />
                        </label>
                        <label>
                          <span>Mô tả trên trang đặt lịch</span>
                          <textarea maxLength={1000} onChange={(e) => setRoomDraft((d) => ({ ...d, description: e.target.value }))} rows={4} value={roomDraft.description} />
                          <small className="room-edit-count">{roomDraft.description.length}/1000</small>
                        </label>
                        <div className="room-edit-actions">
                          <button className="primary-action" disabled={busy} type="submit">{busy ? <Loader2 className="spin" size={16} /> : null}Lưu</button>
                          <button className="text-action" disabled={busy} onClick={() => setEditingRoom("")} type="button">Hủy</button>
                        </div>
                      </form>
                    ) : (
                      <div className="room-body">
                        <h3>{room.name}</h3>
                        <small className="room-capacity">{room.capacity || "Chưa khai báo sức chứa"}</small>
                        <p className="room-description">{room.description || "Chưa có mô tả"}</p>
                        <p className="room-price">
                          {fromPrice !== null ? <><strong>Từ {formatMoney(fromPrice)}</strong> · {roomPackages.length} gói</> : "Chưa có gói"}
                        </p>
                      </div>
                    )}
                    {!editing && (can("rooms.edit") || can("rooms.delete")) ? (
                      <footer className="room-actions">
                        {can("rooms.edit") ? (
                          <>
                            <button className="ghost-action" disabled={busy} onClick={() => startEditRoom(room)} type="button"><Pencil size={16} />Sửa</button>
                            <label className={busy ? "ghost-action is-disabled" : "ghost-action"}>
                              <Upload size={16} />{room.cover_url ? "Đổi ảnh" : "Thêm ảnh"}
                              <input accept="image/jpeg,image/png,image/webp" aria-label={`Ảnh bìa phòng ${room.name}`} disabled={busy} onChange={(event) => pickRoomCover(event, room)} type="file" />
                            </label>
                            {room.cover_original_url ? (
                              <button className="ghost-action" disabled={busy} onClick={() => reframeRoomCover(room)} type="button"><Crop size={16} />Căn khung</button>
                            ) : null}
                            {room.cover_url ? (
                              <button className="text-action" disabled={busy} onClick={() => removeRoomCover(room)} type="button">Gỡ ảnh</button>
                            ) : null}
                          </>
                        ) : null}
                        {can("rooms.delete") ? (
                          <button aria-label={`Xóa phòng ${room.name}`} className="danger-action" disabled={busy} onClick={() => deleteRoom(room)} type="button">
                            <Trash2 size={16} />Xóa
                          </button>
                        ) : null}
                      </footer>
                    ) : null}
                  </article>
                );
              })}
            </div>
          </Panel>
        ) : null}

        {section === "packages" ? (
          <Panel title="Gói chụp" meta={`${visiblePackages.length} gói`}>
            {can("packages.create") ? <form className="admin-form packages-form" onSubmit={createPackage}>
              <select name="room_id" required defaultValue="">
                <option value="" disabled>Chọn phòng</option>
                {visibleRooms.map((room) => <option key={room.id} value={room.id}>{room.name}</option>)}
              </select>
              <input name="name" placeholder="Tên gói" required />
              <input inputMode="numeric" min={1} name="minutes" placeholder="Số phút" required type="number" />
              <input inputMode="numeric" min={0} name="price_vnd" placeholder="Giá VND" required type="number" />
              <input name="description" placeholder="Mô tả gói" />
              <button className="primary-action" disabled={submitting || visibleRooms.length === 0} type="submit"><Plus size={17} />Tạo gói</button>
            </form> : null}
            {visiblePackages.length === 0 ? <Empty icon={<Package size={28} />} title="Chưa có gói" text={visibleRooms.length ? "Thêm gói đầu tiên để khách đặt lịch và để tạo mã chụp." : "Tạo phòng chụp trước, gói chụp gắn với một phòng."} /> : null}
            <div className="studio-grid">
              {visiblePackages.map((pkg) => (
                <article className="studio-card" key={pkg.id}>
                  <span className="eyebrow">{pkg.room_name || "Phòng chụp"}</span>
                  <h3>{pkg.name}</h3>
                  <p>{pkg.description || `${pkg.minutes} phút`}</p>
                  <footer className="card-foot">
                    <strong>{formatMoney(pkg.price_vnd)}</strong>
                    {can("packages.delete") ? (
                      <button aria-label={`Xóa gói ${pkg.name}`} className="danger-action" onClick={() => deletePackage(pkg)} type="button">
                        <Trash2 size={16} />Xóa
                      </button>
                    ) : null}
                  </footer>
                </article>
              ))}
            </div>
          </Panel>
        ) : null}

        {section === "codes" ? (
          <Panel title="Mã chụp 4 số" meta={`${liveCodes.length} mã`}>
            {can("codes.create") ? <form className="admin-form codes-form" onSubmit={createCode}>
              <select name="package_id" required defaultValue="">
                <option value="" disabled>Chọn gói chụp</option>
                {visiblePackages.map((pkg) => (
                  <option key={pkg.id} value={pkg.id}>{pkg.room_name ? `${pkg.room_name} · ` : ""}{pkg.name} · {formatMoney(pkg.price_vnd)}</option>
                ))}
              </select>
              <select name="kind" defaultValue="single">
                <option value="single">Dùng 1 lần</option>
                <option value="reusable">Dùng nhiều lần</option>
              </select>
              <input inputMode="numeric" maxLength={4} name="code" pattern="[0-9]{4}" placeholder="Mã 4 số hoặc bỏ trống" />
              <input inputMode="numeric" min={1} max={100} name="count" placeholder="Số mã random" type="number" />
              <input name="note" placeholder="Ghi chú nội bộ" />
              <button className="primary-action" disabled={submitting || visiblePackages.length === 0} type="submit"><KeyRound size={17} />{submitting ? "Đang tạo" : "Tạo mã"}</button>
            </form> : null}

            <div className="code-toolbar">
              <div className="code-filter" role="radiogroup" aria-label="Lọc mã theo trạng thái">
                {codeFilters.map((filter) => {
                  const count = filter.id === "all" ? liveCodes.length : liveCodes.filter((code) => code.status === filter.id).length;
                  return (
                    <button
                      aria-checked={codeFilter === filter.id}
                      className={codeFilter === filter.id ? "active" : ""}
                      key={filter.id}
                      onClick={() => setCodeFilter(filter.id)}
                      role="radio"
                      type="button"
                    >
                      {filter.label}<small>{count}</small>
                    </button>
                  );
                })}
              </div>
              {can("codes.delete") ? <div className="frame-bulkbar code-bulkbar">
                <button
                  className="ghost-action"
                  disabled={shownCodes.length === 0}
                  onClick={() => setSelectedCodes(allShownSelected
                    ? selectedCodes.filter((id) => !shownCodes.some((code) => code.id === id))
                    : [...new Set([...selectedCodes, ...shownCodes.map((code) => code.id)])])}
                  type="button"
                >
                  {allShownSelected ? <CheckSquare size={18} /> : <Square size={18} />}
                  Chọn tất cả
                </button>
                <span>{shownSelected.length} mã đã chọn</span>
                <button className="danger-action" disabled={shownSelected.length === 0} onClick={() => deleteCodes(shownSelected)} type="button">
                  <Trash2 size={17} />Xóa đã chọn
                </button>
              </div> : null}
            </div>

            {shownCodes.length === 0 ? (
              <Empty
                icon={<Ticket size={28} />}
                title={liveCodes.length ? "Không có mã ở mục này" : "Chưa có mã chụp"}
                text={liveCodes.length ? "Chọn mục khác để xem các mã còn lại." : "Chọn gói chụp rồi bấm Tạo mã. Bỏ trống ô mã để hệ thống tạo số ngẫu nhiên."}
              />
            ) : null}

            <div className="code-list">
              {shownCodes.map((code) => {
                const state = codeStatus(code);
                const checked = selectedCodes.includes(code.id);
                return (
                  <article className={`code-card ${checked ? "selected" : ""}`} key={code.id}>
                    <div>
                      {can("codes.delete") ? (
                        <button aria-label={checked ? `Bỏ chọn mã ${code.code}` : `Chọn mã ${code.code}`} aria-pressed={checked} className="code-select" onClick={() => toggleCode(code.id)} type="button">
                          {checked ? <CheckSquare size={18} /> : <Square size={18} />}
                        </button>
                      ) : null}
                      <strong>{code.code}</strong>
                      <span className={`status-pill ${state.tone}`}>{state.label}</span>
                    </div>
                    <p>{code.room_name || "Phòng"} · {code.package_name || "Gói"} · {formatMoney(code.price_vnd)}</p>
                    <div className="code-actions">
                      <button onClick={() => copyText(code.code)} type="button">{copied === code.code ? <CheckCircle2 size={17} /> : <Copy size={17} />}Copy</button>
                      {code.status === "active" && can("codes.revoke") ? <button disabled={submitting} onClick={() => revokeCode(code.id)} type="button">Thu hồi</button> : null}
                      {can("codes.delete") ? (
                        <button aria-label={`Xóa mã ${code.code}`} className="danger-action code-delete" onClick={() => deleteCodes([code.id])} title="Xóa mã" type="button">
                          <Trash2 size={16} />
                        </button>
                      ) : null}
                    </div>
                  </article>
                );
              })}
            </div>
          </Panel>
        ) : null}

        {section === "frames" ? (
          <Panel title="Thư viện frame" meta={`${frames.length} frame`}>
            {can("frames.upload") ? <form className="admin-form frame-upload-form" onSubmit={uploadFrame}>
              <input name="name" placeholder="Tên frame" />
              <input accept="image/png" aria-label="Chọn file PNG frame" name="file" required type="file" />
              <button className="primary-action" disabled={frameBusy} type="submit">
                <Upload size={17} />Tải frame
              </button>
            </form> : null}

            {can("frames.delete") ? <div className="frame-bulkbar">
              <button
                className="ghost-action"
                disabled={frames.length === 0 || frameBusy}
                onClick={() => setSelectedFrames(selectedFrames.length === frames.length ? [] : frames.map((frame) => frame.id))}
                type="button"
              >
                {selectedFrames.length === frames.length && frames.length > 0 ? <CheckSquare size={18} /> : <Square size={18} />}
                Chọn tất cả
              </button>
              <span>{selectedFrames.length} frame đã chọn</span>
              <button className="danger-action" disabled={selectedFrames.length === 0 || frameBusy} onClick={() => deleteFrames(selectedFrames)} type="button">
                <Trash2 size={17} />Xóa đã chọn
              </button>
            </div> : null}

            {frames.length === 0 ? <Empty icon={<ImagePlus size={28} />} title="Chưa có frame" text="Tải PNG có vùng trong suốt ở giữa, hệ thống sẽ tự nhận các slot ghép ảnh." /> : null}

            <div className="frame-grid">
              {frames.map((frame) => {
                const checked = selectedFrames.includes(frame.id);
                return (
                  <article className={`frame-card ${checked ? "selected" : ""}`} key={frame.id}>
                    <div className="frame-card-head">
                      {can("frames.delete") ? (
                        <button aria-label={checked ? "Bỏ chọn frame" : "Chọn frame"} className="frame-select" onClick={() => toggleFrame(frame.id)} type="button">
                          {checked ? <CheckSquare size={18} /> : <Square size={18} />}
                        </button>
                      ) : null}
                      <span>
                        {frame.slot_count} ô
                        {groupCount(frame.slots) ? ` · ${groupCount(frame.slots)} nhóm` : " · chưa chia nhóm"}
                      </span>
                    </div>
                    {/* Sized to the frame so the slot boxes line up with the holes. */}
                    <div className="frame-preview" style={{ aspectRatio: frame.width && frame.height ? `${frame.width} / ${frame.height}` : undefined }}>
                      <div className="frame-preview-fit">
                        <img alt={frame.name} decoding="async" loading="lazy" src={frame.thumbnail_url || frame.preview_url || frame.image_url} />
                        {frame.slots.map((slot, index) => (
                          <span
                            aria-hidden="true"
                            className="frame-slot"
                            key={`${frame.id}:${index}`}
                            style={{
                              left: `${slot.x * 100}%`,
                              top: `${slot.y * 100}%`,
                              width: `${slot.width * 100}%`,
                              height: `${slot.height * 100}%`,
                              ...(Number.isInteger(slot.group) ? { "--group-color": groupColor(slot.group!) } : {}),
                            } as CSSProperties}
                          />
                        ))}
                      </div>
                    </div>
                    {can("frames.edit") ? (
                      <label className="frame-edit">
                        Tên frame
                        <input onChange={(event) => setFrameNames((current) => ({ ...current, [frame.id]: event.target.value }))} value={frameNames[frame.id] ?? frame.name} />
                      </label>
                    ) : <strong className="frame-name">{frame.name}</strong>}
                    <div className="frame-meta">
                      <span>{frame.width} x {frame.height}px</span>
                      <span>{Math.round(frame.size_bytes / 1024)} KB</span>
                    </div>
                    {can("frames.edit") || can("frames.delete") ? (
                      <div className="frame-actions">
                        {can("frames.edit") ? (
                          <>
                            <button className="ghost-action" disabled={frameBusy} onClick={() => saveFrame(frame)} type="button">
                              Lưu
                            </button>
                            <button className="ghost-action" disabled={frameBusy} onClick={() => openGroups(frame)} type="button">
                              <Layers3 size={17} />Nhóm ô
                            </button>
                          </>
                        ) : null}
                        {can("frames.delete") ? (
                          <button className="danger-action" disabled={frameBusy} onClick={() => deleteFrames([frame.id])} type="button">
                            <Trash2 size={17} />Xóa
                          </button>
                        ) : null}
                      </div>
                    ) : null}
                  </article>
                );
              })}
            </div>

            {groupEdit ? (() => {
              const ids = [...new Set([...groupEdit.slots.map((slot) => slot.group), groupEdit.active])].sort((a, b) => a - b);
              const ratio = groupEdit.width && groupEdit.height ? groupEdit.width / groupEdit.height : 4 / 5;
              return (
                <div className="gallery-modal group-modal" role="dialog" aria-modal="true" aria-label={`Nhóm ô · ${groupEdit.frame.name}`}>
                  <div className="group-modal-panel">
                    <header className="group-modal-head">
                      <div>
                        <span className="eyebrow">Nhóm ô</span>
                        <h2>{frameNames[groupEdit.frame.id] || groupEdit.frame.name}</h2>
                      </div>
                      <button aria-label="Đóng" className="gallery-icon-button" disabled={frameBusy} onClick={() => setGroupEdit(null)} type="button"><X size={18} /></button>
                    </header>

                    <div className="group-modal-body">
                      <div className="group-canvas" style={{ "--frame-ratio": ratio } as CSSProperties}>
                        <img alt={groupEdit.frame.name} decoding="async" src={groupEdit.frame.preview_url || groupEdit.frame.image_url} />
                        {groupEdit.slots.map((slot, index) => (
                          <button
                            aria-label={`Ô ${index + 1}, nhóm ${slot.group + 1}`}
                            className={slot.group === groupEdit.active ? "group-slot in-active" : "group-slot"}
                            key={index}
                            onClick={() => moveSlotToGroup(index)}
                            style={{
                              left: `${slot.x * 100}%`,
                              top: `${slot.y * 100}%`,
                              width: `${slot.width * 100}%`,
                              height: `${slot.height * 100}%`,
                              "--group-color": groupColor(slot.group),
                            } as CSSProperties}
                            type="button"
                          >
                            <b>{slot.group + 1}</b>
                          </button>
                        ))}
                      </div>

                      <aside className="group-side">
                        <p>Chọn nhóm, rồi chạm vào ô trên frame để đưa ô vào nhóm đó.</p>
                        <div className="group-list">
                          {ids.map((id) => {
                            const count = groupEdit.slots.filter((slot) => slot.group === id).length;
                            return (
                              <button
                                aria-pressed={id === groupEdit.active}
                                className={id === groupEdit.active ? "group-pill active" : "group-pill"}
                                key={id}
                                onClick={() => setGroupEdit({ ...groupEdit, active: id })}
                                style={{ "--group-color": groupColor(id) } as CSSProperties}
                                type="button"
                              >
                                <i aria-hidden="true" />
                                Nhóm {id + 1}
                                <small>{count} ô</small>
                              </button>
                            );
                          })}
                          <button className="group-pill add" onClick={newGroup} type="button"><Plus size={16} />Nhóm mới</button>
                        </div>
                        <div className="group-actions">
                          <button className="ghost-action" disabled={frameBusy} onClick={redetectGroups} type="button">
                            <RefreshCw size={17} />Nhận lại từ ảnh
                          </button>
                          <button className="primary-action" disabled={frameBusy} onClick={saveGroups} type="button">
                            <CheckCircle2 size={17} />Lưu {groupCount(compactGroups(groupEdit.slots))} nhóm
                          </button>
                        </div>
                      </aside>
                    </div>
                  </div>
                </div>
              );
            })() : null}
          </Panel>
        ) : null}

        {section === "filters" ? (
          <Panel title="Bộ lọc màu" meta={`${filters.length} bộ lọc`}>
            {can("filters.upload") ? <><form className="admin-form filter-upload-form" onSubmit={uploadFilter}>
              <input maxLength={80} name="name" placeholder="Tên bộ lọc" />
              <label className="file-field">
                <span>File LUT (.cube)</span>
                <input accept=".cube" name="file" required type="file" />
              </label>
              <label className="file-field">
                <span>Ảnh thumbnail (không bắt buộc)</span>
                <input accept="image/jpeg,image/png,image/webp" name="thumbnail" type="file" />
              </label>
              <button className="primary-action" disabled={filterBusy} type="submit">
                <Upload size={17} />{filterBusy ? "Đang xử lý" : "Tải bộ lọc"}
              </button>
            </form>

            <label className="filter-tint-toggle">
              <input checked={tintThumbnails} onChange={(event) => setTintThumbnails(event.target.checked)} type="checkbox" />
              <span>Áp màu bộ lọc lên ảnh thumbnail. Bỏ chọn nếu ảnh đã có màu sẵn. Không chọn ảnh thì hệ thống tự tạo dải màu mẫu.</span>
            </label></> : null}

            {filters.length === 0 ? <Empty icon={<Palette size={28} />} title="Chưa có bộ lọc" text="Tải file LUT .cube (3D) để khách chọn bộ lọc màu khi chỉnh sửa ảnh." /> : null}

            <div className="filter-grid">
              {filters.map((filter) => (
                <article className="filter-card" key={filter.id}>
                  <div className="filter-thumb">
                    {filter.thumbnail_url ? <img alt={filter.name} loading="lazy" src={filter.thumbnail_url} /> : <Palette size={28} />}
                  </div>
                  {can("filters.edit") ? (
                    <label className="frame-edit">
                      Tên bộ lọc
                      <input maxLength={80} onChange={(event) => setFilterNames((current) => ({ ...current, [filter.id]: event.target.value }))} value={filterNames[filter.id] ?? filter.name} />
                    </label>
                  ) : <strong className="frame-name">{filter.name}</strong>}
                  <div className="frame-meta">
                    <span>LUT {filter.lut_size}³</span>
                    <span>{Math.max(1, Math.round(filter.cube_size_bytes / 1024))} KB</span>
                  </div>
                  {can("filters.edit") || can("filters.delete") ? (
                    <div className="frame-actions">
                      {can("filters.edit") ? (
                        <>
                          <button className="ghost-action" disabled={filterBusy || (filterNames[filter.id] ?? filter.name) === filter.name} onClick={() => saveFilterName(filter)} type="button">Lưu tên</button>
                          <label className={`gallery-upload-button filter-thumb-button${filterBusy ? " is-disabled" : ""}`}>
                            <ImagePlus size={16} />Thumbnail
                            <input accept="image/jpeg,image/png,image/webp" disabled={filterBusy} onChange={(event) => changeFilterThumbnail(filter, event)} type="file" />
                          </label>
                        </>
                      ) : null}
                      {can("filters.delete") ? (
                        <button aria-label={`Xóa ${filter.name}`} className="danger-action" disabled={filterBusy} onClick={() => deleteFilter(filter)} title="Xóa bộ lọc" type="button"><Trash2 size={17} /></button>
                      ) : null}
                    </div>
                  ) : null}
                </article>
              ))}
            </div>
          </Panel>
        ) : null}

        {section === "library" ? (
          <Panel title="Thư viện ảnh" meta={`${captureSessions.length} lượt chụp`}>
            <form className="library-toolbar" onSubmit={(event) => { event.preventDefault(); void loadLibrary(false); }}>
              <label className="library-filter library-filter-machine">
                <span>Máy</span>
                <select onChange={(event) => setLibraryMachine(event.target.value)} value={libraryMachine}>
                  <option value="">Tất cả máy</option>
                  {machines.map((machine) => <option key={machine.id} value={machine.id}>{machineLabel(machine)}</option>)}
                </select>
              </label>
              <label className="library-filter">
                <span>Từ ngày</span>
                <input onChange={(event) => setLibraryFrom(event.target.value)} type="date" value={libraryFrom} />
              </label>
              <label className="library-filter">
                <span>Đến ngày</span>
                <input min={libraryFrom || undefined} onChange={(event) => setLibraryTo(event.target.value)} type="date" value={libraryTo} />
              </label>
              <label className="library-filter library-filter-no" title="Số thứ tự lượt chụp trong ngày; chọn ngày để tìm đúng lượt">
                <span>STT</span>
                <input inputMode="numeric" min={1} onChange={(event) => setLibraryNo(event.target.value)} placeholder="Tất cả" type="number" value={libraryNo} />
              </label>
              <label className="library-filter library-filter-limit">
                <span>Hiển thị</span>
                <select onChange={(event) => setLibraryLimit(Number(event.target.value))} value={libraryLimit}>
                  {LIBRARY_PAGE_SIZES.map((size) => <option key={size} value={size}>{size} lượt gần nhất</option>)}
                </select>
              </label>
              <div className="library-filter-actions">
                <button className="ghost-action" disabled={loading} type="submit"><RefreshCw size={18} />Lọc</button>
                {libraryMachine || libraryFrom || libraryTo || libraryNo ? (
                  <button
                    className="text-action"
                    onClick={() => { setLibraryMachine(""); setLibraryFrom(""); setLibraryTo(""); setLibraryNo(""); }}
                    type="button"
                  >
                    Xoá lọc
                  </button>
                ) : null}
              </div>
            </form>
            <div className="table-shell library-table">
              <table>
                <thead><tr><th className="cell-no">STT</th><th>Thời gian</th><th>Máy</th><th>Preview</th><th className="cell-count">Số ảnh</th><th></th></tr></thead>
                <tbody>
                  {captureSessions.map((session) => {
                    return (
                      <tr key={`${session.machine_id}:${session.session_id}`}>
                        <td className="cell-no" data-label="STT" title={session.session_id}>{session.day_no || "–"}</td>
                        <td data-label="Thời gian">{formatDate(session.started_at || session.created_at)}</td>
                        <td data-label="Máy">{session.device_name || "Máy chưa đặt tên"}</td>
                        <td className="cell-thumb">
                          <div className="session-thumb" aria-label="Ảnh xem nhanh">
                            {session.thumbnail_url ? <img alt="" loading="lazy" src={session.thumbnail_url} /> : <Images size={20} />}
                          </div>
                        </td>
                        <td className="cell-count" data-label="Số ảnh">{session.received_assets}</td>
                        <td className="cell-action">
                          <div className="session-actions">
                            <a className="table-link" href={session.gallery_token
                              ? `/gallery?t=${encodeURIComponent(session.gallery_token)}`
                              : `/gallery?machine_id=${encodeURIComponent(session.machine_id)}&session_id=${encodeURIComponent(session.session_id)}`} target="_blank" rel="noreferrer">
                              <ExternalLink size={16} />Xem ảnh
                            </a>
                            <a
                              aria-label={`Ảnh đã ghép của phiên ${session.session_id}`}
                              className="table-link session-composed-link"
                              href={session.gallery_token
                                ? `/gallery/composed?t=${encodeURIComponent(session.gallery_token)}`
                                : `/gallery/composed?machine_id=${encodeURIComponent(session.machine_id)}&session_id=${encodeURIComponent(session.session_id)}`}
                              rel="noreferrer"
                              target="_blank"
                              title="Xem ảnh khách đã ghép frame"
                            >
                              <Layers3 size={16} />Ảnh đã ghép
                            </a>
                            {can("library.share") ? <><button
                              aria-label={`Copy link album phiên ${session.session_id}`}
                              className={`table-link${copied === sessionKey(session) ? " is-done" : ""}`}
                              onClick={() => copySessionLink(session)}
                              title="Copy link album để gửi khách"
                              type="button"
                            >
                              {copied === sessionKey(session) ? <CheckCircle2 size={16} /> : <Link2 size={16} />}
                              {copied === sessionKey(session) ? "Đã copy" : "Copy link"}
                            </button>
                            <button
                              aria-label={`Mã QR album phiên ${session.session_id}`}
                              className="table-link session-qr-button"
                              onClick={() => openSessionQr(session)}
                              title="Mã QR cho khách quét"
                              type="button"
                            >
                              <QrCode size={16} /><span>QR</span>
                            </button></> : null}
                          </div>
                        </td>
                      </tr>
                    );
                  })}
                </tbody>
              </table>
            </div>
            {captureSessions.length === 0 ? <Empty icon={<Images size={28} />} title="Chưa có lượt chụp" text="Ảnh sẽ xuất hiện khi máy commit upload thành công." /> : null}
            {libraryCursor ? <button className="load-more" disabled={loading} onClick={() => loadLibrary(true)} type="button">Tải thêm</button> : null}
          </Panel>
        ) : null}

        {section === "revenue" ? (
          <Panel title="Doanh thu mã chụp" meta={formatMoney(stats.revenue)}>
            <div className="revenue-strip">
              <Summary label="Lượt dùng mã" value={Number(revenueSummary.used_codes ?? 0)} />
              <Summary label="Doanh thu" value={formatMoney(stats.revenue)} />
              <Summary label="Mã 1 lần" value={Number(revenueSummary.single_uses ?? 0)} />
              <Summary label="Mã dùng lại" value={Number(revenueSummary.reusable_uses ?? 0)} />
              <Summary label="Mã local" value={Number(revenueSummary.local_uses ?? 0)} />
            </div>
            <div className="table-shell revenue-table">
              <table>
                <thead><tr><th>Mã</th><th>Gói</th><th>Máy</th><th>Giá trị</th><th>Thời gian</th></tr></thead>
                <tbody>
                  {revenueUses.map((use) => (
                    <tr key={use.id}>
                      <td className="cell-title" data-label="Mã">{use.code}</td>
                      <td data-label="Gói">{use.room_name || "Phòng"} · {use.package_name || "Gói"}</td>
                      <td data-label="Máy">{use.device_name || "Máy chưa đặt tên"}</td>
                      <td className="cell-money" data-label="Giá trị">{formatMoney(use.price_vnd)}</td>
                      <td data-label="Thời gian">{formatDate(use.used_at)}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </div>
          </Panel>
        ) : null}
      </section>

      {coverEdit ? (() => {
        const roomPackages = visiblePackages.filter((pkg) => pkg.room_id === coverEdit.room.id);
        const from = roomPackages.length ? Math.min(...roomPackages.map((pkg) => pkg.price_vnd)) : null;
        return (
          <CoverEditor
            busy={roomBusy === coverEdit.room.id}
            capacity={coverEdit.room.capacity}
            error={error}
            initialCrop={coverEdit.crop}
            key={coverEdit.src}
            onCancel={closeCoverEditor}
            onSave={saveRoomCover}
            priceLine={from !== null ? `Từ ${money.format(from)} · ${roomPackages.length} gói` : "Chưa có gói"}
            roomName={coverEdit.room.name}
            src={coverEdit.src}
          />
        );
      })() : null}

      {sessionQr ? (() => {
        const qr = sessionQr.url ? qrPath(sessionQr.url) : null;
        const { session } = sessionQr;
        return (
          <div className="gallery-modal" onClick={(event) => { if (event.target === event.currentTarget) setSessionQr(null); }}>
            <section className="gallery-modal-panel session-qr-panel" role="dialog" aria-modal="true" aria-labelledby="session-qr-title">
              <header className="group-modal-head">
                <div>
                  <span className="eyebrow">QR album khách</span>
                  <h2 id="session-qr-title">{session.device_name || "Máy chưa đặt tên"}</h2>
                  <small>{formatDate(session.started_at || session.created_at)} · {session.received_assets} ảnh</small>
                </div>
                <button aria-label="Đóng" autoFocus className="gallery-icon-button" onClick={() => setSessionQr(null)} type="button"><X size={18} /></button>
              </header>
              <div className="booking-qr session-qr">
                {qr ? (
                  <svg aria-label="Mã QR album của phiên chụp" role="img" shapeRendering="crispEdges" viewBox={`0 0 ${qr.size} ${qr.size}`}>
                    <rect fill="#fff" height={qr.size} width={qr.size} />
                    <path d={qr.d} fill="#111" />
                  </svg>
                ) : <div className="session-qr-loading" aria-label="Đang tạo mã QR"><div className="loading-line" /></div>}
                <p className="booking-qr-link">{sessionQr.url || "Đang tạo link…"}</p>
                <div className="booking-qr-actions">
                  <button
                    className="primary-action"
                    disabled={!sessionQr.url}
                    onClick={() => downloadQr(sessionQr.url, branding?.name || auth.studio.name, "Quét mã để xem ảnh của bạn", `qr-album-${session.session_id}.png`)}
                    type="button"
                  >
                    <Download size={17} />Tải mã QR
                  </button>
                  <button className="ghost-action" disabled={!sessionQr.url} onClick={() => copySessionLink(session)} type="button">
                    {copied === sessionKey(session) ? <CheckCircle2 size={17} /> : <Copy size={17} />}
                    {copied === sessionKey(session) ? "Đã copy link" : "Copy link"}
                  </button>
                  {sessionQr.url ? <a className="text-action" href={sessionQr.url} rel="noreferrer" target="_blank"><ExternalLink size={16} />Mở album</a> : null}
                </div>
              </div>
              <p className="session-qr-note">Album mở tự do trong 24 giờ sau khi chụp. Sau đó, phiên có đặt lịch sẽ hỏi số điện thoại đã đặt; phiên khách vãng lai vẫn mở được.</p>
            </section>
          </div>
        );
      })() : null}

      {passwordOpen ? <PasswordDialog onClose={() => setPasswordOpen(false)} /> : null}

      {pendingDelete ? (
        <div className="undo-bar" key={pendingDelete.ids.join(",")} role="status" aria-live="polite" style={{ "--undo-ms": `${UNDO_MS}ms` } as CSSProperties}>
          <span>{pendingDelete.label}</span>
          <button onClick={undoDelete} type="button"><Undo2 size={16} />Hoàn tác</button>
          <i aria-hidden="true" />
        </div>
      ) : null}
    </main>
  );
}

function Panel({ children, meta, title }: { children: ReactNode; meta: string; title: string }) {
  return (
    <section className="device-panel">
      <div className="panel-heading">
        <h2>{title}</h2>
        <p>{meta}</p>
      </div>
      {children}
    </section>
  );
}

function Empty({ icon, text, title }: { icon: ReactNode; text: string; title: string }) {
  return <div className="empty-state">{icon}<strong>{title}</strong><span>{text}</span></div>;
}

function Summary({ label, value }: { label: string; value: number | string }) {
  return <div><span>{label}</span><strong>{value}</strong></div>;
}

