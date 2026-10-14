"use client";

import { ArrowLeft, ArrowRight, CalendarCheck, CalendarDays, CalendarX, ChevronRight, DoorOpen, Images, Loader2, LogIn, LogOut, Ticket, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { FormEvent } from "react";
import { addDays, clock, dayLabel, money } from "../admin/api";
import { type Branding, BrandLogo, applyBranding } from "../brand";

type Room = { id: string; name: string; description: string; capacity: string; cover_url?: string };
type PhotoPackage = { id: string; room_id: string; name: string; minutes: number; price_vnd: number; description: string };
type Settings = { enabled: boolean; open_minute: number; close_minute: number; slot_minutes: number; days_ahead: number; notice: string };
type Options = { studio_id: string; branding?: Branding; settings?: Settings; today?: string; rooms: Room[]; packages: PhotoPackage[] };
type Customer = { id: string; name: string; phone: string; phone_masked: string };
type Status = "pending" | "confirmed" | "done" | "cancelled";
type MyBooking = {
  id: string; code: string; booking_date: string; start_minute: number; end_minute: number; note: string; price_vnd: number;
  status: Status; room_name: string | null; package_name: string | null; play_code: string | null; play_code_status: string | null;
};
type MyGallery = { token: string; photos_count: number; shot_at: string; booking_code: string; booking_date: string; room_name: string; cover_url: string };
type View = "book" | "mine" | "photos";

const FALLBACK_SETTINGS: Settings = { enabled: true, open_minute: 540, close_minute: 1260, slot_minutes: 30, days_ahead: 30, notice: "" };
/** "Lịch của tôi" re-reads this often while a booking waits for the studio, so the code shows up by itself. */
const PENDING_POLL_MS = 15000;

const STATUS_LABEL: Record<Status, { label: string; tone: string }> = {
  pending: { label: "Chờ xác nhận", tone: "warn" },
  confirmed: { label: "Đã xác nhận", tone: "ok" },
  done: { label: "Đã chụp", tone: "neutral" },
  cancelled: { label: "Đã hủy", tone: "error" },
};

type ApiFailure = Error & { status?: number; code?: string };

async function call<T>(path: string, init?: RequestInit): Promise<T> {
  const response = await fetch(path, {
    cache: "no-store",
    credentials: "include",
    ...init,
    headers: init?.body ? { "content-type": "application/json" } : undefined,
  });
  const data = await response.json().catch(() => ({}));
  if (!response.ok) {
    const err = new Error(data.message || data.error || "Không kết nối được studio") as ApiFailure;
    err.status = response.status;
    err.code = data.error;
    throw err;
  }
  return data as T;
}

/** Phòng đang xem, từ `?room=` — để nút Back của trình duyệt quay về danh sách phòng. */
function roomFromUrl() {
  return new URLSearchParams(window.location.search).get("room") || "";
}

export default function BookingPage() {
  const [studioId, setStudioId] = useState("");
  const [options, setOptions] = useState<Options | null>(null);
  const [customer, setCustomer] = useState<Customer | null>(null);
  const [checkedSession, setCheckedSession] = useState(false);
  const [bookings, setBookings] = useState<MyBooking[]>([]);
  const [galleries, setGalleries] = useState<MyGallery[]>([]);
  const [view, setView] = useState<View>("book");
  const [authMode, setAuthMode] = useState<"login" | "register">("login");
  const [authName, setAuthName] = useState("");
  const [authPhone, setAuthPhone] = useState("");
  const [authBusy, setAuthBusy] = useState(false);
  const [authError, setAuthError] = useState("");
  /** Khách bấm "Đặt lịch" khi chưa đăng nhập: đăng nhập xong thì gửi lịch luôn. */
  const [bookAfterAuth, setBookAfterAuth] = useState(false);
  const authDialog = useRef<HTMLDialogElement | null>(null);
  /** "" = danh sách phòng; có id = trang của phòng đó. */
  const [roomId, setRoomId] = useState("");
  const [packageId, setPackageId] = useState("");
  const [date, setDate] = useState("");
  const [start, setStart] = useState<number | null>(null);
  const [busy, setBusy] = useState<Array<{ start: number; end: number }>>([]);
  const [nowMinute, setNowMinute] = useState<number | null>(null);
  const [slotsLoading, setSlotsLoading] = useState(false);
  const [slotsVersion, setSlotsVersion] = useState(0);
  const [note, setNote] = useState("");
  const [submitting, setSubmitting] = useState(false);
  const [error, setError] = useState("");
  const [justBooked, setJustBooked] = useState("");

  const loadMe = useCallback(async () => {
    try {
      const data = await call<{ customer: Customer; bookings: MyBooking[]; galleries: MyGallery[] }>("/v1/public/customers/me");
      setCustomer(data.customer);
      setBookings(data.bookings);
      setGalleries(data.galleries);
      return true;
    } catch {
      // 401: chưa đăng nhập, hoặc phiên 24h đã hết → hỏi lại SĐT khi khách đặt lịch.
      setCustomer(null);
      return false;
    } finally {
      setCheckedSession(true);
    }
  }, []);

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    const id = params.get("studio_id") || params.get("s") || "";
    setStudioId(id);
    if (params.get("view") === "mine" || params.get("view") === "photos") setView(params.get("view") as View);
    call<Options>(`/v1/public/booking/options${id ? `?studio_id=${encodeURIComponent(id)}` : ""}`)
      .then((data) => {
        setOptions(data);
        if (data.branding) applyBranding(data.branding);
        const linked = roomFromUrl();
        if (linked && data.rooms.some((room) => room.id === linked)) setRoomId(linked);
        setDate(data.today || new Date().toISOString().slice(0, 10));
      })
      .catch((err) => setError((err as Error).message));
    void loadMe();
  }, [loadMe]);

  // Nút Back / Forward của trình duyệt: đi giữa danh sách phòng và trang phòng.
  useEffect(() => {
    const onPop = () => {
      setRoomId(roomFromUrl());
      setPackageId("");
      setStart(null);
    };
    window.addEventListener("popstate", onPop);
    return () => window.removeEventListener("popstate", onPop);
  }, []);

  const settings = options?.settings ?? FALLBACK_SETTINGS;
  const branding = options?.branding ?? null;
  const brandName = branding?.name || "Studio";
  const today = options?.today || "";
  const roomPackages = useMemo(
    () => (options?.packages ?? []).filter((pkg) => pkg.room_id === roomId).sort((a, b) => a.price_vnd - b.price_vnd),
    [options, roomId],
  );
  const room = options?.rooms.find((item) => item.id === roomId);
  const pkg = roomPackages.find((item) => item.id === packageId);
  /** Giá thấp nhất + số gói của mỗi phòng, cho dòng "Từ … · n gói". */
  const roomSummary = useMemo(() => {
    const summary = new Map<string, { from: number; count: number }>();
    for (const item of options?.packages ?? []) {
      const current = summary.get(item.room_id);
      summary.set(item.room_id, {
        from: current ? Math.min(current.from, item.price_vnd) : item.price_vnd,
        count: (current?.count ?? 0) + 1,
      });
    }
    return summary;
  }, [options]);
  const days = useMemo(() => {
    if (!options) return [];
    const first = options.today || new Date().toISOString().slice(0, 10);
    return Array.from({ length: settings.days_ahead + 1 }, (_, i) => addDays(first, i));
  }, [options, settings.days_ahead]);
  const upcoming = useMemo(
    () => bookings.filter((b) => b.booking_date >= today && (b.status === "pending" || b.status === "confirmed")),
    [bookings, today],
  );
  const ordered = useMemo(() => {
    const next = [...upcoming].sort((a, b) => (a.booking_date.localeCompare(b.booking_date)) || a.start_minute - b.start_minute);
    const rest = bookings.filter((b) => !upcoming.includes(b));
    return [...next, ...rest];
  }, [bookings, upcoming]);
  const waiting = upcoming.some((b) => b.status === "pending");

  useEffect(() => {
    document.title = room ? `${room.name} · ${brandName}` : `${brandName} · Đặt lịch chụp`;
  }, [brandName, room]);

  // Trong lúc lịch chờ studio xác nhận, đọc lại để mã chụp tự hiện.
  useEffect(() => {
    if (!customer || !waiting) return;
    const timer = window.setInterval(() => {
      if (!document.hidden) void loadMe();
    }, PENDING_POLL_MS);
    return () => window.clearInterval(timer);
  }, [customer, loadMe, waiting]);

  // Giờ đã kín của phòng trong ngày (xem được cả khi chưa đăng nhập).
  useEffect(() => {
    if (!roomId || !date || !options) return;
    let live = true;
    setSlotsLoading(true);
    setStart(null);
    const query = new URLSearchParams({ room_id: roomId, date, ...(options.studio_id ? { studio_id: options.studio_id } : {}) });
    call<{ busy: Array<{ start: number; end: number }>; now_minute: number | null }>(`/v1/public/booking/availability?${query}`)
      .then((data) => { if (live) { setBusy(data.busy); setNowMinute(data.now_minute); } })
      .catch(() => { if (live) { setBusy([]); setNowMinute(null); } })
      .finally(() => { if (live) setSlotsLoading(false); });
    return () => { live = false; };
  }, [date, options, roomId, slotsVersion]);

  const slots = useMemo(() => {
    const length = pkg?.minutes ?? settings.slot_minutes;
    const list: Array<{ minute: number; free: boolean }> = [];
    for (let m = settings.open_minute; m + length <= settings.close_minute; m += settings.slot_minutes) {
      const taken = busy.some((b) => m < b.end && b.start < m + length);
      const past = nowMinute !== null && m <= nowMinute;
      list.push({ minute: m, free: !taken && !past });
    }
    return list;
  }, [busy, nowMinute, pkg, settings]);

  const openRoom = (id: string) => {
    const url = new URL(window.location.href);
    url.searchParams.set("room", id);
    window.history.pushState({ room: id }, "", url);
    setRoomId(id);
    setPackageId("");
    setStart(null);
    setError("");
    window.scrollTo({ top: 0 });
  };

  const backToRooms = () => {
    // Vào thẳng từ link có ?room= thì không có trang trước để Back: thay URL tại chỗ.
    if (window.history.state?.room) {
      window.history.back();
      return;
    }
    const url = new URL(window.location.href);
    url.searchParams.delete("room");
    window.history.replaceState(null, "", url);
    setRoomId("");
    setPackageId("");
    setStart(null);
  };

  const choosePackage = (id: string) => {
    setPackageId(id);
    setStart(null);
  };

  const openAuth = (afterwards: boolean) => {
    setBookAfterAuth(afterwards);
    setAuthError("");
    if (!authDialog.current?.open) authDialog.current?.showModal();
  };

  const closeAuth = () => {
    authDialog.current?.close();
  };

  // Mở link "Lịch của tôi" / "Ảnh của tôi" khi chưa đăng nhập: hỏi SĐT trước.
  useEffect(() => {
    if (checkedSession && !customer && view !== "book") {
      setView("book");
      openAuth(false);
    }
  }, [checkedSession, customer, view]);

  const ready = Boolean(room && pkg && date && start !== null && note.trim().length >= 2);

  const submit = useCallback(async () => {
    if (!ready || start === null || !pkg || !room) return;
    setSubmitting(true);
    setError("");
    try {
      const data = await call<{ booking: { code: string } }>("/v1/public/booking", {
        method: "POST",
        body: JSON.stringify({ studio_id: options?.studio_id || studioId, room_id: room.id, package_id: pkg.id, date, start_minute: start, note: note.trim() }),
      });
      setJustBooked(data.booking.code);
      setNote("");
      setStart(null);
      setSlotsVersion((v) => v + 1);
      await loadMe();
      setView("mine");
      window.scrollTo({ top: 0 });
    } catch (err) {
      const failure = err as ApiFailure;
      if (failure.status === 401) {
        await loadMe();
        openAuth(true);
      }
      setError(failure.message);
      setSlotsVersion((v) => v + 1);
    } finally {
      setSubmitting(false);
    }
  }, [date, loadMe, note, options, pkg, ready, room, start, studioId]);

  const book = () => {
    if (!ready) return;
    if (!customer) {
      openAuth(true);
      return;
    }
    void submit();
  };

  const authenticate = async (event: FormEvent) => {
    event.preventDefault();
    setAuthBusy(true);
    setAuthError("");
    const studio = options?.studio_id || studioId;
    try {
      if (authMode === "register") {
        await call("/v1/public/customers/register", { method: "POST", body: JSON.stringify({ studio_id: studio, name: authName, phone: authPhone }) });
      } else {
        await call("/v1/public/customers/login", { method: "POST", body: JSON.stringify({ studio_id: studio, phone: authPhone }) });
      }
      if (await loadMe()) closeAuth();
    } catch (err) {
      const failure = err as ApiFailure;
      if (failure.code === "phone_registered") setAuthMode("login");
      if (failure.code === "customer_not_found") setAuthMode("register");
      setAuthError(failure.message);
    } finally {
      setAuthBusy(false);
    }
  };

  // Đăng nhập xong từ nút "Đặt lịch": gửi lịch đã chọn luôn, không bắt bấm lại.
  useEffect(() => {
    if (!customer || !bookAfterAuth) return;
    setBookAfterAuth(false);
    void submit();
  }, [bookAfterAuth, customer, submit]);

  const signOut = async () => {
    await call("/v1/public/customers/logout", { method: "POST" }).catch(() => undefined);
    setCustomer(null);
    setBookings([]);
    setGalleries([]);
    setView("book");
  };

  const header = (
    <header className="booking-brand">
      <BrandLogo branding={branding} name={brandName} />
      <div>
        <span className="eyebrow">Đặt lịch chụp</span>
        <h1>{brandName}</h1>
      </div>
    </header>
  );

  const authDialogNode = (
    <dialog
      aria-labelledby="booking-auth-title"
      className="booking-auth-dialog"
      onClick={(event) => { if (event.target === event.currentTarget) closeAuth(); }}
      onClose={() => setBookAfterAuth(false)}
      ref={authDialog}
    >
      <section className="booking-auth">
        <header className="booking-auth-head">
          <h2 id="booking-auth-title">{bookAfterAuth ? "Đăng nhập để đặt lịch" : "Tài khoản"}</h2>
          <button aria-label="Đóng" className="booking-icon-button" onClick={closeAuth} type="button"><X size={18} /></button>
        </header>
        <div className="booking-tabs" role="tablist" aria-label="Tài khoản">
          <button aria-selected={authMode === "login"} className={authMode === "login" ? "active" : ""} onClick={() => { setAuthMode("login"); setAuthError(""); }} role="tab" type="button">Đăng nhập</button>
          <button aria-selected={authMode === "register"} className={authMode === "register" ? "active" : ""} onClick={() => { setAuthMode("register"); setAuthError(""); }} role="tab" type="button">Đăng ký</button>
        </div>
        <form className="booking-fields" onSubmit={authenticate}>
          {authMode === "register" ? (
            <label className="wide">Họ tên<input autoComplete="name" maxLength={80} onChange={(e) => setAuthName(e.target.value)} required value={authName} /></label>
          ) : null}
          <label className="wide">Số điện thoại<input autoComplete="tel" inputMode="tel" maxLength={20} onChange={(e) => setAuthPhone(e.target.value)} required value={authPhone} /></label>
          {authError ? <p className="booking-error wide" role="alert">{authError}</p> : null}
          <button className="primary-action wide" disabled={authBusy} type="submit">
            {authBusy ? <Loader2 className="spin" size={18} /> : null}
            {authMode === "register" ? (bookAfterAuth ? "Đăng ký & đặt lịch" : "Đăng ký") : (bookAfterAuth ? "Đăng nhập & đặt lịch" : "Đăng nhập")}
          </button>
        </form>
        <p className="booking-auth-hint">
          {authMode === "login" ? "Dùng số điện thoại bạn đã đăng ký." : "Đăng ký một lần, lần sau chỉ cần số điện thoại."}
        </p>
      </section>
    </dialog>
  );

  if (!options) {
    return (
      <main className="booking-page">
        {header}
        {error ? <div className="inline-message" role="alert">{error}</div> : <div className="gallery-frame-status"><Loader2 className="spin" size={18} /> Đang tải</div>}
      </main>
    );
  }

  const showFlowBar = view === "book" && settings.enabled && Boolean(room);

  return (
    <main className={showFlowBar ? "booking-page has-flow-bar" : "booking-page"}>
      {header}
      {customer ? (
        <>
          <div className="booking-account">
            <span><strong>{customer.name}</strong><small>{customer.phone_masked}</small></span>
            <button className="text-action" onClick={signOut} type="button"><LogOut size={16} />Thoát</button>
          </div>
          <nav className="booking-tabs booking-views" aria-label="Mục">
            <button aria-current={view === "book" ? "page" : undefined} className={view === "book" ? "active" : ""} onClick={() => setView("book")} type="button"><CalendarDays size={17} />Đặt lịch</button>
            <button aria-current={view === "mine" ? "page" : undefined} className={view === "mine" ? "active" : ""} onClick={() => { setView("mine"); void loadMe(); }} type="button">
              <Ticket size={17} />Lịch của tôi{upcoming.length > 0 ? <b>{upcoming.length}</b> : null}
            </button>
            <button aria-current={view === "photos" ? "page" : undefined} className={view === "photos" ? "active" : ""} onClick={() => { setView("photos"); void loadMe(); }} type="button"><Images size={17} />Ảnh của tôi</button>
          </nav>
        </>
      ) : checkedSession ? (
        <div className="booking-account">
          <p className="booking-account-hint">Đã có lịch? Đăng nhập để xem mã chụp và ảnh.</p>
          <button className="text-action" onClick={() => openAuth(false)} type="button"><LogIn size={16} />Đăng nhập</button>
        </div>
      ) : null}

      {error ? <div className="inline-message" role="alert">{error}</div> : null}

      {view === "book" ? (
        <>
          {settings.notice && !room ? <p className="booking-notice-text">{settings.notice}</p> : null}
          {!settings.enabled ? (
            <section className="booking-closed">
              <CalendarX size={30} />
              <h2>Studio tạm ngừng nhận lịch online</h2>
              <p>Vui lòng liên hệ trực tiếp studio để đặt lịch.</p>
            </section>
          ) : !room ? (
            <section className="booking-step" aria-labelledby="rooms-title">
              <h2 id="rooms-title">Chọn phòng</h2>
              {options.rooms.length === 0 ? <p className="booking-empty">Studio chưa mở phòng nhận lịch.</p> : null}
              <div className="room-list">
                {options.rooms.map((item) => {
                  const summary = roomSummary.get(item.id);
                  return (
                    <button className="room-row" key={item.id} onClick={() => openRoom(item.id)} type="button">
                      <span className="room-row-cover">
                        {item.cover_url ? <img alt="" decoding="async" loading="lazy" src={item.cover_url} /> : <DoorOpen size={26} />}
                      </span>
                      <span className="room-row-text">
                        <strong>{item.name}</strong>
                        {item.capacity ? <small>{item.capacity}</small> : null}
                        <span className="room-row-price">
                          {summary ? <><b>Từ {money.format(summary.from)}</b> · {summary.count} gói</> : "Chưa có gói"}
                        </span>
                      </span>
                      <ChevronRight aria-hidden="true" className="room-row-go" size={20} />
                    </button>
                  );
                })}
              </div>
            </section>
          ) : (
            <div className="booking-steps">
              <section className="room-detail" aria-labelledby="room-title">
                <button className="text-action room-back" onClick={backToRooms} type="button"><ArrowLeft size={16} />Tất cả phòng</button>
                {room.cover_url ? (
                  <figure className="room-hero"><img alt={`Phòng ${room.name}`} decoding="async" src={room.cover_url} /></figure>
                ) : null}
                <h2 id="room-title">{room.name}</h2>
                {room.capacity ? <p className="room-detail-capacity">{room.capacity}</p> : null}
                {room.description ? <p className="room-detail-description">{room.description}</p> : null}
              </section>

              <section className="booking-step" aria-labelledby="step-package">
                <h2 id="step-package">Gói chụp</h2>
                {roomPackages.length === 0 ? <p className="booking-empty">Phòng này chưa có gói.</p> : null}
                <div className="package-list" role="radiogroup" aria-labelledby="step-package">
                  {roomPackages.map((item) => (
                    <button aria-checked={item.id === packageId} className={item.id === packageId ? "package-row active" : "package-row"} key={item.id} onClick={() => choosePackage(item.id)} role="radio" type="button">
                      <span className="package-row-mark" aria-hidden="true" />
                      <span className="package-row-text">
                        <strong>{item.name}</strong>
                        <small>{item.minutes} phút{item.description ? ` · ${item.description}` : ""}</small>
                      </span>
                      <b className="package-row-price">{money.format(item.price_vnd)}</b>
                    </button>
                  ))}
                </div>
              </section>

              {pkg ? (
                <>
                  <section className="booking-step" aria-labelledby="step-day">
                    <h2 id="step-day">Ngày</h2>
                    <div className="booking-days">
                      {days.map((d) => {
                        const label = dayLabel(d);
                        return (
                          <button aria-pressed={d === date} className={d === date ? "active" : ""} key={d} onClick={() => setDate(d)} type="button">
                            <small>{d === today ? "Hôm nay" : label.weekday}</small>
                            <strong>{label.day}</strong>
                          </button>
                        );
                      })}
                    </div>
                  </section>

                  <section className="booking-step" aria-labelledby="step-time">
                    <h2 id="step-time">Giờ {slotsLoading ? <Loader2 className="spin" size={16} /> : null}</h2>
                    {slots.length > 0 && slots.every((slot) => !slot.free) && !slotsLoading ? <p className="booking-empty">Ngày này đã kín lịch, hãy chọn ngày khác.</p> : null}
                    <div className="booking-slots">
                      {slots.map((slot) => (
                        <button aria-pressed={slot.minute === start} className={slot.minute === start ? "active" : ""} disabled={!slot.free || slotsLoading} key={slot.minute} onClick={() => setStart(slot.minute)} type="button">
                          {clock(slot.minute)}
                        </button>
                      ))}
                    </div>
                  </section>

                  <section className="booking-step" aria-labelledby="step-note">
                    <h2 id="step-note">Ghi chú cho studio</h2>
                    <div className="booking-fields">
                      <label className="wide">
                        <span>Bắt buộc · số người, concept, yêu cầu thêm</span>
                        <textarea aria-required="true" maxLength={500} onChange={(e) => setNote(e.target.value)} placeholder="2 người, concept vintage" required rows={3} value={note} />
                      </label>
                    </div>
                  </section>
                </>
              ) : null}
            </div>
          )}
        </>
      ) : null}

      {view === "mine" ? (
        <section className="my-bookings" aria-label="Lịch của tôi">
          {justBooked && !ordered.find((x) => x.code === justBooked)?.play_code ? <p className="booking-just" role="status"><CalendarCheck size={18} />Đã gửi lịch {justBooked}. Mã chụp sẽ hiện ở đây khi studio xác nhận.</p> : null}
          {ordered.length === 0 ? (
            <div className="empty-state"><Ticket size={28} /><strong>Chưa có lịch</strong><button className="text-action" onClick={() => setView("book")} type="button">Đặt lịch ngay</button></div>
          ) : null}
          {ordered.map((b) => {
            const label = dayLabel(b.booking_date);
            const showCode = b.play_code && (b.status === "confirmed" || b.status === "done");
            return (
              <article className={`my-booking is-${b.status}`} key={b.id}>
                <header>
                  <div>
                    <strong>{label.weekday} {label.day} · {clock(b.start_minute)}–{clock(b.end_minute)}</strong>
                    <span>{b.room_name || "Phòng"} · {b.package_name || "Gói"} · {money.format(b.price_vnd)}</span>
                  </div>
                  <span className={`status-pill ${STATUS_LABEL[b.status].tone}`}>{STATUS_LABEL[b.status].label}</span>
                </header>
                {showCode ? (
                  <div className={`play-code${b.play_code_status === "used" ? " is-used" : ""}`}>
                    <small>Mã chụp</small>
                    <strong aria-label={`Mã chụp ${b.play_code?.split("").join(" ")}`}>{b.play_code}</strong>
                    <span>{b.play_code_status === "used" ? "Đã dùng ở máy chụp" : `Nhập mã này ở máy chụp · dùng trong ngày ${label.day}`}</span>
                  </div>
                ) : b.status === "pending" ? (
                  <p className="my-booking-wait"><Loader2 className="spin" size={15} />Chờ studio xác nhận, mã chụp sẽ hiện tại đây.</p>
                ) : null}
                {b.note ? <p className="my-booking-note">{b.note}</p> : null}
                <small className="my-booking-code">{b.code}</small>
              </article>
            );
          })}
        </section>
      ) : null}

      {view === "photos" ? (
        <section className="my-photos" aria-label="Ảnh của tôi">
          {galleries.length === 0 ? (
            <div className="empty-state"><Images size={28} /><strong>Chưa có ảnh</strong><span>Ảnh hiện ở đây sau buổi chụp bằng mã đặt lịch.</span></div>
          ) : null}
          <div className="photo-grid">
            {galleries.map((g) => {
              const label = g.booking_date ? dayLabel(g.booking_date) : null;
              return (
                <a className="photo-tile my-photo" href={`/gallery?t=${encodeURIComponent(g.token)}`} key={g.token}>
                  {g.cover_url ? <img alt="" decoding="async" loading="lazy" src={g.cover_url} /> : <span className="my-photo-empty"><Images size={26} /></span>}
                  <span className="my-photo-caption">
                    <strong>{label ? `${label.weekday} ${label.day}` : "Buổi chụp"}</strong>
                    <small>{g.photos_count} ảnh{g.room_name ? ` · ${g.room_name}` : ""}</small>
                  </span>
                </a>
              );
            })}
          </div>
        </section>
      ) : null}

      {showFlowBar ? (
        <div className="flow-bar">
          <p aria-live="polite" className="flow-pick">
            <strong>{pkg ? money.format(pkg.price_vnd) : "Chọn gói"}</strong>
            <span>
              {pkg ? `${pkg.name} · ` : ""}
              {date ? `${dayLabel(date).weekday} ${dayLabel(date).day}` : ""}
              {pkg ? (start !== null ? ` · ${clock(start)}` : " · chọn giờ") : ""}
              {pkg && start !== null && note.trim().length < 2 ? " · cần ghi chú" : ""}
            </span>
          </p>
          <button className="primary-action" disabled={!ready || submitting} onClick={book} type="button">
            {submitting ? <Loader2 className="spin" size={18} /> : null}
            Đặt lịch
            <ArrowRight size={18} />
          </button>
        </div>
      ) : null}

      {authDialogNode}
    </main>
  );
}
