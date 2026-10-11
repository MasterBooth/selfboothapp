"use client";

/**
 * Studio branding on the web: name, logo and three colours (background, text, buttons).
 * The design system's tokens (tokens.css) are overridden at the root, and the in-between
 * shades (cards, rules, muted text) are mixed from those three, so every page follows
 * without per-page colour code. Empty colours keep the built-in Studio theme.
 */

import { useEffect, useState } from "react";
import type { CSSProperties } from "react";

export type Branding = { name: string; logo_url: string; bg: string; text: string; accent: string };

export const EMPTY_BRANDING: Branding = { name: "", logo_url: "", bg: "", text: "", accent: "" };

/** The built-in theme in hex, as starting values for colour pickers. */
export const THEME_COLORS = { bg: "#f7efe4", text: "#24170f", accent: "#6e3b1c" };

const TOKENS = [
  "--color-paper", "--color-paper-2", "--color-paper-3", "--color-surface", "--color-nav",
  "--color-rule", "--color-rule-strong", "--color-ink", "--color-muted", "--color-neutral",
  "--color-accent", "--color-accent-ink", "--color-focus",
  "--color-success", "--color-success-soft", "--color-error", "--color-price",
];

/** Dark backgrounds also switch native controls (date / time pickers, scrollbars) to dark. */
function scheme(branding: Pick<Branding, "bg">): "light" | "dark" {
  return isHex(branding.bg) && luminance(branding.bg) <= 0.4 ? "dark" : "light";
}

function rgb(hex: string) {
  const n = parseInt(hex.slice(1), 16);
  return [(n >> 16) & 255, (n >> 8) & 255, n & 255];
}

/** WCAG relative luminance (0 black … 1 white). */
export function luminance(hex: string) {
  const [r, g, b] = rgb(hex).map((v) => {
    const c = v / 255;
    return c <= 0.03928 ? c / 12.92 : ((c + 0.055) / 1.055) ** 2.4;
  });
  return 0.2126 * r + 0.7152 * g + 0.0722 * b;
}

/** WCAG contrast ratio between two hex colours (1 … 21). */
export function contrast(a: string, b: string) {
  const [hi, lo] = [luminance(a), luminance(b)].sort((x, y) => y - x);
  return (hi + 0.05) / (lo + 0.05);
}

const isHex = (v: string) => /^#[0-9a-f]{6}$/i.test(v);

/** Token overrides for a branding (only for the colours that are set). */
export function brandVars(branding: Pick<Branding, "bg" | "text" | "accent">): Record<string, string> {
  const vars: Record<string, string> = {};
  const bg = isHex(branding.bg) ? branding.bg : "";
  const text = isHex(branding.text) ? branding.text : "";
  const accent = isHex(branding.accent) ? branding.accent : "";
  const paper = bg || "var(--color-paper)";
  const ink = text || "var(--color-ink)";
  if (bg || text) {
    const lightPaper = bg ? luminance(bg) > 0.4 : true;
    const surface = lightPaper ? `color-mix(in oklch, ${paper} 55%, white)` : `color-mix(in oklch, ${paper} 88%, ${ink})`;
    Object.assign(vars, {
      "--color-paper": paper,
      "--color-paper-2": `color-mix(in oklch, ${paper} 93%, ${ink})`,
      "--color-paper-3": `color-mix(in oklch, ${paper} 86%, ${ink})`,
      "--color-surface": surface,
      "--color-nav": `color-mix(in oklch, ${surface} 86%, transparent)`,
      "--color-rule": `color-mix(in oklch, ${paper} 72%, ${ink})`,
      "--color-rule-strong": `color-mix(in oklch, ${paper} 52%, ${ink})`,
      "--color-ink": ink,
      "--color-muted": `color-mix(in oklch, ${ink} 82%, ${paper})`,
      "--color-neutral": `color-mix(in oklch, ${ink} 64%, ${paper})`,
    });
    // Status colours are dark shades made for light paper: lift them on a dark background.
    if (!lightPaper) {
      Object.assign(vars, {
        "--color-success": "oklch(80% 0.13 145)",
        "--color-success-soft": `color-mix(in oklch, oklch(80% 0.13 145) 18%, ${paper})`,
        "--color-error": "oklch(74% 0.15 25)",
        "--color-price": "oklch(82% 0.12 80)",
      });
    }
  }
  if (accent) {
    Object.assign(vars, {
      "--color-accent": accent,
      // Button text: dark on light buttons, light on dark ones.
      "--color-accent-ink": luminance(accent) > 0.45 ? "#1b1410" : "#fffaf3",
      "--color-focus": `color-mix(in oklch, ${accent} 75%, oklch(70% 0.17 70))`,
    });
  }
  return vars;
}

/** Inline style for a preview box: the same overrides, scoped to that element. */
export function brandStyle(branding: Pick<Branding, "bg" | "text" | "accent">): CSSProperties {
  return { ...brandVars(branding), colorScheme: scheme(branding) } as CSSProperties;
}

/** Apply (or clear) the branding on the whole page. */
export function applyBranding(branding: Branding | null) {
  const root = document.documentElement;
  TOKENS.forEach((token) => root.style.removeProperty(token));
  root.style.removeProperty("color-scheme");
  if (!branding) {
    delete root.dataset.brand;
    return;
  }
  Object.entries(brandVars(branding)).forEach(([token, value]) => root.style.setProperty(token, value));
  root.style.setProperty("color-scheme", scheme(branding));
  root.dataset.brand = "on";
}

const CACHE_KEY = "selfbooth.brand";
const fetches = new Map<string, Promise<Branding | null>>();

function cached(): { token: string; branding: Branding } | null {
  try {
    return JSON.parse(sessionStorage.getItem(CACHE_KEY) || "null");
  } catch {
    return null;
  }
}

/**
 * Branding for the guest pages. Applies the last known branding at once (no flash
 * between steps; the editor has no token in its URL), then refreshes it from the
 * gallery token once per page load.
 */
export function useGuestBranding(token?: string | null): Branding | null {
  const [branding, setBranding] = useState<Branding | null>(null);

  useEffect(() => {
    const last = cached();
    if (last && (!token || last.token === token)) {
      setBranding(last.branding);
      applyBranding(last.branding);
    }
    if (!token) return;
    let live = true;
    let job = fetches.get(token);
    if (!job) {
      job = fetch(`/v1/public/gallery/${encodeURIComponent(token)}/branding`, { cache: "no-store" })
        .then((response) => (response.ok ? response.json() : null))
        .then((data) => (data?.branding as Branding) ?? null)
        .catch(() => null);
      fetches.set(token, job);
    }
    void job.then((next) => {
      if (!live || !next) return;
      setBranding(next);
      applyBranding(next);
      try {
        sessionStorage.setItem(CACHE_KEY, JSON.stringify({ token, branding: next }));
      } catch {
        // Private mode: fine, it is fetched again next page.
      }
    });
    return () => { live = false; };
  }, [token]);

  return branding;
}

/** Just the logo (or the name's first letter when there is no logo). */
export function BrandLogo({ branding, name, className = "" }: { branding: Branding | null; name: string; className?: string }) {
  return (
    <span className={`brand-mark-logo ${className}`}>
      {branding?.logo_url ? <img alt={`Logo ${name}`} src={branding.logo_url} /> : <b aria-hidden="true">{name.trim().charAt(0).toUpperCase() || "B"}</b>}
    </span>
  );
}

/** Logo (or the name's first letter when there is no logo) and the brand name. */
export function BrandMark({ branding, fallbackName = "BOOTHME", size = "md" }: { branding: Branding | null; fallbackName?: string; size?: "sm" | "md" | "lg" }) {
  const name = branding?.name || fallbackName;
  return (
    <span className={`brand-mark brand-mark-${size}`}>
      <span className="brand-mark-logo" aria-hidden={Boolean(branding?.logo_url) ? undefined : true}>
        {branding?.logo_url ? <img alt={`Logo ${name}`} src={branding.logo_url} /> : <b>{name.trim().charAt(0).toUpperCase() || "B"}</b>}
      </span>
      <span className="brand-mark-name">{name}</span>
    </span>
  );
}
