// What a studio's staff may do in the browser admin. One code per action; the owner ticks
// them per staff member. The server checks them on every /v1/web route
// (requirePermission in webAuth.ts); the web only hides what the server would refuse.
// The owner has every permission. Managing staff is owner-only and never a permission,
// so a staff account can never raise its own rights.

export type PermissionGroup = {
  id: string;
  label: string;
  actions: Array<{ code: string; label: string }>;
};

export const PERMISSION_GROUPS: PermissionGroup[] = [
  {
    id: "bookings", label: "Đặt lịch", actions: [
      { code: "bookings.view", label: "Xem lịch" },
      { code: "bookings.create", label: "Thêm lịch tại quầy" },
      { code: "bookings.confirm", label: "Xác nhận lịch" },
      { code: "bookings.checkin", label: "Đánh dấu đã chụp" },
      { code: "bookings.cancel", label: "Hủy lịch" },
      { code: "bookings.edit", label: "Sửa giờ, phòng, khách" },
      { code: "bookings.settings", label: "Cài đặt đặt lịch & QR" },
    ],
  },
  {
    id: "codes", label: "Mã chụp", actions: [
      { code: "codes.view", label: "Xem mã" },
      { code: "codes.create", label: "Tạo mã" },
      { code: "codes.revoke", label: "Thu hồi mã" },
      { code: "codes.delete", label: "Xóa mã" },
    ],
  },
  {
    id: "library", label: "Thư viện ảnh", actions: [
      { code: "library.view", label: "Xem phiên chụp & ảnh" },
      { code: "library.share", label: "Copy link & QR album" },
    ],
  },
  {
    id: "rooms", label: "Phòng chụp", actions: [
      { code: "rooms.view", label: "Xem phòng" },
      { code: "rooms.create", label: "Thêm phòng" },
      { code: "rooms.edit", label: "Sửa thông tin & ảnh bìa" },
      { code: "rooms.delete", label: "Xóa phòng" },
    ],
  },
  {
    id: "packages", label: "Gói chụp", actions: [
      { code: "packages.view", label: "Xem gói" },
      { code: "packages.create", label: "Thêm gói" },
      { code: "packages.delete", label: "Xóa gói" },
    ],
  },
  {
    id: "frames", label: "Thư viện frame", actions: [
      { code: "frames.view", label: "Xem frame" },
      { code: "frames.upload", label: "Tải frame lên" },
      { code: "frames.edit", label: "Đổi tên & nhóm ô" },
      { code: "frames.delete", label: "Xóa frame" },
    ],
  },
  {
    id: "filters", label: "Bộ lọc màu", actions: [
      { code: "filters.view", label: "Xem bộ lọc" },
      { code: "filters.upload", label: "Tải bộ lọc lên" },
      { code: "filters.edit", label: "Đổi tên & ảnh mẫu" },
      { code: "filters.delete", label: "Xóa bộ lọc" },
    ],
  },
  {
    id: "devices", label: "Thiết bị", actions: [
      { code: "devices.view", label: "Xem máy" },
      { code: "devices.rename", label: "Đổi tên máy" },
    ],
  },
  {
    id: "revenue", label: "Doanh thu", actions: [
      { code: "revenue.view", label: "Xem doanh thu" },
    ],
  },
  {
    id: "brand", label: "Thương hiệu", actions: [
      { code: "brand.edit", label: "Sửa tên, logo, màu" },
    ],
  },
];

export const ALL_PERMISSIONS = new Set(PERMISSION_GROUPS.flatMap((group) => group.actions.map((action) => action.code)));

/** One-tap starting points in the staff editor; the owner can still change any box. */
export const PERMISSION_PRESETS: Array<{ id: string; label: string; permissions: string[] }> = [
  {
    id: "front-desk",
    label: "Lễ tân",
    permissions: [
      "bookings.view", "bookings.create", "bookings.confirm", "bookings.checkin",
      "codes.view", "codes.create",
      "library.view", "library.share",
    ],
  },
  {
    id: "manager",
    label: "Quản lý",
    permissions: [...ALL_PERMISSIONS].filter((code) => !code.startsWith("brand.") && !code.startsWith("revenue.")),
  },
];

/**
 * Keep known codes only; every action brings its group's "view" (acting on what you
 * cannot see makes no sense, and the screens need the list).
 */
export function normalizePermissions(raw: unknown): string[] {
  const list = Array.isArray(raw) ? raw : [];
  const picked = new Set(list.filter((code): code is string => typeof code === "string" && ALL_PERMISSIONS.has(code)));
  for (const code of [...picked]) {
    const view = `${code.split(".")[0]}.view`;
    if (ALL_PERMISSIONS.has(view)) picked.add(view);
  }
  return [...ALL_PERMISSIONS].filter((code) => picked.has(code));
}

export function parseStoredPermissions(json: string | null | undefined): Set<string> {
  try {
    return new Set(normalizePermissions(JSON.parse(json || "[]")));
  } catch {
    return new Set();
  }
}

/**
 * Reads a screen needs from other groups. A booking desk lists rooms and packages, the
 * photo library names the machines and lets staff compose for a guest with frames and
 * filters: any of these permissions opens that read.
 */
export const READ_ROOMS_PACKAGES = ["rooms.view", "packages.view", "bookings.view", "codes.view"];
export const READ_MACHINES = ["devices.view", "library.view"];
export const READ_FRAMES = ["frames.view", "library.view"];
export const READ_FILTERS = ["filters.view", "library.view"];

export function permissionLabel(code: string): string {
  for (const group of PERMISSION_GROUPS) {
    const action = group.actions.find((item) => item.code === code);
    if (action) return `${group.label} · ${action.label}`;
  }
  return code;
}
