"use client";

import { Check, CheckCircle2, Copy, Download, KeyRound, Lock, LockOpen, Pencil, Plus, Trash2, Undo2, UserRound, X } from "lucide-react";
import { useCallback, useEffect, useMemo, useRef, useState } from "react";
import type { CSSProperties, FormEvent } from "react";
import { type ApiError, adminApi, portalHeaders } from "./api";
import { copyPending, downloadQr } from "./qr";

type PermissionGroup = { id: string; label: string; actions: Array<{ code: string; label: string }> };
type Preset = { id: string; label: string; permissions: string[] };

type Staff = {
  id: string;
  username: string;
  display_name: string;
  permissions: string[];
  status: "active" | "disabled";
  created_at: string;
  last_login_at: string;
};

type Draft = { id?: string; username: string; display_name: string; password: string; permissions: string[] };

/** Same undo window as the other deletes in the admin. */
const UNDO_MS = 6000;

function when(value: string) {
  if (!value) return "Chưa đăng nhập";
  const date = new Date(value);
  return Number.isNaN(date.getTime())
    ? "—"
    : date.toLocaleString("vi-VN", { hour: "2-digit", minute: "2-digit", day: "2-digit", month: "2-digit", year: "numeric" });
}

/** Tick an action: its group's "view" comes with it. Untick "view": the whole group goes. */
function toggle(permissions: string[], code: string, groups: PermissionGroup[]) {
  const group = groups.find((item) => item.actions.some((action) => action.code === code));
  const view = group?.actions.find((action) => action.code.endsWith(".view"))?.code;
  const next = new Set(permissions);
  if (next.has(code)) {
    if (code === view && group) group.actions.forEach((action) => next.delete(action.code));
    else next.delete(code);
  } else {
    next.add(code);
    if (view) next.add(view);
  }
  return groups.flatMap((item) => item.actions.map((action) => action.code)).filter((item) => next.has(item));
}

/** Owner only: staff accounts, what each may do, and the link to the staff portal. */
export function StaffPanel({ studioId, studioName }: { studioId: string; studioName: string }) {
  const [staff, setStaff] = useState<Staff[]>([]);
  const [groups, setGroups] = useState<PermissionGroup[]>([]);
  const [presets, setPresets] = useState<Preset[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState("");
  const [notice, setNotice] = useState("");
  const [draft, setDraft] = useState<Draft | null>(null);
  const [saving, setSaving] = useState(false);
  const [draftError, setDraftError] = useState("");
  const [reset, setReset] = useState<{ staff: Staff; password: string } | null>(null);
  const [copied, setCopied] = useState(false);
  const [pendingDelete, setPendingDelete] = useState<Staff | null>(null);
  const pendingTimer = useRef(0);

  const portalUrl = typeof window === "undefined" ? "" : `${window.location.origin}/staff?studio=${encodeURIComponent(studioId)}`;
  const allCodes = useMemo(() => groups.flatMap((group) => group.actions.map((action) => action.code)), [groups]);

  const load = useCallback(async () => {
    setLoading(true);
    setError("");
    try {
      const data = await adminApi<{ staff: Staff[]; groups: PermissionGroup[]; presets: Preset[] }>("/v1/web/staff");
      setStaff(data.staff);
      setGroups(data.groups);
      setPresets(data.presets);
    } catch (err) {
      setError((err as ApiError).message);
    } finally {
      setLoading(false);
    }
  }, []);

  useEffect(() => { void load(); }, [load]);

  const commitDelete = useCallback(async (target: Staff | null) => {
    window.clearTimeout(pendingTimer.current);
    if (!target) return;
    setPendingDelete((current) => (current?.id === target.id ? null : current));
    try {
      await adminApi(`/v1/web/staff/${target.id}`, { method: "DELETE" });
      setStaff((current) => current.filter((item) => item.id !== target.id));
    } catch (err) {
      setError(`Chưa xóa được: ${(err as ApiError).message}`);
    }
  }, []);

  // Leaving the page inside the undo window still deletes.
  useEffect(() => {
    if (!pendingDelete) return;
    const flush = () => {
      void fetch(`/v1/web/staff/${pendingDelete.id}`, { method: "DELETE", credentials: "include", headers: portalHeaders(), keepalive: true }).catch(() => undefined);
    };
    window.addEventListener("pagehide", flush);
    return () => window.removeEventListener("pagehide", flush);
  }, [pendingDelete]);

  const scheduleDelete = (target: Staff) => {
    void commitDelete(pendingDelete);
    setNotice("");
    setPendingDelete(target);
    pendingTimer.current = window.setTimeout(() => void commitDelete(target), UNDO_MS);
  };

  const undoDelete = () => {
    window.clearTimeout(pendingTimer.current);
    setPendingDelete(null);
  };

  const openNew = () => {
    setDraftError("");
    setDraft({ username: "", display_name: "", password: "", permissions: presets[0]?.permissions ?? [] });
  };

  const openEdit = (item: Staff) => {
    setDraftError("");
    setDraft({ id: item.id, username: item.username, display_name: item.display_name, password: "", permissions: item.permissions });
  };

  const saveDraft = async (event: FormEvent) => {
    event.preventDefault();
    if (!draft) return;
    setSaving(true);
    setDraftError("");
    try {
      if (draft.id) {
        const data = await adminApi<{ staff: Staff }>(`/v1/web/staff/${draft.id}`, {
          method: "PATCH",
          body: JSON.stringify({ display_name: draft.display_name, permissions: draft.permissions }),
        });
        setStaff((current) => current.map((item) => (item.id === data.staff.id ? data.staff : item)));
        setNotice(`Đã lưu quyền của ${data.staff.display_name}.`);
      } else {
        const data = await adminApi<{ staff: Staff }>("/v1/web/staff", {
          method: "POST",
          body: JSON.stringify(draft),
        });
        setStaff((current) => [data.staff, ...current]);
        setNotice(`Đã tạo tài khoản @${data.staff.username}. Gửi link cổng nhân viên kèm mật khẩu cho nhân viên.`);
      }
      setDraft(null);
    } catch (err) {
      setDraftError((err as ApiError).message);
    } finally {
      setSaving(false);
    }
  };

  const setStatus = async (item: Staff, status: Staff["status"]) => {
    setError("");
    try {
      const data = await adminApi<{ staff: Staff }>(`/v1/web/staff/${item.id}`, { method: "PATCH", body: JSON.stringify({ status }) });
      setStaff((current) => current.map((row) => (row.id === data.staff.id ? data.staff : row)));
      setNotice(status === "disabled" ? `Đã khóa @${item.username} và đăng xuất mọi thiết bị.` : `Đã mở lại @${item.username}.`);
    } catch (err) {
      setError((err as ApiError).message);
    }
  };

  const savePassword = async (event: FormEvent) => {
    event.preventDefault();
    if (!reset) return;
    setSaving(true);
    setDraftError("");
    try {
      await adminApi(`/v1/web/staff/${reset.staff.id}`, { method: "PATCH", body: JSON.stringify({ password: reset.password }) });
      setNotice(`Đã đặt mật khẩu mới cho @${reset.staff.username}.`);
      setReset(null);
    } catch (err) {
      setDraftError((err as ApiError).message);
    } finally {
      setSaving(false);
    }
  };

  const copyLink = async () => {
    try {
      await copyPending(Promise.resolve(portalUrl));
      setCopied(true);
      window.setTimeout(() => setCopied(false), 1800);
    } catch {
      setError("Trình duyệt không cho copy, hãy chọn và copy link bằng tay.");
    }
  };

  const shown = staff.filter((item) => item.id !== pendingDelete?.id);

  return (
    <div className="staff-admin">
      <section className="staff-portal" aria-labelledby="staff-portal-title">
        <div>
          <h3 id="staff-portal-title">Cổng nhân viên</h3>
          <p className="staff-portal-link">{portalUrl}</p>
        </div>
        <div className="staff-portal-actions">
          <button className={`ghost-action${copied ? " is-done" : ""}`} onClick={copyLink} type="button">
            {copied ? <CheckCircle2 size={17} /> : <Copy size={17} />}{copied ? "Đã copy" : "Copy link"}
          </button>
          <button className="ghost-action" onClick={() => downloadQr(portalUrl, studioName, "Cổng nhân viên", "cong-nhan-vien.png")} type="button">
            <Download size={17} />Tải QR
          </button>
        </div>
      </section>

      <div className="staff-toolbar">
        <p>{loading ? "Đang tải" : `${shown.length} nhân viên`}</p>
        <button className="primary-action" disabled={loading || groups.length === 0} onClick={openNew} type="button"><Plus size={17} />Thêm nhân viên</button>
      </div>

      {error ? <p className="booking-error" role="alert">{error}</p> : null}
      {notice ? <p className="staff-notice" role="status">{notice}</p> : null}

      {!loading && shown.length === 0 ? (
        <div className="empty-state">
          <UserRound size={28} />
          <strong>Chưa có nhân viên</strong>
          <span>Tạo tài khoản, chọn việc nhân viên được làm, rồi gửi link cổng nhân viên.</span>
        </div>
      ) : null}

      <ul className="staff-list">
        {shown.map((item) => {
          const granted = new Set(item.permissions);
          const groupsShown = groups.filter((group) => group.actions.some((action) => granted.has(action.code)));
          return (
            <li className={`staff-row${item.status === "disabled" ? " is-disabled" : ""}`} key={item.id}>
              <div className="staff-who">
                <strong>{item.display_name}</strong>
                <span>@{item.username}</span>
              </div>
              <span className={`status-pill ${item.status === "active" ? "online" : "disabled"}`}>{item.status === "active" ? "Đang dùng" : "Đã khóa"}</span>
              <p className="staff-scope">
                {groupsShown.length === 0 ? "Chưa có quyền nào" : groupsShown.map((group) => group.label).join(" · ")}
              </p>
              <small className="staff-last">{when(item.last_login_at)}</small>
              <div className="staff-actions">
                <button className="text-action" onClick={() => openEdit(item)} type="button"><Pencil size={15} />Quyền</button>
                <button className="text-action" onClick={() => { setDraftError(""); setReset({ staff: item, password: "" }); }} type="button"><KeyRound size={15} />Mật khẩu</button>
                {item.status === "active" ? (
                  <button className="text-action" onClick={() => setStatus(item, "disabled")} type="button"><Lock size={15} />Khóa</button>
                ) : (
                  <button className="text-action" onClick={() => setStatus(item, "active")} type="button"><LockOpen size={15} />Mở khóa</button>
                )}
                <button aria-label={`Xóa @${item.username}`} className="danger-action" onClick={() => scheduleDelete(item)} type="button"><Trash2 size={15} /></button>
              </div>
            </li>
          );
        })}
      </ul>

      {draft ? (
        <div className="gallery-modal" onClick={(event) => { if (event.target === event.currentTarget && !saving) setDraft(null); }}>
          <form aria-labelledby="staff-draft-title" aria-modal="true" className="gallery-modal-panel staff-dialog" onSubmit={saveDraft} role="dialog">
            <header className="group-modal-head">
              <h2 id="staff-draft-title">{draft.id ? `Quyền của @${draft.username}` : "Thêm nhân viên"}</h2>
              <button aria-label="Đóng" className="gallery-icon-button" disabled={saving} onClick={() => setDraft(null)} type="button"><X size={18} /></button>
            </header>

            <div className="staff-dialog-fields">
              {draft.id ? null : (
                <label>
                  Tên đăng nhập
                  <input autoCapitalize="none" autoComplete="off" maxLength={32} minLength={3} onChange={(event) => setDraft({ ...draft, username: event.target.value.toLowerCase() })} pattern="[a-z0-9][a-z0-9._\-]{2,31}" placeholder="vd: thungan01" required spellCheck={false} value={draft.username} />
                </label>
              )}
              <label>
                Tên hiển thị
                <input maxLength={60} onChange={(event) => setDraft({ ...draft, display_name: event.target.value })} placeholder="vd: Lan · thu ngân" value={draft.display_name} />
              </label>
              {draft.id ? null : (
                <label>
                  Mật khẩu
                  <input autoComplete="new-password" maxLength={128} minLength={8} onChange={(event) => setDraft({ ...draft, password: event.target.value })} placeholder="Tối thiểu 8 ký tự" required type="text" value={draft.password} />
                </label>
              )}
            </div>

            <div className="staff-presets" role="group" aria-label="Mẫu quyền">
              <span>Mẫu nhanh</span>
              {presets.map((preset) => (
                <button className="chip-action" key={preset.id} onClick={() => setDraft({ ...draft, permissions: preset.permissions })} type="button">{preset.label}</button>
              ))}
              <button className="chip-action" onClick={() => setDraft({ ...draft, permissions: allCodes })} type="button">Tất cả</button>
              <button className="chip-action" onClick={() => setDraft({ ...draft, permissions: [] })} type="button">Bỏ hết</button>
            </div>

            <div className="permission-sheet">
              {groups.map((group) => {
                const picked = group.actions.filter((action) => draft.permissions.includes(action.code)).length;
                return (
                  <fieldset className="permission-group" key={group.id} style={{ "--picked": picked } as CSSProperties}>
                    <legend>
                      <span>{group.label}</span>
                      <small>{picked}/{group.actions.length}</small>
                    </legend>
                    {group.actions.map((action) => {
                      const checked = draft.permissions.includes(action.code);
                      return (
                        <label className={checked ? "permission-item is-on" : "permission-item"} key={action.code}>
                          <input checked={checked} onChange={() => setDraft({ ...draft, permissions: toggle(draft.permissions, action.code, groups) })} type="checkbox" />
                          <span>{action.label}</span>
                        </label>
                      );
                    })}
                  </fieldset>
                );
              })}
            </div>

            {draftError ? <p className="booking-error" role="alert">{draftError}</p> : null}
            <div className="booking-dialog-actions">
              <span className="staff-count">{draft.permissions.length} quyền</span>
              <button className="text-action" disabled={saving} onClick={() => setDraft(null)} type="button">Hủy bỏ</button>
              <button className="primary-action" disabled={saving} type="submit"><Check size={17} />{saving ? "Đang lưu…" : draft.id ? "Lưu quyền" : "Tạo tài khoản"}</button>
            </div>
          </form>
        </div>
      ) : null}

      {reset ? (
        <div className="gallery-modal" onClick={(event) => { if (event.target === event.currentTarget && !saving) setReset(null); }}>
          <form aria-labelledby="staff-reset-title" aria-modal="true" className="gallery-modal-panel password-dialog" onSubmit={savePassword} role="dialog">
            <header className="group-modal-head">
              <h2 id="staff-reset-title">Mật khẩu mới · @{reset.staff.username}</h2>
              <button aria-label="Đóng" className="gallery-icon-button" disabled={saving} onClick={() => setReset(null)} type="button"><X size={18} /></button>
            </header>
            <label>
              Mật khẩu mới
              <input autoComplete="new-password" autoFocus maxLength={128} minLength={8} onChange={(event) => setReset({ ...reset, password: event.target.value })} placeholder="Tối thiểu 8 ký tự" required type="text" value={reset.password} />
            </label>
            <p className="form-message">Nhân viên bị đăng xuất khỏi mọi thiết bị và đăng nhập lại bằng mật khẩu mới.</p>
            {draftError ? <p className="booking-error" role="alert">{draftError}</p> : null}
            <div className="booking-dialog-actions">
              <button className="text-action" disabled={saving} onClick={() => setReset(null)} type="button">Hủy bỏ</button>
              <button className="primary-action" disabled={saving} type="submit"><Check size={17} />{saving ? "Đang lưu…" : "Đặt mật khẩu"}</button>
            </div>
          </form>
        </div>
      ) : null}

      {pendingDelete ? (
        <div className="undo-bar" key={pendingDelete.id} role="status" aria-live="polite" style={{ "--undo-ms": `${UNDO_MS}ms` } as CSSProperties}>
          <span>Đã xóa @{pendingDelete.username}</span>
          <button onClick={undoDelete} type="button"><Undo2 size={16} />Hoàn tác</button>
          <i aria-hidden="true" />
        </div>
      ) : null}
    </div>
  );
}
