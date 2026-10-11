"use client";

import {
  CalendarDays, Check, ChevronLeft, ChevronRight, Copy, Download, ExternalLink, Pencil, Phone, Plus, QrCode, X,
} from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { FormEvent } from "react";
import { type ApiError, addDays, adminApi, clock, dayLabel, minutesOf, money } from "./api";
import { downloadQr, qrPath } from "./qr";

type Room = { id: string; name: string; status: string };
type PhotoPackage = { id: string; room_id: string; name: string; minutes: number; price_vnd: number; status: string };

type Status = "pending" | "confirmed" | "done" | "cancelled";

type Booking = {
  id: string;
  code: string;
  room_id: string;
  package_id: string | null;
  booking_date: string;
  start_minute: number;
  end_minute: number;
  customer_name: string;
  customer_phone: string;
  note: string;
  price_vnd: number;
  status: Status;
  source: "web" | "admin";
  room_name: string | null;
  package_name: string | null;
  /** 4-digit code issued when staff confirm; the guest types it at the booth. */
  play_code?: string | null;
  play_code_status?: "active" | "used" | "revoked" | null;
  customer_id?: string | null;
};

type Settings = { enabled: boolean; open_minute: number; close_minute: number; slot_minutes: number; days_ahead: number; notice: string };

type Draft = { id?: string; name: string; phone: string; date: string; start: string; room_id: string; package_id: string; status: Status; note: string };

const STATUS: Record<Status, { label: string; tone: string }> = {
  pending: { label: "Chờ xác nhận", tone: "warn" },
  confirmed: { label: "Đã xác nhận", tone: "ok" },
  done: { label: "Đã chụp", tone: "neutral" },
  cancelled: { label: "Đã hủy", tone: "error" },
};

const STATUS_ORDER: Status[] = ["pending", "confirmed", "done", "cancelled"];

type Props = { rooms: Room[]; packages: PhotoPackage[]; brandName: string };

export function BookingsPanel({ rooms, packages, brandName }: Props) {
  const [tab, setTab] = useState<"list" | "settings">("list");
  const [weekStart, setWeekStart] = useState("");
  const [day, setDay] = useState("");
  const [today, setToday] = useState("");
  const [filter, setFilter] = useState<Status | "all">("all");
  const [bookings, setBookings] = useState<Booking[]>([]);
  const [pending, setPending] = useState(0);
  const [loading, setLoading] = useState(false);
  const [error, setError] = useState("");
  const [draft, setDraft] = useState<Draft | null>(null);
  const [draftError, setDraftError] = useState("");
  const [saving, setSaving] = useState(false);
  const [settings, setSettings] = useState<Settings | null>(null);
  const [studioId, setStudioId] = useState("");
  const [settingsNote, setSettingsNote] = useState("");
  const [copied, setCopied] = useState(false);

  const activeRooms = useMemo(() => rooms.filter((room) => room.status === "active"), [rooms]);
  const activePackages = useMemo(() => packages.filter((pkg) => pkg.status === "active"), [packages]);

  const load = useCallback(async (from?: string) => {
    setLoading(true);
    setError("");
    try {
      const query = from ? `?from=${from}&to=${addDays(from, 6)}` : "";
      const data = await adminApi<{ from: string; today: string; pending: number; bookings: Booking[] }>(`/v1/web/bookings${query}`);
      setBookings(data.bookings);
      setPending(data.pending);
      setToday(data.today);
      setWeekStart(data.from);
      setDay((current) => (current && current >= data.from && current <= addDays(data.from, 6) ? current : data.from));
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => {
    void load();
    adminApi<{ studio_id: string; settings: Settings }>("/v1/web/booking-settings")
      .then((data) => { setSettings(data.settings); setStudioId(data.studio_id); })
      .catch((err) => setError((err as ApiError).message));
  }, [load]);

  const week = useMemo(() => (weekStart ? Array.from({ length: 7 }, (_, i) => addDays(weekStart, i)) : []), [weekStart]);
  const dayBookings = useMemo(
    () => bookings.filter((b) => b.booking_date === day && (filter === "all" || b.status === filter)),
    [bookings, day, filter],
  );
  const bookingUrl = typeof window !== "undefined" && studioId ? `${window.location.origin}/booking?studio_id=${encodeURIComponent(studioId)}` : "";
  const qr = useMemo(() => (bookingUrl ? qrPath(bookingUrl) : null), [bookingUrl]);

  const setStatus = async (booking: Booking, status: Status) => {
    setError("");
    try {
      const data = await adminApi<{ booking: Booking }>(`/v1/web/bookings/${booking.id}`, { method: "PATCH", body: JSON.stringify({ status }) });
      setBookings((current) => current.map((b) => (b.id === booking.id ? data.booking : b)));
      if (booking.status === "pending" || status === "pending") void load(weekStart);
    } catch (err) {
      setError((err as ApiError).message);
    }
  };

  const openDraft = (booking?: Booking) => {
    setDraftError("");
    if (booking) {
      setDraft({
        id: booking.id, name: booking.customer_name, phone: booking.customer_phone, date: booking.booking_date,
        start: clock(booking.start_minute), room_id: booking.room_id, package_id: booking.package_id || "",
        status: booking.status, note: booking.note,
      });
      return;
    }
    const room = activeRooms[0];
    setDraft({
      name: "", phone: "", date: day || today, start: clock(settings?.open_minute ?? 540), room_id: room?.id || "",
      package_id: activePackages.find((pkg) => pkg.room_id === room?.id)?.id || "", status: "confirmed", note: "",
    });
  };

  const saveDraft = async (event: FormEvent) => {
    event.preventDefault();
    if (!draft) return;
    const start = minutesOf(draft.start);
    if (!Number.isFinite(start)) {
      setDraftError("Giờ không hợp lệ.");
      return;
    }
    setSaving(true);
    setDraftError("");
    const body = JSON.stringify({
      name: draft.name, phone: draft.phone, date: draft.date, start_minute: start, room_id: draft.room_id,
      package_id: draft.package_id, status: draft.status, note: draft.note,
    });
    try {
      if (draft.id) await adminApi(`/v1/web/bookings/${draft.id}`, { method: "PATCH", body });
      else await adminApi("/v1/web/bookings", { method: "POST", body });
      setDraft(null);
      setDay(draft.date);
      const from = draft.date < weekStart || draft.date > addDays(weekStart, 6) ? draft.date : weekStart;
      await load(from);
    } catch (err) {
      setDraftError((err as ApiError).message);
    } finally {
      setSaving(false);
    }
  };

  const saveSettings = async (event: FormEvent<HTMLFormElement>) => {
    event.preventDefault();
    const form = new FormData(event.currentTarget);
    setSettingsNote("");
    try {
      const data = await adminApi<{ settings: Settings }>("/v1/web/booking-settings", {
        method: "PUT",
        body: JSON.stringify({
          enabled: form.get("enabled") === "on",
          open_minute: minutesOf(String(form.get("open"))),
          close_minute: minutesOf(String(form.get("close"))),
          slot_minutes: Number(form.get("slot")),
          days_ahead: Number(form.get("days")),
          notice: String(form.get("notice") || ""),
        }),
      });
      setSettings(data.settings);
      setSettingsNote("Đã lưu cài đặt đặt lịch.");
    } catch (err) {
      setSettingsNote((err as ApiError).message);
    }
  };

  const copyLink = async () => {
    try {
      await navigator.clipboard.writeText(bookingUrl);
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1500);
    } catch {
      setCopied(false);
    }
  };

  const draftPackages = draft ? activePackages.filter((pkg) => pkg.room_id === draft.room_id) : [];

  return (
    <div className="booking-admin">
      <div className="booking-tabs" role="tablist" aria-label="Đặt lịch">
        <button aria-selected={tab === "list"} className={tab === "list" ? "active" : ""} onClick={() => setTab("list")} role="tab" type="button">
          <CalendarDays size={17} />Lịch hẹn{pending > 0 ? <b>{pending}</b> : null}
        </button>
        <button aria-selected={tab === "settings"} className={tab === "settings" ? "active" : ""} onClick={() => setTab("settings")} role="tab" type="button">
          <QrCode size={17} />Cài đặt & mã QR
        </button>
      </div>

      {error ? <p className="booking-error" role="alert">{error}</p> : null}

      {tab === "list" ? (
        <>
          <div className="booking-toolbar">
            <div className="booking-week-nav">
              <button aria-label="Tuần trước" className="gallery-icon-button" disabled={loading || !weekStart} onClick={() => load(addDays(weekStart, -7))} type="button"><ChevronLeft size={18} /></button>
              <button className="text-action" disabled={loading || !today} onClick={() => { setDay(today); void load(today); }} type="button">Hôm nay</button>
              <button aria-label="Tuần sau" className="gallery-icon-button" disabled={loading || !weekStart} onClick={() => load(addDays(weekStart, 7))} type="button"><ChevronRight size={18} /></button>
            </div>
            <select aria-label="Lọc trạng thái" onChange={(event) => setFilter(event.target.value as Status | "all")} value={filter}>
              <option value="all">Tất cả trạng thái</option>
              {STATUS_ORDER.map((status) => <option key={status} value={status}>{STATUS[status].label}</option>)}
            </select>
            <button className="primary-action" disabled={activeRooms.length === 0} onClick={() => openDraft()} type="button"><Plus size={17} />Thêm lịch</button>
          </div>

          <div className="booking-week" role="tablist" aria-label="Ngày trong tuần">
            {week.map((date) => {
              const label = dayLabel(date);
              const count = bookings.filter((b) => b.booking_date === date && b.status !== "cancelled").length;
              return (
                <button
                  aria-selected={date === day}
                  className={`${date === day ? "active" : ""}${date === today ? " today" : ""}`}
                  key={date}
                  onClick={() => setDay(date)}
                  role="tab"
                  type="button"
                >
                  <small>{label.weekday}</small>
                  <strong>{label.day}</strong>
                  <span>{count > 0 ? `${count} lịch` : "—"}</span>
                </button>
              );
            })}
          </div>

          {!loading && dayBookings.length === 0 ? (
            <div className="empty-state"><CalendarDays size={28} /><strong>Không có lịch</strong><span>{day ? `${dayLabel(day).weekday} ${dayLabel(day).day}` : ""}</span></div>
          ) : null}

          <ol className="booking-list">
            {dayBookings.map((b) => (
              <li className={`booking-row is-${b.status}`} key={b.id}>
                <div className="booking-time">
                  <strong>{clock(b.start_minute)}</strong>
                  <span>{clock(b.end_minute)}</span>
                </div>
                <div className="booking-who">
                  <strong>{b.customer_name}</strong>
                  {b.customer_phone ? <a href={`tel:${b.customer_phone}`}><Phone size={14} />{b.customer_phone}</a> : null}
                  <span>{b.room_name || "Phòng đã xóa"} · {b.package_name || "Gói đã xóa"} · {money.format(b.price_vnd)}</span>
                  {b.note ? <em>{b.note}</em> : null}
                </div>
                <div className="booking-side">
                  <span className={`status-pill ${STATUS[b.status].tone}`}>{STATUS[b.status].label}</span>
                  {b.play_code && b.play_code_status !== "revoked" ? (
                    <span className={`booking-play-code${b.play_code_status === "used" ? " is-used" : ""}`} title={b.play_code_status === "used" ? "Khách đã dùng mã ở máy chụp" : "Mã khách nhập ở máy chụp"}>
                      Mã chụp <b>{b.play_code}</b>{b.play_code_status === "used" ? " · đã dùng" : ""}
                    </span>
                  ) : null}
                  <small>{b.code}{b.source === "admin" ? " · tại quầy" : b.customer_id ? " · tài khoản web" : ""}</small>
                  <div className="booking-row-actions">
                    {b.status === "pending" ? <button onClick={() => setStatus(b, "confirmed")} type="button"><Check size={15} />Xác nhận</button> : null}
                    {b.status === "confirmed" ? <button onClick={() => setStatus(b, "done")} type="button"><Check size={15} />Đã chụp</button> : null}
                    {b.status === "pending" || b.status === "confirmed" ? <button className="danger" onClick={() => setStatus(b, "cancelled")} type="button"><X size={15} />Hủy</button> : null}
                    <button onClick={() => openDraft(b)} type="button"><Pencil size={15} />Sửa</button>
                  </div>
                </div>
              </li>
            ))}
          </ol>
        </>
      ) : null}

      {tab === "settings" && settings ? (
        <div className="booking-settings">
          <form className="booking-settings-form" key={JSON.stringify(settings)} onSubmit={saveSettings}>
            <label className="booking-switch">
              <input defaultChecked={settings.enabled} name="enabled" type="checkbox" />
              <span>Nhận đặt lịch online</span>
            </label>
            <div className="booking-settings-grid">
              <label>Giờ mở cửa<input defaultValue={clock(settings.open_minute)} name="open" required type="time" /></label>
              <label>Giờ đóng cửa<input defaultValue={clock(settings.close_minute)} name="close" required type="time" /></label>
              <label>Mỗi khung giờ
                <select defaultValue={settings.slot_minutes} name="slot">
                  <option value={15}>15 phút</option>
                  <option value={30}>30 phút</option>
                  <option value={60}>60 phút</option>
                </select>
              </label>
              <label>Cho đặt trước<input defaultValue={settings.days_ahead} max={180} min={1} name="days" required type="number" /><small>ngày</small></label>
            </div>
            <label className="booking-notice">Lời nhắn trên trang đặt lịch
              <textarea defaultValue={settings.notice} maxLength={300} name="notice" placeholder="Ví dụ: Studio giữ lịch 15 phút, đến muộn hơn sẽ dời sang khung sau." rows={3} />
            </label>
            {settingsNote ? <p className="brand-message" role="status">{settingsNote}</p> : null}
            <button className="primary-action" type="submit"><Check size={17} />Lưu cài đặt</button>
          </form>

          <aside className="booking-qr">
            <span className="eyebrow">Mã QR trang đặt lịch</span>
            {qr ? (
              <svg aria-label="Mã QR trang đặt lịch" role="img" shapeRendering="crispEdges" viewBox={`0 0 ${qr.size} ${qr.size}`}>
                <rect fill="#fff" height={qr.size} width={qr.size} />
                <path d={qr.d} fill="#111" />
              </svg>
            ) : null}
            <p className="booking-qr-link">{bookingUrl}</p>
            <div className="booking-qr-actions">
              <button className="primary-action" disabled={!bookingUrl} onClick={() => downloadQr(bookingUrl, brandName, "Quét mã để đặt lịch chụp", "ma-qr-dat-lich.png")} type="button"><Download size={17} />Tải mã QR</button>
              <button className="ghost-action" disabled={!bookingUrl} onClick={copyLink} type="button"><Copy size={17} />{copied ? "Đã sao chép" : "Sao chép link"}</button>
              <a className="text-action" href={bookingUrl || undefined} rel="noreferrer" target="_blank"><ExternalLink size={16} />Mở trang đặt lịch</a>
            </div>
          </aside>
        </div>
      ) : null}

      {draft ? (
        <div className="gallery-modal" role="dialog" aria-modal="true" aria-label={draft.id ? "Sửa lịch hẹn" : "Thêm lịch hẹn"}>
          <form className="gallery-modal-panel booking-dialog" onSubmit={saveDraft}>
            <header>
              <h2>{draft.id ? "Sửa lịch hẹn" : "Thêm lịch hẹn"}</h2>
              <button aria-label="Đóng" className="gallery-icon-button" onClick={() => setDraft(null)} type="button"><X size={18} /></button>
            </header>
            <div className="booking-dialog-grid">
              <label>Tên khách<input onChange={(e) => setDraft({ ...draft, name: e.target.value })} required={Boolean(draft.id)} value={draft.name} /></label>
              <label>Số điện thoại<input inputMode="tel" onChange={(e) => setDraft({ ...draft, phone: e.target.value })} value={draft.phone} /></label>
              <label>Ngày<input onChange={(e) => setDraft({ ...draft, date: e.target.value })} required type="date" value={draft.date} /></label>
              <label>Giờ bắt đầu<input onChange={(e) => setDraft({ ...draft, start: e.target.value })} required step={300} type="time" value={draft.start} /></label>
              <label>Phòng
                <select onChange={(e) => setDraft({ ...draft, room_id: e.target.value, package_id: activePackages.find((pkg) => pkg.room_id === e.target.value)?.id || "" })} required value={draft.room_id}>
                  {activeRooms.map((room) => <option key={room.id} value={room.id}>{room.name}</option>)}
                </select>
              </label>
              <label>Gói
                <select onChange={(e) => setDraft({ ...draft, package_id: e.target.value })} required value={draft.package_id}>
                  {draftPackages.length === 0 ? <option value="">Phòng chưa có gói</option> : null}
                  {draftPackages.map((pkg) => <option key={pkg.id} value={pkg.id}>{pkg.name} · {pkg.minutes} phút</option>)}
                </select>
              </label>
              <label>Trạng thái
                <select onChange={(e) => setDraft({ ...draft, status: e.target.value as Status })} value={draft.status}>
                  {STATUS_ORDER.map((status) => <option key={status} value={status}>{STATUS[status].label}</option>)}
                </select>
              </label>
              <label className="wide">Ghi chú<textarea maxLength={500} onChange={(e) => setDraft({ ...draft, note: e.target.value })} rows={2} value={draft.note} /></label>
            </div>
            {draftError ? <p className="booking-error" role="alert">{draftError}</p> : null}
            <div className="booking-dialog-actions">
              <button className="text-action" onClick={() => setDraft(null)} type="button">Hủy bỏ</button>
              <button className="primary-action" disabled={saving || !draft.package_id} type="submit"><Check size={17} />{saving ? "Đang lưu…" : "Lưu lịch"}</button>
            </div>
          </form>
        </div>
      ) : null}
    </div>
  );
}
