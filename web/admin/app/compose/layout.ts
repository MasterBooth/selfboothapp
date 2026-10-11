/**
 * Slot placement shared by the on-screen editor and the print renderer, so both
 * produce the same picture. Every value is a fraction of the slot box, which keeps
 * the math independent of screen size and output resolution.
 *
 * zoom 1 = the photo just covers the slot (default), at any rotation. Below 1 the
 * photo shrinks to show more of the scene; the uncovered area is filled with a
 * blurred copy and the photo's edges are feathered into it.
 *
 * Pan (x, y) runs along the slot's own axes, so dragging always follows the finger;
 * rotation and the mirror flip turn the photo about its centre.
 */

export type SlotTransform = {
  zoom: number;
  /** Photo centre offset from the slot centre, as fractions of the slot width / height. */
  x: number;
  y: number;
  /** Degrees clockwise, -180…180. */
  rotate?: number;
  /** Mirror left ↔ right. */
  flip?: boolean;
};

type DrawSource = HTMLImageElement | HTMLCanvasElement;

function sourceDims(source: DrawSource) {
  return source instanceof HTMLImageElement
    ? { width: source.naturalWidth, height: source.naturalHeight }
    : { width: source.width, height: source.height };
}

export type SlotLayout = {
  /** Photo size (before rotation) relative to the slot (1 = slot width / height). */
  width: number;
  height: number;
  /** Photo top-left (before rotation) relative to the slot. */
  left: number;
  top: number;
  /** Feather size as a fraction of the photo's own width / height (0 = hard edge). */
  featherX: number;
  featherY: number;
  /** True when part of the slot is not covered by the photo. */
  needsFill: boolean;
  /** Turn and mirror applied about the photo's centre. */
  rotate: number;
  flip: boolean;
};

export const MAX_ZOOM = 4;
/** Soft-edge and blur strength, as a fraction of the slot's shorter side. */
export const SOFT_EDGE = 0.06;
/** How far (in blur radii) the blurred fill overhangs the slot on each side. */
export const FILL_BLEED = 3.5;
const EPSILON = 0.002;

export const DEFAULT_TRANSFORM: SlotTransform = { zoom: 1, x: 0, y: 0, rotate: 0, flip: false };

/** -180 < angle ≤ 180. */
export function normalizeAngle(degrees: number) {
  const a = ((degrees % 360) + 360) % 360;
  return a > 180 ? a - 360 : a;
}

/**
 * Geometry in slot-width units (slot = 1 × 1/slotAspect). `foot` is the slot's
 * footprint seen from the turned photo; `cover` the photo size that just covers it.
 */
function geometry(slotAspect: number, imageAspect: number, rotate = 0) {
  const w = 1;
  const h = 1 / slotAspect;
  const angle = (rotate * Math.PI) / 180;
  const cos = Math.cos(angle);
  const sin = Math.sin(angle);
  const c = Math.abs(cos);
  const s = Math.abs(sin);
  const footW = w * c + h * s;
  const footH = w * s + h * c;
  const cover = imageAspect > footW / footH
    ? { w: footH * imageAspect, h: footH }
    : { w: footW, h: footW / imageAspect };
  return { w, h, cos, sin, c, s, footW, footH, cover };
}

/** Smallest zoom: a little past "whole photo visible", but never below 20%. */
export function minZoom(slotAspect: number, imageAspect: number, rotate = 0) {
  const g = geometry(slotAspect, imageAspect, rotate);
  const contain = Math.min(g.footW / g.cover.w, g.footH / g.cover.h);
  return Math.max(0.2, Math.min(0.6, contain * 0.85));
}

/** How far x / y (slot fractions) may move at this zoom (0 = locked on that axis). */
export function panLimits(slotAspect: number, imageAspect: number, zoom: number, rotate = 0) {
  const g = geometry(slotAspect, imageAspect, rotate);
  const limU = Math.abs(g.cover.w * zoom - g.footW) / 2;
  const limV = Math.abs(g.cover.h * zoom - g.footH) / 2;
  return { x: (limU * g.c + limV * g.s) / g.w, y: (limU * g.s + limV * g.c) / g.h };
}

/** Clamp zoom to the allowed range and keep the photo from drifting off its slot. */
export function clampTransform(t: SlotTransform, slotAspect: number, imageAspect: number): SlotTransform {
  const rotate = normalizeAngle(t.rotate ?? 0);
  const g = geometry(slotAspect, imageAspect, rotate);
  const zoom = Math.min(MAX_ZOOM, Math.max(minZoom(slotAspect, imageAspect, rotate), t.zoom));
  // Work in the photo's own axes: larger than the slot never reveals a gap, smaller never leaves it.
  const px = t.x * g.w;
  const py = t.y * g.h;
  const limU = Math.abs(g.cover.w * zoom - g.footW) / 2;
  const limV = Math.abs(g.cover.h * zoom - g.footH) / 2;
  const u = Math.min(limU, Math.max(-limU, px * g.cos + py * g.sin));
  const v = Math.min(limV, Math.max(-limV, -px * g.sin + py * g.cos));
  return {
    zoom,
    x: (u * g.cos - v * g.sin) / g.w,
    y: (u * g.sin + v * g.cos) / g.h,
    rotate,
    flip: Boolean(t.flip),
  };
}

export function slotLayout(slotAspect: number, imageAspect: number, t: SlotTransform): SlotLayout {
  const rotate = normalizeAngle(t.rotate ?? 0);
  const g = geometry(slotAspect, imageAspect, rotate);
  const photoW = g.cover.w * t.zoom;
  const photoH = g.cover.h * t.zoom;
  const width = photoW / g.w;
  const height = photoH / g.h;
  const shrunkX = photoW < g.footW - EPSILON;
  const shrunkY = photoH < g.footH - EPSILON;
  // Edge size in slot-width units, then expressed relative to the photo's own size.
  const edge = SOFT_EDGE * Math.min(g.w, g.h);
  return {
    width,
    height,
    left: 0.5 + t.x - width / 2,
    top: 0.5 + t.y - height / 2,
    featherX: shrunkX ? Math.min(0.25, edge / photoW) : 0,
    featherY: shrunkY ? Math.min(0.25, edge / photoH) : 0,
    needsFill: shrunkX || shrunkY,
    rotate,
    flip: Boolean(t.flip),
  };
}

/** CSS transform for the photo (and its blurred fill): turn, then mirror, about the centre. */
export function photoTransform(layout: Pick<SlotLayout, "rotate" | "flip">) {
  const parts = [];
  if (layout.rotate) parts.push(`rotate(${layout.rotate.toFixed(2)}deg)`);
  if (layout.flip) parts.push("scaleX(-1)");
  return parts.length ? parts.join(" ") : undefined;
}

/**
 * Box (px, centred on the slot) the blurred fill must cover so no corner shows at
 * this rotation, overhanging the slot by `bleed` px on each side.
 */
export function fillBox(slotWidth: number, slotHeight: number, rotate: number, bleed: number) {
  const angle = (rotate * Math.PI) / 180;
  const c = Math.abs(Math.cos(angle));
  const s = Math.abs(Math.sin(angle));
  const w = slotWidth + 2 * bleed;
  const h = slotHeight + 2 * bleed;
  return { width: w * c + h * s, height: w * s + h * c };
}

/** CSS mask that fades the photo's edges, matching the canvas feather in drawSlot. */
export function featherMask(layout: SlotLayout) {
  const masks: string[] = [];
  if (layout.featherX > 0) {
    const f = (layout.featherX * 100).toFixed(2);
    masks.push(`linear-gradient(to right, transparent, black ${f}%, black calc(100% - ${f}%), transparent)`);
  }
  if (layout.featherY > 0) {
    const f = (layout.featherY * 100).toFixed(2);
    masks.push(`linear-gradient(to bottom, transparent, black ${f}%, black calc(100% - ${f}%), transparent)`);
  }
  if (masks.length === 0) return undefined;
  return masks.join(", ");
}

/** A rectangle in frame fractions (0–1 of the frame's width / height). */
export type FrameRect = { x: number; y: number; width: number; height: number };

/** A slot as stored with the frame. `group` is set when the admin upload worked out the frame's groups. */
export type GroupedRect = FrameRect & { group?: number };

export type SlotGroup = {
  /** Slot indexes in reading order. */
  slots: number[];
  /** The part of the frame this group owns, in frame fractions. */
  region: FrameRect;
};

export type FrameGroups = {
  groups: SlotGroup[];
  /** True when every group is the same layout repeated (e.g. two strips cut from one 4x6). */
  copies: boolean;
};

export type Axis = "x" | "y";

/** An empty gutter between two sets of slots that the frame could be cut along. */
export type FrameCut = {
  /** "x": a vertical gutter, slots left and right of it. "y": a horizontal one. */
  axis: Axis;
  /** Gutter edges on `axis`, in frame fractions. */
  from: number;
  to: number;
  /** Extent of the slots being split on the other axis, in frame fractions. */
  cross: [number, number];
};

/** Looks at the frame picture: true when a card edge runs along the gutter. */
export type GutterProbe = (cut: FrameCut) => boolean;

type Candidate = FrameCut & { size: number; before: number[]; after: number[] };

/** Slots that overlap on an axis by less than this (frame fraction) still sit in separate bands. */
const BAND_EPSILON = 0.004;
/** How far (frame fraction) matching slots in two bands may drift and still be copies. */
const COPY_TOLERANCE = 0.012;
/** Gutters narrower than this share of a typical slot's short side never split (grid bars, strip spacing). */
const MIN_GUTTER = 0.12;
/** Copies only split when the gutter between them beats every gutter inside them by this much. */
const COPY_GAP_RATIO = 1.5;
/** Gutters at least this share of a typical slot's short side always split. */
const WIDE_GUTTER = 0.3;
/** Luminance step (0–255, over 2 px) that counts as an edge in the frame picture. */
const EDGE_STEP = 24;
/** Share of the lines across a gutter that must meet an edge for it to be a card boundary. */
const EDGE_COVERAGE = 0.75;
const FULL_FRAME: FrameRect = { x: 0, y: 0, width: 1, height: 1 };

function readingOrder(slots: FrameRect[], indexes: number[]) {
  if (indexes.length === 0) return [];
  const rowTolerance = 0.25 * Math.min(...indexes.map((i) => slots[i].height));
  return [...indexes].sort((a, b) => {
    const dy = slots[a].y - slots[b].y;
    return Math.abs(dy) > rowTolerance ? dy : slots[a].x - slots[b].x;
  });
}

const startOf = (r: FrameRect, axis: Axis) => axis === "x" ? r.x : r.y;
const endOf = (r: FrameRect, axis: Axis) => axis === "x" ? r.x + r.width : r.y + r.height;

/** Split slots into bands along an axis wherever no slot crosses. */
function splitBands(slots: FrameRect[], axis: Axis, indexes: number[]) {
  const order = [...indexes].sort((a, b) => startOf(slots[a], axis) - startOf(slots[b], axis));
  const bands: Array<{ slots: number[]; start: number; end: number }> = [];
  for (const index of order) {
    const band = bands[bands.length - 1];
    if (band && startOf(slots[index], axis) < band.end - BAND_EPSILON) {
      band.slots.push(index);
      band.end = Math.max(band.end, endOf(slots[index], axis));
    } else {
      bands.push({ slots: [index], start: startOf(slots[index], axis), end: endOf(slots[index], axis) });
    }
  }
  return bands;
}

function median(values: number[]) {
  if (values.length === 0) return 0;
  const sorted = [...values].sort((a, b) => a - b);
  return sorted[Math.floor(sorted.length / 2)];
}

/** Same slot pattern in every band, relative to each band's own box. */
function bandsAreCopies(slots: FrameRect[], bands: number[][]) {
  if (bands.some((band) => band.length !== bands[0].length)) return false;
  const shapes = bands.map((band) => {
    const ordered = readingOrder(slots, band);
    const minX = Math.min(...band.map((i) => slots[i].x));
    const minY = Math.min(...band.map((i) => slots[i].y));
    return ordered.map((i) => [slots[i].x - minX, slots[i].y - minY, slots[i].width, slots[i].height]);
  });
  return shapes.every((shape) => shape.every((rect, i) => rect.every((value, k) => Math.abs(value - shapes[0][i][k]) <= COPY_TOLERANCE)));
}

/** Every gutter that splits these slots in two, widest first. Sizes are in frame heights. */
function cutsOf(slots: FrameRect[], indexes: number[], ratio: number): Candidate[] {
  const result: Candidate[] = [];
  for (const axis of ["x", "y"] as const) {
    const across: Axis = axis === "x" ? "y" : "x";
    const cross: [number, number] = [
      Math.min(...indexes.map((i) => startOf(slots[i], across))),
      Math.max(...indexes.map((i) => endOf(slots[i], across))),
    ];
    const bands = splitBands(slots, axis, indexes);
    for (let i = 1; i < bands.length; i++) {
      const from = Math.max(...bands.slice(0, i).map((band) => band.end));
      const to = bands[i].start;
      if (to <= from) continue;
      result.push({
        axis,
        from,
        to,
        cross,
        size: (to - from) * (axis === "x" ? ratio : 1),
        before: bands.slice(0, i).flatMap((band) => band.slots),
        after: bands.slice(i).flatMap((band) => band.slots),
      });
    }
  }
  return result.sort((a, b) => b.size - a.size);
}

/** Cut the frame along its widest allowed gutter, again and again, until no cut is allowed. */
function guillotine(slots: FrameRect[], ratio: number, indexes: number[], region: FrameRect, allow: (cut: Candidate) => boolean): SlotGroup[] {
  if (indexes.length > 1) {
    for (const cut of cutsOf(slots, indexes, ratio)) {
      if (!allow(cut)) continue;
      const mid = (cut.from + cut.to) / 2;
      const [first, second] = cut.axis === "x"
        ? [{ ...region, width: mid - region.x }, { ...region, x: mid, width: region.x + region.width - mid }]
        : [{ ...region, height: mid - region.y }, { ...region, y: mid, height: region.y + region.height - mid }];
      return [
        ...guillotine(slots, ratio, cut.before, first, allow),
        ...guillotine(slots, ratio, cut.after, second, allow),
      ];
    }
  }
  return [{ slots: readingOrder(slots, indexes), region }];
}

/**
 * When to cut, for a frame nobody grouped yet. Narrow gutters (bars inside a grid,
 * spacing inside a strip) never split; wide ones always do. In between, a gutter
 * splits when both sides are the same layout set further apart than their own
 * slots (strips side by side), or when the frame picture shows a card edge along it.
 * This is only a first guess: the admin corrects the groups before guests see them.
 */
function autoRule(slots: FrameRect[], ratio: number, probe?: GutterProbe) {
  const typical = median(slots.map((slot) => Math.min(slot.width * ratio, slot.height)));
  const widestInside = (indexes: number[]) => cutsOf(slots, indexes, ratio)[0]?.size ?? 0;
  return (cut: Candidate) => {
    if (cut.size < MIN_GUTTER * typical) return false;
    if (cut.size >= WIDE_GUTTER * typical) return true;
    if (cut.before.length > 1
      && bandsAreCopies(slots, [cut.before, cut.after])
      && cut.size >= COPY_GAP_RATIO * Math.max(widestInside(cut.before), widestInside(cut.after))) return true;
    return probe ? probe(cut) : false;
  };
}

/**
 * The groups of a frame: the cards, strips or blocks the slots are laid out in.
 * Frames saved by the admin carry a `group` on every slot and are split exactly along
 * those; older frames are worked out from the slot layout alone. Each group owns the
 * rectangle of the frame it was cut out as, decoration included.
 */
export function frameGroups(slots: GroupedRect[], frameRatio: number, probe?: GutterProbe): FrameGroups {
  const all = slots.map((_, i) => i);
  if (slots.length === 0) return { groups: [{ slots: [], region: FULL_FRAME }], copies: false };
  const stored = slots.every((slot) => Number.isInteger(slot.group));
  const allow = stored
    ? (cut: Candidate) => {
        const before = new Set(cut.before.map((i) => slots[i].group));
        return cut.after.every((i) => !before.has(slots[i].group));
      }
    : autoRule(slots, frameRatio, probe);
  let groups = guillotine(slots, frameRatio, all, FULL_FRAME, allow);

  // Stored groups that no straight cut can separate: fall back to each group's own box.
  if (stored && groups.some((group) => new Set(group.slots.map((i) => slots[i].group)).size > 1)) {
    const ids = [...new Set(readingOrder(slots, all).map((i) => slots[i].group))];
    groups = ids.map((id) => {
      const members = all.filter((i) => slots[i].group === id);
      const x = Math.min(...members.map((i) => slots[i].x));
      const y = Math.min(...members.map((i) => slots[i].y));
      const right = Math.max(...members.map((i) => slots[i].x + slots[i].width));
      const bottom = Math.max(...members.map((i) => slots[i].y + slots[i].height));
      return { slots: readingOrder(slots, members), region: { x, y, width: right - x, height: bottom - y } };
    });
  }
  // Keep the admin's numbering, so "Nhóm 3" means the same card for staff and guests.
  if (stored) groups.sort((a, b) => (slots[a.slots[0]].group ?? 0) - (slots[b.slots[0]].group ?? 0));
  return { groups, copies: groups.length > 1 && bandsAreCopies(slots, groups.map((group) => group.slots)) };
}

/** Slots with their `group` filled in, ready to store with the frame. */
export function withGroups<T extends FrameRect>(slots: T[], frameRatio: number, probe?: GutterProbe): Array<T & { group: number }> {
  const { groups } = frameGroups(slots.map(({ x, y, width, height }) => ({ x, y, width, height })), frameRatio, probe);
  const groupOf = new Map<number, number>();
  groups.forEach((group, g) => group.slots.forEach((slot) => groupOf.set(slot, g)));
  return slots.map((slot, i) => ({ ...slot, group: groupOf.get(i) ?? 0 }));
}

/**
 * Reads the frame picture (RGBA, any scale): a gutter is a card boundary when nearly
 * every line across it meets a sharp light/dark step, i.e. a card edge runs along it.
 * Text or a logo inside one card leaves gaps between letters and does not count.
 */
export function gutterProbe(pixels: Uint8ClampedArray | Uint8Array, width: number, height: number): GutterProbe {
  const coverage = gutterCoverage(pixels, width, height);
  return (cut) => coverage(cut) >= EDGE_COVERAGE;
}

/** Share (0–1) of the lines across a gutter that meet a sharp step in the frame picture. */
export function gutterCoverage(pixels: Uint8ClampedArray | Uint8Array, width: number, height: number) {
  const lum = (x: number, y: number) => {
    const i = (y * width + x) * 4;
    const alpha = pixels[i + 3] / 255;
    // Transparent pixels read as white paper.
    return (0.299 * pixels[i] + 0.587 * pixels[i + 1] + 0.114 * pixels[i + 2]) * alpha + 255 * (1 - alpha);
  };
  return (cut: FrameCut) => {
    const vertical = cut.axis === "x";
    const size = vertical ? width : height;
    const crossSize = vertical ? height : width;
    // Stay off the slot edges themselves: they are always sharp.
    const inset = Math.max(3, Math.round((cut.to - cut.from) * size * 0.08));
    const from = Math.round(cut.from * size) + inset;
    const to = Math.round(cut.to * size) - inset;
    const c0 = Math.max(0, Math.round(cut.cross[0] * crossSize));
    const c1 = Math.min(crossSize - 1, Math.round(cut.cross[1] * crossSize));
    if (to - from < 3 || c1 <= c0) return 0;
    let lines = 0;
    let hits = 0;
    for (let c = c0; c <= c1; c++) {
      lines++;
      for (let p = from; p + 2 <= to; p++) {
        const step = vertical ? lum(p + 2, c) - lum(p, c) : lum(c, p + 2) - lum(c, p);
        if (Math.abs(step) > EDGE_STEP) { hits++; break; }
      }
    }
    return lines > 0 ? hits / lines : 0;
  };
}

/**
 * Which photo goes in which slot when the editor opens: group by group in reading order.
 * When the groups are copies, a slot left empty takes the photo from the same spot in
 * the first group, so a guest who picks one strip's worth gets every strip filled,
 * like the booth's cut prints.
 */
export function initialSlotAssets<T>(slotCount: number, layout: FrameGroups, picks: T[]): Array<T | null> {
  const result: Array<T | null> = Array.from({ length: slotCount }, () => null);
  let next = 0;
  for (const group of layout.groups) {
    group.slots.forEach((slot, p) => {
      result[slot] = picks[next + p] ?? null;
    });
    next += group.slots.length;
  }
  if (layout.copies) {
    const first = layout.groups[0].slots;
    for (const group of layout.groups.slice(1)) {
      group.slots.forEach((slot, p) => {
        if (result[slot] === null) result[slot] = result[first[p]];
      });
    }
  }
  return result;
}

let canvasFilterSupport: boolean | null = null;

function supportsCanvasFilter() {
  if (canvasFilterSupport !== null) return canvasFilterSupport;
  const ctx = document.createElement("canvas").getContext("2d");
  if (!ctx || !("filter" in ctx)) return (canvasFilterSupport = false);
  ctx.filter = "blur(2px)";
  return (canvasFilterSupport = ctx.filter === "blur(2px)");
}

function makeCanvas(width: number, height: number) {
  const canvas = document.createElement("canvas");
  canvas.width = Math.max(1, Math.round(width));
  canvas.height = Math.max(1, Math.round(height));
  const ctx = canvas.getContext("2d");
  if (!ctx) throw new Error("Trình duyệt không hỗ trợ tạo ảnh in");
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";
  return { canvas, ctx };
}

/** Blurred, slightly enlarged cover copy of the photo that fills the slot behind it. */
function drawBlurredFill(ctx: CanvasRenderingContext2D, image: DrawSource, x: number, y: number, w: number, h: number, layout: SlotLayout) {
  const dims = sourceDims(image);
  const imageAspect = dims.width / dims.height;
  const radius = Math.max(4, SOFT_EDGE * Math.min(w, h));
  // Cover a box that overhangs the slot by FILL_BLEED radii (turned with the photo), so
  // the blur's own fade-out lands outside the clip and the slot stays fully opaque.
  const box = fillBox(w, h, layout.rotate, FILL_BLEED * radius);
  const wide = imageAspect > box.width / box.height;
  const dw = wide ? box.height * imageAspect : box.width;
  const dh = wide ? box.height : box.width / imageAspect;

  ctx.save();
  ctx.translate(x + w / 2, y + h / 2);
  ctx.rotate((layout.rotate * Math.PI) / 180);
  if (layout.flip) ctx.scale(-1, 1);
  if (supportsCanvasFilter()) {
    ctx.filter = `blur(${radius.toFixed(1)}px)`;
    ctx.drawImage(image, -dw / 2, -dh / 2, dw, dh);
  } else {
    // Safari fallback: shrink hard, then scale back up in two passes for a smooth blur.
    const factor = Math.max(2, radius / 1.5);
    const tiny = makeCanvas(dw / factor, dh / factor);
    tiny.ctx.drawImage(image, 0, 0, tiny.canvas.width, tiny.canvas.height);
    const mid = makeCanvas(tiny.canvas.width * 4, tiny.canvas.height * 4);
    mid.ctx.drawImage(tiny.canvas, 0, 0, mid.canvas.width, mid.canvas.height);
    ctx.drawImage(mid.canvas, -dw / 2, -dh / 2, dw, dh);
  }
  ctx.restore();
}

/** Draw one photo into its slot rectangle (in output pixels). */
export function drawSlot(
  ctx: CanvasRenderingContext2D,
  image: DrawSource,
  rect: { x: number; y: number; width: number; height: number },
  transform: SlotTransform,
) {
  const { x, y, width: w, height: h } = rect;
  const dims = sourceDims(image);
  const imageAspect = dims.width / dims.height;
  const layout = slotLayout(w / h, imageAspect, clampTransform(transform, w / h, imageAspect));
  const dw = layout.width * w;
  const dh = layout.height * h;
  const cx = x + (layout.left + layout.width / 2) * w;
  const cy = y + (layout.top + layout.height / 2) * h;

  ctx.save();
  ctx.beginPath();
  ctx.rect(x, y, w, h);
  ctx.clip();
  ctx.imageSmoothingEnabled = true;
  ctx.imageSmoothingQuality = "high";

  if (layout.needsFill) drawBlurredFill(ctx, image, x, y, w, h, layout);

  // Turn and mirror about the photo centre, in the same order as photoTransform() on screen.
  ctx.translate(cx, cy);
  ctx.rotate((layout.rotate * Math.PI) / 180);
  if (layout.flip) ctx.scale(-1, 1);

  if (layout.featherX > 0 || layout.featherY > 0) {
    const sprite = makeCanvas(dw, dh);
    const sw = sprite.canvas.width;
    const sh = sprite.canvas.height;
    sprite.ctx.drawImage(image, 0, 0, sw, sh);
    sprite.ctx.globalCompositeOperation = "destination-in";
    if (layout.featherX > 0) {
      const g = sprite.ctx.createLinearGradient(0, 0, sw, 0);
      g.addColorStop(0, "rgba(0,0,0,0)");
      g.addColorStop(layout.featherX, "rgba(0,0,0,1)");
      g.addColorStop(1 - layout.featherX, "rgba(0,0,0,1)");
      g.addColorStop(1, "rgba(0,0,0,0)");
      sprite.ctx.fillStyle = g;
      sprite.ctx.fillRect(0, 0, sw, sh);
    }
    if (layout.featherY > 0) {
      const g = sprite.ctx.createLinearGradient(0, 0, 0, sh);
      g.addColorStop(0, "rgba(0,0,0,0)");
      g.addColorStop(layout.featherY, "rgba(0,0,0,1)");
      g.addColorStop(1 - layout.featherY, "rgba(0,0,0,1)");
      g.addColorStop(1, "rgba(0,0,0,0)");
      sprite.ctx.fillStyle = g;
      sprite.ctx.fillRect(0, 0, sw, sh);
    }
    ctx.drawImage(sprite.canvas, -dw / 2, -dh / 2, dw, dh);
  } else {
    ctx.drawImage(image, -dw / 2, -dh / 2, dw, dh);
  }
  ctx.restore();
}
