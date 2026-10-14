"use client";

import { Check, Eye, EyeOff, X } from "lucide-react";
import { useEffect, useState } from "react";
import type { FormEvent } from "react";
import { type ApiError, adminApi } from "./api";

/** Change your own password (owner or staff). Other devices signed in are signed out. */
export function PasswordDialog({ onClose }: { onClose: () => void }) {
  const [current, setCurrent] = useState("");
  const [next, setNext] = useState("");
  const [show, setShow] = useState(false);
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [done, setDone] = useState(false);

  useEffect(() => {
    const onKey = (event: KeyboardEvent) => { if (event.key === "Escape") onClose(); };
    window.addEventListener("keydown", onKey);
    return () => window.removeEventListener("keydown", onKey);
  }, [onClose]);

  const submit = async (event: FormEvent) => {
    event.preventDefault();
    setBusy(true);
    setError("");
    try {
      await adminApi("/v1/web/auth/password", { method: "POST", body: JSON.stringify({ current, next }) });
      setDone(true);
      window.setTimeout(onClose, 1200);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setBusy(false);
    }
  };

  return (
    <div className="gallery-modal" onClick={(event) => { if (event.target === event.currentTarget) onClose(); }}>
      <form aria-labelledby="password-title" aria-modal="true" className="gallery-modal-panel password-dialog" onSubmit={submit} role="dialog">
        <header className="group-modal-head">
          <h2 id="password-title">Đổi mật khẩu</h2>
          <button aria-label="Đóng" autoFocus className="gallery-icon-button" onClick={onClose} type="button"><X size={18} /></button>
        </header>
        <label>
          Mật khẩu hiện tại
          <input autoComplete="current-password" onChange={(event) => setCurrent(event.target.value)} required type={show ? "text" : "password"} value={current} />
        </label>
        <label>
          Mật khẩu mới
          <span className="password-field">
            <input autoComplete="new-password" minLength={8} onChange={(event) => setNext(event.target.value)} placeholder="Tối thiểu 8 ký tự" required type={show ? "text" : "password"} value={next} />
            <button aria-label={show ? "Ẩn mật khẩu" : "Hiện mật khẩu"} aria-pressed={show} onClick={() => setShow((value) => !value)} type="button">
              {show ? <EyeOff size={18} /> : <Eye size={18} />}
            </button>
          </span>
        </label>
        <p className="form-message" role="status" aria-live="polite">{error || (done ? "Đã đổi mật khẩu." : "")}</p>
        <div className="booking-dialog-actions">
          <button className="text-action" onClick={onClose} type="button">Để sau</button>
          <button className="primary-action" disabled={busy || done} type="submit"><Check size={17} />{busy ? "Đang lưu…" : "Lưu mật khẩu"}</button>
        </div>
      </form>
    </div>
  );
}
