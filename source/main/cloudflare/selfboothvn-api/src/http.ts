// Tiện ích HTTP/crypto dùng chung cho mọi route.

export interface Env {
  DB: D1Database;
  MEDIA: R2Bucket;
  API_TOKEN: string;             // legacy bootstrap: chỉ còn cho /v1/machines/register nếu dùng thủ công
  ADMIN_API_TOKEN: string;       // route /v1/admin/*
  UPLOAD_SIGNING_SECRET: string; // ký upload_url
  LICENSE_PUBLIC_KEYS: string;   // "kid:hex,kid2:hex" — khoá công khai xác minh giấy phép (license.ts)
}

export const corsHeaders: Record<string, string> = {
  "access-control-allow-origin": "*",
  "access-control-allow-methods": "GET, HEAD, POST, PUT, PATCH, DELETE, OPTIONS",
  "access-control-allow-headers": "authorization, content-type, range",
  "access-control-expose-headers": "content-length, content-range, accept-ranges, etag",
};

export function json(body: unknown, status = 200, extraHeaders: Record<string, string> = {}): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, ...extraHeaders, "content-type": "application/json; charset=utf-8" },
  });
}

// Lỗi nghiệp vụ: `error` là mã ổn định để client rẽ nhánh, `message` để hiển thị.
export function fail(status: number, error: string, message?: string): Response {
  return json({ success: false, error, ...(message ? { message } : {}) }, status);
}

export class HttpError extends Error {
  constructor(public status: number, public code: string, message?: string) {
    super(message ?? code);
  }
}

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const body = await req.json();
    if (body && typeof body === "object" && !Array.isArray(body)) return body as Record<string, unknown>;
  } catch {
    // rơi xuống lỗi bên dưới
  }
  throw new HttpError(400, "invalid_json");
}

export function nowIso(): string {
  return new Date().toISOString();
}

export function newId(): string {
  return crypto.randomUUID();
}

export function str(v: unknown, maxLen = 1000): string {
  return typeof v === "string" ? v.trim().slice(0, maxLen) : "";
}

// Số nguyên không âm; giá trị khác -> fallback.
export function int(v: unknown, fallback = 0): number {
  return typeof v === "number" && Number.isInteger(v) && v >= 0 ? v : fallback;
}

export function bearer(req: Request): string {
  const auth = (req.headers.get("authorization") ?? "").trim();
  return auth.startsWith("Bearer ") ? auth.slice(7).trim() : "";
}

export function timingSafeEqual(a: string, b: string): boolean {
  const ea = new TextEncoder().encode(a);
  const eb = new TextEncoder().encode(b);
  if (ea.length !== eb.length) return false;
  let diff = 0;
  for (let i = 0; i < ea.length; i++) diff |= ea[i] ^ eb[i];
  return diff === 0;
}

export function toHex(buf: ArrayBuffer): string {
  return [...new Uint8Array(buf)].map((b) => b.toString(16).padStart(2, "0")).join("");
}

export function toB64(bytes: Uint8Array): string {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

export function fromB64(b64: string): Uint8Array {
  const s = atob(b64);
  const out = new Uint8Array(s.length);
  for (let i = 0; i < s.length; i++) out[i] = s.charCodeAt(i);
  return out;
}

export async function sha256Hex(text: string): Promise<string> {
  return toHex(await crypto.subtle.digest("SHA-256", new TextEncoder().encode(text)));
}

export async function hmacHex(secret: string, message: string): Promise<string> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" }, false, ["sign"]);
  return toHex(await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(message)));
}

export function randomToken(prefix: string): string {
  const b = new Uint8Array(32);
  crypto.getRandomValues(b);
  return prefix + toB64(b).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}

// Định danh do app sinh (hwid, session_id, use_id): chữ, số, . _ -
export function isSafeId(v: string, min = 1, max = 128): boolean {
  return v.length >= min && v.length <= max && /^[A-Za-z0-9._-]+$/.test(v) && v !== "." && v !== "..";
}
