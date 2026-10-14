"use client";

/**
 * Cloudflare Turnstile on the admin / staff sign-in forms. The site key comes from the API
 * (`/v1/public/auth-config`); while the studio has not set Turnstile up the key is empty and
 * nothing renders, so sign-in keeps working. The box is always shown; in Managed mode Cloudflare
 * ticks it by itself for low-risk visitors and asks the rest to click.
 */

import { useEffect, useRef, useState } from "react";

type TurnstileApi = {
  render: (el: HTMLElement, options: Record<string, unknown>) => string;
  reset: (widgetId: string) => void;
  remove: (widgetId: string) => void;
};

declare global {
  interface Window { turnstile?: TurnstileApi }
}

const SCRIPT_URL = "https://challenges.cloudflare.com/turnstile/v0/api.js?render=explicit";

let configJob: Promise<string> | null = null;
let scriptJob: Promise<TurnstileApi> | null = null;

/** The site key, read once per page and only once `enabled`; "" = Turnstile not configured. */
export function useTurnstileSiteKey(enabled: boolean) {
  const [siteKey, setSiteKey] = useState<string | null>(null);
  useEffect(() => {
    if (!enabled) return;
    configJob ??= fetch("/v1/public/auth-config")
      .then((response) => response.json())
      .then((data) => String(data.turnstile_site_key || ""))
      .catch(() => "");
    let live = true;
    void configJob.then((key) => { if (live) setSiteKey(key); });
    return () => { live = false; };
  }, [enabled]);
  return siteKey;
}

function loadScript(): Promise<TurnstileApi> {
  scriptJob ??= new Promise((resolve, reject) => {
    if (window.turnstile) {
      resolve(window.turnstile);
      return;
    }
    const script = document.createElement("script");
    script.src = SCRIPT_URL;
    script.async = true;
    script.defer = true;
    script.onload = () => (window.turnstile ? resolve(window.turnstile) : reject(new Error("turnstile")));
    script.onerror = () => {
      scriptJob = null;
      reject(new Error("turnstile"));
    };
    document.head.appendChild(script);
  });
  return scriptJob;
}

type Props = {
  siteKey: string;
  /** Checked by the server: a token from one form is refused by another. */
  action: "owner_login" | "staff_login";
  onToken: (token: string) => void;
  /** Bump after a failed sign-in: tokens are single-use, so the widget issues a new one. */
  resetSignal: number;
};

export function Turnstile({ siteKey, action, onToken, resetSignal }: Props) {
  const box = useRef<HTMLDivElement | null>(null);
  const widget = useRef<string | null>(null);
  const tokenSink = useRef(onToken);
  const [failed, setFailed] = useState(false);
  tokenSink.current = onToken;

  useEffect(() => {
    let cancelled = false;
    loadScript()
      .then((api) => {
        if (cancelled || !box.current) return;
        widget.current = api.render(box.current, {
          sitekey: siteKey,
          action,
          language: "vi",
          size: "flexible",
          // Luôn hiện ô xác minh (ai rủi ro thấp được Cloudflare tự tích, người khác phải bấm).
          appearance: "always",
          callback: (token: string) => { setFailed(false); tokenSink.current(token); },
          "expired-callback": () => tokenSink.current(""),
          "error-callback": () => { tokenSink.current(""); setFailed(true); },
        });
      })
      .catch(() => { if (!cancelled) setFailed(true); });
    return () => {
      cancelled = true;
      if (widget.current) window.turnstile?.remove(widget.current);
      widget.current = null;
    };
  }, [action, siteKey]);

  useEffect(() => {
    if (resetSignal === 0 || !widget.current) return;
    tokenSink.current("");
    window.turnstile?.reset(widget.current);
  }, [resetSignal]);

  return (
    <div className="turnstile-slot">
      <div ref={box} />
      {failed ? <p className="turnstile-error" role="alert">Chưa xác minh được. Tải lại trang hoặc kiểm tra kết nối mạng.</p> : null}
    </div>
  );
}
