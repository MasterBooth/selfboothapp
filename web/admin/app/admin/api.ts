/** JSON fetch for the admin panels (same behaviour as apiJson in app/page.tsx). */

export type ApiError = Error & { status?: number; code?: string };

/**
 * Which sign-in door this page is: `/staff…` = staff, otherwise the owner. The API keeps one
 * session per door, so the owner and a staff member can be signed in on the same browser.
 */
export function portalHeaders(): Record<string, string> {
  if (typeof window === "undefined") return {};
  return { "x-sb-portal": window.location.pathname.startsWith("/staff") ? "staff" : "owner" };
}

export async function adminApi<T>(path: string, init: RequestInit = {}): Promise<T> {
  const isJsonBody = typeof init.body === "string";
  const response = await fetch(path, {
    ...init,
    credentials: "include",
    headers: { ...portalHeaders(), ...(isJsonBody ? { "content-type": "application/json" } : {}), ...(init.headers ?? {}) },
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

/** 570 → "09:30". */
export function clock(minute: number) {
  const m = ((minute % 1440) + 1440) % 1440;
  return `${String(Math.floor(m / 60)).padStart(2, "0")}:${String(m % 60).padStart(2, "0")}`;
}

/** "09:30" → 570 (NaN when malformed). */
export function minutesOf(value: string) {
  const match = /^(\d{1,2}):(\d{2})$/.exec(value.trim());
  return match ? Number(match[1]) * 60 + Number(match[2]) : Number.NaN;
}

export function addDays(date: string, days: number) {
  const d = new Date(`${date}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + days);
  return d.toISOString().slice(0, 10);
}

const WEEKDAYS = ["CN", "T2", "T3", "T4", "T5", "T6", "T7"];

/** "2026-10-03" → { weekday: "T7", day: "03/10" }. */
export function dayLabel(date: string) {
  const d = new Date(`${date}T00:00:00Z`);
  return { weekday: WEEKDAYS[d.getUTCDay()], day: `${date.slice(8, 10)}/${date.slice(5, 7)}` };
}

export const money = new Intl.NumberFormat("vi-VN", { style: "currency", currency: "VND", maximumFractionDigits: 0 });
