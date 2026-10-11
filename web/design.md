# Design - Vibe Studio Selfbooth

Locked design system. Future Hallmark runs read this file first; pages defer
to it. Amend intentionally - the file is the rule.

## System
- Genre · editorial
- Macrostructure · Workbench
- Theme · Studio soft editorial
- Axes · light paper / serif display / warm cocoa accent
- Nav · N5 Floating pill
- Footer · Ft5 Statement

## Tokens (canonical · `tokens.css` is the source of truth)
```css
:root {
  --color-paper: oklch(96.5% 0.018 76);
  --color-paper-2: oklch(93.5% 0.022 76);
  --color-paper-3: oklch(89% 0.026 76);
  --color-surface: oklch(98% 0.012 76);
  --color-rule: oklch(78% 0.026 74);
  --color-rule-strong: oklch(65% 0.035 70);
  --color-neutral: oklch(45% 0.035 62);
  --color-muted: oklch(35% 0.035 58);
  --color-ink: oklch(20% 0.035 54);
  --color-accent: oklch(39% 0.09 48);
  --color-accent-ink: oklch(98% 0.012 76);
  --color-focus: oklch(50% 0.16 55);
  --color-price: oklch(48% 0.1 78);
  --color-success: oklch(43% 0.08 135);
  --color-error: oklch(48% 0.16 28);

  --font-display: "Fraunces", ui-serif, Georgia, serif;
  --font-body: "IBM Plex Sans", ui-sans-serif, system-ui, sans-serif;

  /* 4-pt spacing scale: --space-3xs through --space-3xl. See tokens.css. */
  /* Type scale: --text-xs through --text-display. See tokens.css. */

  --ease-out: cubic-bezier(0.16, 1, 0.3, 1);
  --ease-in: cubic-bezier(0.7, 0, 0.84, 0);
  --ease-in-out: cubic-bezier(0.65, 0, 0.35, 1);
  --dur-micro: 120ms;
  --dur-short: 220ms;
  --dur-long: 420ms;

  --radius-sm: 0.75rem;
  --radius-md: 1rem;
  --radius-lg: 1.5rem;
  --radius-xl: 2rem;
  --radius-pill: 999rem;
}
```

## CTA Voice
- Primary · cocoa fill, cream text, pill radius, 48px minimum height.
- Secondary · typographic underline link, no box fill, same single-line affordance rule.
- Labels · concrete verbs: "Đặt lịch", "Lưu khách", "Xác nhận lịch".

## Motion Stance
- Motion-cut with two primitives only: page reveal and CTA hover lift.
- Animate transform and opacity only.
- Reduced-motion fallback · <=150ms opacity crossfade.

## Component Voice
- Booking surfaces are workbench panels, not marketing cards.
- Keep the receipt visible near choices; totals update silently.
- Photos are placeholders until replaced by real booth assets. Never present stock imagery as final studio proof.
- Headings stay roman; no italic display emphasis.
- Interactive text never wraps on mobile.

## Exports
`tokens.css` is the source of truth in this project. For Tailwind v4 `@theme`,
DTCG `tokens.json`, or shadcn/ui CSS variables, ask to extend `design.md` with
that export format.
