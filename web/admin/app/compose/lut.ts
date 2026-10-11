/**
 * 3D LUT (.cube) support: parse once, apply with trilinear interpolation on a canvas.
 * Shared by the admin (thumbnail generation), the editor preview and the print render,
 * so every place shows the same colours.
 */

export type Lut = {
  size: number;
  /** RGB triplets, red fastest, then green, then blue (Adobe .cube order). */
  table: Float32Array;
  domainMin: [number, number, number];
  domainMax: [number, number, number];
};

export type FilterItem = {
  id: string;
  name: string;
  lut_size: number;
  cube_size_bytes: number;
  cube_url: string;
  thumbnail_url: string;
};

export function parseCube(text: string): Lut {
  let size = 0;
  let domainMin: [number, number, number] = [0, 0, 0];
  let domainMax: [number, number, number] = [1, 1, 1];
  const values: number[] = [];
  for (const raw of text.split(/\r?\n/)) {
    const line = raw.trim();
    if (!line || line.startsWith("#")) continue;
    const parts = line.split(/\s+/);
    const key = parts[0].toUpperCase();
    if (key === "LUT_3D_SIZE") { size = Number(parts[1]); continue; }
    if (key === "LUT_1D_SIZE") throw new Error("Chỉ hỗ trợ LUT 3D (.cube)");
    if (key === "DOMAIN_MIN") { domainMin = [Number(parts[1]), Number(parts[2]), Number(parts[3])]; continue; }
    if (key === "DOMAIN_MAX") { domainMax = [Number(parts[1]), Number(parts[2]), Number(parts[3])]; continue; }
    if (/^[A-Z_]/i.test(line)) continue;
    values.push(Number(parts[0]), Number(parts[1]), Number(parts[2]));
  }
  if (!Number.isInteger(size) || size < 2 || size > 128) throw new Error("File .cube thiếu hoặc sai LUT_3D_SIZE");
  if (values.length !== size ** 3 * 3 || values.some((v) => !Number.isFinite(v))) {
    throw new Error(`File .cube cần ${size ** 3} dòng màu hợp lệ`);
  }
  return { size, table: Float32Array.from(values), domainMin, domainMax };
}

const lutCache = new Map<string, Promise<Lut>>();

/** Fetch and parse a filter's LUT once per page. */
export function loadLut(filter: Pick<FilterItem, "id" | "cube_url">): Promise<Lut> {
  const cached = lutCache.get(filter.id);
  if (cached) return cached;
  const promise = fetch(filter.cube_url, { credentials: "include" })
    .then((response) => {
      if (!response.ok) throw new Error("Không tải được bộ lọc màu");
      return response.text();
    })
    .then(parseCube);
  promise.catch(() => lutCache.delete(filter.id));
  lutCache.set(filter.id, promise);
  return promise;
}

/** Apply the LUT to RGBA pixels in place (trilinear interpolation). */
export function applyLutToPixels(pixels: Uint8ClampedArray, lut: Lut) {
  const { size, table, domainMin, domainMax } = lut;
  const max = size - 1;
  const size2 = size * size;
  const scale = [0, 1, 2].map((c) => max / 255 / ((domainMax[c] - domainMin[c]) || 1));
  const offset = [0, 1, 2].map((c) => -domainMin[c] * max / ((domainMax[c] - domainMin[c]) || 1));
  for (let i = 0; i < pixels.length; i += 4) {
    const r = Math.min(max, Math.max(0, pixels[i] * scale[0] + offset[0]));
    const g = Math.min(max, Math.max(0, pixels[i + 1] * scale[1] + offset[1]));
    const b = Math.min(max, Math.max(0, pixels[i + 2] * scale[2] + offset[2]));
    const r0 = Math.floor(r); const g0 = Math.floor(g); const b0 = Math.floor(b);
    const r1 = Math.min(max, r0 + 1); const g1 = Math.min(max, g0 + 1); const b1 = Math.min(max, b0 + 1);
    const fr = r - r0; const fg = g - g0; const fb = b - b0;
    const i000 = (r0 + g0 * size + b0 * size2) * 3;
    const i100 = (r1 + g0 * size + b0 * size2) * 3;
    const i010 = (r0 + g1 * size + b0 * size2) * 3;
    const i110 = (r1 + g1 * size + b0 * size2) * 3;
    const i001 = (r0 + g0 * size + b1 * size2) * 3;
    const i101 = (r1 + g0 * size + b1 * size2) * 3;
    const i011 = (r0 + g1 * size + b1 * size2) * 3;
    const i111 = (r1 + g1 * size + b1 * size2) * 3;
    for (let c = 0; c < 3; c++) {
      const c00 = table[i000 + c] + (table[i100 + c] - table[i000 + c]) * fr;
      const c10 = table[i010 + c] + (table[i110 + c] - table[i010 + c]) * fr;
      const c01 = table[i001 + c] + (table[i101 + c] - table[i001 + c]) * fr;
      const c11 = table[i011 + c] + (table[i111 + c] - table[i011 + c]) * fr;
      const c0 = c00 + (c10 - c00) * fg;
      const c1 = c01 + (c11 - c01) * fg;
      pixels[i + c] = (c0 + (c1 - c0) * fb) * 255;
    }
  }
}

type Source = HTMLImageElement | HTMLCanvasElement | ImageBitmap;

export function sourceSize(source: Source) {
  if (source instanceof HTMLImageElement) return { width: source.naturalWidth, height: source.naturalHeight };
  return { width: source.width, height: source.height };
}

/** Draw `source` scaled so its long side is at most `maxSide`, then apply the LUT. */
export function filteredCanvas(source: Source, lut: Lut | null, maxSide = 1600): HTMLCanvasElement {
  const { width, height } = sourceSize(source);
  const ratio = Math.min(1, maxSide / Math.max(width, height));
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(width * ratio));
  canvas.height = Math.max(1, Math.round(height * ratio));
  const ctx = canvas.getContext("2d", { willReadFrequently: true });
  if (!ctx) throw new Error("Trình duyệt không hỗ trợ bộ lọc màu");
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(source, 0, 0, canvas.width, canvas.height);
  if (lut) {
    const data = ctx.getImageData(0, 0, canvas.width, canvas.height);
    applyLutToPixels(data.data, lut);
    ctx.putImageData(data, 0, 0);
  }
  return canvas;
}

export function canvasToBlob(canvas: HTMLCanvasElement, type = "image/jpeg", quality = 0.88): Promise<Blob> {
  return new Promise((resolve, reject) => {
    canvas.toBlob((blob) => blob ? resolve(blob) : reject(new Error("Không tạo được ảnh")), type, quality);
  });
}

export function loadImageElement(url: string): Promise<HTMLImageElement> {
  return new Promise((resolve, reject) => {
    const image = new Image();
    image.crossOrigin = "anonymous";
    image.decoding = "async";
    image.onload = () => resolve(image);
    image.onerror = () => reject(new Error("Không tải được ảnh"));
    image.src = url;
  });
}

/**
 * Neutral sample used for an auto thumbnail when the admin gives no photo:
 * warm-to-cool sky, a skin-tone band and a grey ramp, so the LUT's character shows.
 */
export function sampleSwatch(size = 320): HTMLCanvasElement {
  const canvas = document.createElement("canvas");
  canvas.width = size;
  canvas.height = size;
  const ctx = canvas.getContext("2d")!;
  const sky = ctx.createLinearGradient(0, 0, size, 0);
  ["#2f6fb0", "#6fb3d9", "#f2c879", "#e0784a", "#8a3b6b"].forEach((c, i, all) => sky.addColorStop(i / (all.length - 1), c));
  ctx.fillStyle = sky;
  ctx.fillRect(0, 0, size, size * 0.5);
  const skin = ctx.createLinearGradient(0, 0, size, 0);
  ["#f6d7c3", "#e8b896", "#c98d68", "#8d5a3f"].forEach((c, i, all) => skin.addColorStop(i / (all.length - 1), c));
  ctx.fillStyle = skin;
  ctx.fillRect(0, size * 0.5, size, size * 0.25);
  const grey = ctx.createLinearGradient(0, 0, size, 0);
  grey.addColorStop(0, "#111");
  grey.addColorStop(1, "#f4f4f4");
  ctx.fillStyle = grey;
  ctx.fillRect(0, size * 0.75, size, size * 0.25);
  return canvas;
}

/** Square JPEG thumbnail: centre-cropped photo (or the sample swatch) with the LUT applied. */
export async function makeFilterThumbnail(lut: Lut | null, photo?: File | null, size = 360): Promise<Blob> {
  let source: Source = sampleSwatch(size);
  if (photo) {
    const url = URL.createObjectURL(photo);
    try {
      source = await loadImageElement(url);
    } finally {
      URL.revokeObjectURL(url);
    }
  }
  const { width, height } = sourceSize(source);
  const side = Math.min(width, height);
  const square = document.createElement("canvas");
  square.width = size;
  square.height = size;
  const ctx = square.getContext("2d")!;
  ctx.imageSmoothingQuality = "high";
  ctx.drawImage(source, (width - side) / 2, (height - side) / 2, side, side, 0, 0, size, size);
  return canvasToBlob(filteredCanvas(square, lut, size));
}
