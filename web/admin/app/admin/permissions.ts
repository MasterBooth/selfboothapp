/**
 * What the signed-in account may do, as the API reported it at sign-in (`user.permissions`).
 * The owner holds every permission. The server checks each request again
 * (src/permissions.ts in the API); here it only decides what to show.
 */

export type Role = "owner" | "staff";

export type AdminUser = {
  id: string;
  email: string;
  role: Role | string;
  username?: string;
  display_name?: string;
  permissions?: string[];
};

export type Can = (code: string) => boolean;

export function makeCan(user: AdminUser | null | undefined): Can {
  if (!user) return () => false;
  if (user.role === "owner") return () => true;
  const granted = new Set(user.permissions ?? []);
  return (code) => granted.has(code);
}

export type Section =
  | "bookings" | "codes" | "library"
  | "rooms" | "packages" | "frames" | "filters" | "devices"
  | "revenue" | "brand" | "staff";

/** The permission that opens each section; `owner` = owner only (staff management). */
export const SECTION_ACCESS: Record<Section, string> = {
  bookings: "bookings.view",
  codes: "codes.view",
  library: "library.view",
  rooms: "rooms.view",
  packages: "packages.view",
  frames: "frames.view",
  filters: "filters.view",
  devices: "devices.view",
  revenue: "revenue.view",
  brand: "brand.edit",
  staff: "owner",
};

export function canOpen(section: Section, user: AdminUser | null | undefined, can: Can) {
  const access = SECTION_ACCESS[section];
  return access === "owner" ? user?.role === "owner" : can(access);
}

export function displayName(user: AdminUser) {
  return user.display_name || user.username || user.email || "Tài khoản";
}

export function roleLabel(user: AdminUser) {
  return user.role === "owner" ? "Chủ studio" : "Nhân viên";
}
