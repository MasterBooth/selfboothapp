"use client";

import { Check, Pencil, X } from "lucide-react";
import { useEffect, useRef, useState } from "react";
import type { FormEvent, KeyboardEvent } from "react";
import { type ApiError, adminApi } from "./api";

export type Machine = {
  id: string;
  device_name: string;
  /** Name the studio gave the machine here; never overwritten by the app. */
  display_name?: string;
  app_version: string;
  status: string;
  first_seen_at: string;
  last_seen_at: string;
  linked_at: string | null;
};

/** The studio's name for the machine, else the name in the app's config. Never the hardware id. */
export function machineName(machine: Pick<Machine, "display_name" | "device_name">) {
  return machine.display_name?.trim() || machine.device_name?.trim() || "Máy chưa đặt tên";
}

function machineState(machine: Machine) {
  if (machine.status === "disabled") return { label: "Đã khóa", tone: "disabled", detail: "Thiết bị đang bị vô hiệu hóa" };
  const seen = Date.parse(machine.last_seen_at);
  if (!Number.isNaN(seen)) {
    const minutes = (Date.now() - seen) / 60000;
    if (minutes <= 10) return { label: "Online", tone: "online", detail: "Đang kết nối" };
    if (minutes <= 24 * 60) return { label: "Tạm vắng", tone: "idle", detail: "Chưa kết nối lại trong 10 phút qua" };
  }
  return { label: "Offline", tone: "offline", detail: "Mở app trên máy để kết nối lại" };
}

function when(value: string | null) {
  if (!value) return "—";
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? "—"
    : date.toLocaleString("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit", year: "numeric" });
}

/** One linked machine: status, app version, last contact, and an in-place rename. */
export function DeviceCard({ machine, onRenamed }: { machine: Machine; onRenamed: (machine: Machine) => void }) {
  const [editing, setEditing] = useState(false);
  const [name, setName] = useState("");
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const input = useRef<HTMLInputElement | null>(null);
  const state = machineState(machine);

  useEffect(() => {
    if (editing) input.current?.select();
  }, [editing]);

  const start = () => {
    setName(machine.display_name?.trim() || machine.device_name?.trim() || "");
    setError("");
    setEditing(true);
  };

  const save = async (event?: FormEvent) => {
    event?.preventDefault();
    setBusy(true);
    setError("");
    try {
      const data = await adminApi<{ machine: Machine }>(`/v1/web/machines/${machine.id}`, {
        method: "PATCH",
        body: JSON.stringify({ display_name: name.trim() }),
      });
      onRenamed(data.machine);
      setEditing(false);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setBusy(false);
    }
  };

  const onKey = (event: KeyboardEvent<HTMLInputElement>) => {
    if (event.key === "Escape") setEditing(false);
  };

  return (
    <article className="device-card">
      <div className="device-card-head">
        <span className={`status-pill ${state.tone}`}>{state.label}</span>
        {!editing ? (
          <button aria-label={`Đổi tên ${machineName(machine)}`} className="text-action device-rename" onClick={start} type="button">
            <Pencil size={15} />Đổi tên
          </button>
        ) : null}
      </div>

      {editing ? (
        <form className="device-name-form" onSubmit={save}>
          <input
            aria-label="Tên máy"
            maxLength={60}
            onChange={(event) => setName(event.target.value)}
            onKeyDown={onKey}
            placeholder={machine.device_name || "Tên máy chụp"}
            ref={input}
            value={name}
          />
          <button aria-label="Lưu tên" className="primary-action" disabled={busy} type="submit"><Check size={17} /></button>
          <button aria-label="Hủy" className="gallery-icon-button" onClick={() => setEditing(false)} type="button"><X size={17} /></button>
        </form>
      ) : (
        <h3 className="device-name">{machineName(machine)}</h3>
      )}
      {error ? <p className="device-error" role="alert">{error}</p> : null}

      <dl className="device-meta">
        <div><dt>Phiên bản app</dt><dd>{machine.app_version || "Chưa rõ"}</dd></div>
        <div><dt>Kết nối lần cuối</dt><dd>{when(machine.last_seen_at)}</dd></div>
        <div><dt>Liên kết từ</dt><dd>{when(machine.linked_at)}</dd></div>
      </dl>
      <p className="device-detail">{state.detail}</p>
    </article>
  );
}
