// Hash mật khẩu: PBKDF2-HMAC-SHA256, salt 16 byte, 100 000 vòng, khóa 32 byte.
// Định dạng lưu (web phải verify đúng định dạng này):
//   pbkdf2_sha256$<iterations>$<salt_base64>$<hash_base64>
// 100 000 là mức tối đa Workers WebCrypto cho phép với PBKDF2.

import { fromB64, timingSafeEqual, toB64 } from "./http";

const ITERATIONS = 100_000;
const SALT_BYTES = 16;
const KEY_BITS = 256;

async function derive(password: string, salt: Uint8Array, iterations: number): Promise<Uint8Array> {
  const key = await crypto.subtle.importKey(
    "raw", new TextEncoder().encode(password), "PBKDF2", false, ["deriveBits"]);
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt, iterations }, key, KEY_BITS);
  return new Uint8Array(bits);
}

export async function hashPassword(password: string): Promise<string> {
  const salt = new Uint8Array(SALT_BYTES);
  crypto.getRandomValues(salt);
  const hash = await derive(password, salt, ITERATIONS);
  return `pbkdf2_sha256$${ITERATIONS}$${toB64(salt)}$${toB64(hash)}`;
}

export async function verifyPassword(password: string, stored: string): Promise<boolean> {
  const parts = stored.split("$");
  if (parts.length !== 4 || parts[0] !== "pbkdf2_sha256") return false;
  const iterations = Number(parts[1]);
  if (!Number.isInteger(iterations) || iterations < 1 || iterations > ITERATIONS) return false;
  const hash = await derive(password, fromB64(parts[2]), iterations);
  return timingSafeEqual(toB64(hash), parts[3]);
}

// Chạy một lần derive giả khi email không tồn tại để thời gian phản hồi giống nhau
// (không lộ email nào đã đăng ký qua thời gian trả lời).
export async function burnPasswordCheck(password: string): Promise<void> {
  await derive(password, new Uint8Array(SALT_BYTES), ITERATIONS);
}
