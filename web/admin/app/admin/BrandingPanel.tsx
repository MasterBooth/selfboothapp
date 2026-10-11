"use client";

import { CheckCircle2, ImagePlus, RotateCcw, Trash2, TriangleAlert } from "lucide-react";
import { useEffect, useMemo, useState } from "react";
import type { CSSProperties, ChangeEvent } from "react";
import { type Branding, BrandLogo, THEME_COLORS, brandStyle, contrast } from "../brand";
import { type ApiError, adminApi } from "./api";

const LOGO_TYPES = ["image/png", "image/jpeg", "image/webp"];
const MAX_LOGO_BYTES = 2 * 1024 * 1024;
/** WCAG AA for body text. */
const READABLE = 4.5;

type ColorKey = "bg" | "text" | "accent";
const COLOR_FIELDS: Array<{ key: ColorKey; label: string; hint: string }> = [
  { key: "bg", label: "Màu nền", hint: "Nền các trang" },
  { key: "text", label: "Màu chữ", hint: "Chữ và tiêu đề" },
  { key: "accent", label: "Màu nút", hint: "Nút chính, điểm nhấn" },
];

type Props = {
  branding: Branding | null;
  studioName: string;
  onSaved: (branding: Branding) => void;
};

/**
 * Brand name, logo and the three colours, with a phone preview of the guest gallery
 * that follows every change before anything is saved.
 */
export function BrandingPanel({ branding, studioName, onSaved }: Props) {
  const [name, setName] = useState("");
  const [colors, setColors] = useState<Record<ColorKey, string>>({ bg: "", text: "", accent: "" });
  const [logoFile, setLogoFile] = useState<File | null>(null);
  const [logoPreview, setLogoPreview] = useState("");
  const [removeLogo, setRemoveLogo] = useState(false);
  const [busy, setBusy] = useState(false);
  const [message, setMessage] = useState<{ tone: "ok" | "error"; text: string } | null>(null);

  // Start from what is saved whenever it changes.
  useEffect(() => {
    setName(branding?.name || "");
    setColors({ bg: branding?.bg || "", text: branding?.text || "", accent: branding?.accent || "" });
    setLogoFile(null);
    setRemoveLogo(false);
  }, [branding]);

  useEffect(() => {
    if (!logoFile) {
      setLogoPreview("");
      return;
    }
    const url = URL.createObjectURL(logoFile);
    setLogoPreview(url);
    return () => URL.revokeObjectURL(url);
  }, [logoFile]);

  const shown = (key: ColorKey) => colors[key] || THEME_COLORS[key];
  const draft: Branding = useMemo(() => ({
    name: name || studioName,
    logo_url: removeLogo ? "" : logoPreview || branding?.logo_url || "",
    ...colors,
  }), [branding?.logo_url, colors, logoPreview, name, removeLogo, studioName]);
  const textContrast = contrast(shown("text"), shown("bg"));
  const accentContrast = contrast(shown("accent"), shown("bg"));

  const pickLogo = (event: ChangeEvent<HTMLInputElement>) => {
    const file = event.target.files?.[0];
    event.currentTarget.value = "";
    if (!file) return;
    if (!LOGO_TYPES.includes(file.type) || file.size > MAX_LOGO_BYTES) {
      setMessage({ tone: "error", text: "Logo phải là PNG, JPG hoặc WebP, tối đa 2MB." });
      return;
    }
    setMessage(null);
    setRemoveLogo(false);
    setLogoFile(file);
  };

  const save = async () => {
    setBusy(true);
    setMessage(null);
    try {
      let saved = (await adminApi<{ branding: Branding }>("/v1/web/branding", {
        method: "PUT",
        body: JSON.stringify({ name: name.trim(), ...colors }),
      })).branding;
      if (logoFile) {
        saved = (await adminApi<{ branding: Branding }>("/v1/web/branding/logo", {
          method: "PUT",
          body: logoFile,
          headers: { "content-type": logoFile.type },
        })).branding;
      } else if (removeLogo && branding?.logo_url) {
        saved = (await adminApi<{ branding: Branding }>("/v1/web/branding/logo", { method: "DELETE" })).branding;
      }
      onSaved(saved);
      setMessage({ tone: "ok", text: "Đã lưu thương hiệu. Trang khách và admin dùng giao diện mới ngay." });
    } catch (err) {
      setMessage({ tone: "error", text: (err as ApiError).message });
    } finally {
      setBusy(false);
    }
  };

  const resetTheme = () => {
    setColors({ bg: "", text: "", accent: "" });
    setMessage(null);
  };

  return (
    <div className="brand-workbench">
      <div className="brand-form">
        <label className="brand-field">
          <span>Tên thương hiệu</span>
          <input maxLength={80} onChange={(event) => setName(event.target.value)} placeholder={studioName} value={name} />
        </label>

        <div className="brand-field">
          <span>Logo</span>
          <div className="brand-logo-row">
            <BrandLogo branding={draft} className="brand-logo-current" name={draft.name} />
            <label className="ghost-action brand-file">
              <ImagePlus size={17} />
              {draft.logo_url ? "Đổi logo" : "Chọn logo"}
              <input accept="image/png,image/jpeg,image/webp" aria-label="Chọn logo" onChange={pickLogo} type="file" />
            </label>
            {draft.logo_url ? (
              <button className="text-action" onClick={() => { setLogoFile(null); setRemoveLogo(true); }} type="button">
                <Trash2 size={16} />Bỏ logo
              </button>
            ) : null}
          </div>
          <small>PNG, JPG hoặc WebP, tối đa 2MB. Nên dùng logo vuông, nền trong suốt.</small>
        </div>

        <div className="brand-colors">
          {COLOR_FIELDS.map((field) => (
            <div className="brand-color" key={field.key}>
              <input
                aria-label={field.label}
                onChange={(event) => setColors((current) => ({ ...current, [field.key]: event.target.value }))}
                type="color"
                value={shown(field.key)}
              />
              <span>
                <strong>{field.label}</strong>
                <small>{colors[field.key] ? shown(field.key).toUpperCase() : `Mặc định · ${field.hint}`}</small>
              </span>
              {colors[field.key] ? (
                <button aria-label={`Về mặc định: ${field.label}`} className="text-action" onClick={() => setColors((current) => ({ ...current, [field.key]: "" }))} type="button">
                  <RotateCcw size={15} />
                </button>
              ) : null}
            </div>
          ))}
        </div>

        <ul className="brand-checks" aria-live="polite">
          <li className={textContrast >= READABLE ? "ok" : "warn"}>
            {textContrast >= READABLE ? <CheckCircle2 size={16} /> : <TriangleAlert size={16} />}
            Chữ trên nền: {textContrast.toFixed(1)}:1 {textContrast >= READABLE ? "· dễ đọc" : "· khó đọc, nên chọn màu chữ đậm/nhạt hơn"}
          </li>
          <li className={accentContrast >= 3 ? "ok" : "warn"}>
            {accentContrast >= 3 ? <CheckCircle2 size={16} /> : <TriangleAlert size={16} />}
            Nút trên nền: {accentContrast.toFixed(1)}:1 {accentContrast >= 3 ? "· nổi rõ" : "· nút chìm vào nền"}
          </li>
        </ul>

        {message ? <p className={`brand-message ${message.tone}`} role="status">{message.text}</p> : null}

        <div className="brand-actions">
          <button className="primary-action" disabled={busy} onClick={save} type="button">
            <CheckCircle2 size={17} />{busy ? "Đang lưu…" : "Lưu thương hiệu"}
          </button>
          <button className="text-action" disabled={busy || (!colors.bg && !colors.text && !colors.accent)} onClick={resetTheme} type="button">
            Về giao diện mặc định
          </button>
        </div>
      </div>

      {/* Phone preview of the guest gallery, painted with the draft colours. */}
      <figure className="brand-preview" aria-label="Xem trước trang ảnh của khách">
        <div className="brand-phone" style={brandStyle(draft)}>
          <div className="bp-steps"><i /><i /><i /><i /><i /><i /></div>
          <div className="bp-header">
            <BrandLogo branding={draft} className="bp-logo" name={draft.name} />
            <span>
              <small>Ảnh của bạn</small>
              <strong>{draft.name}</strong>
            </span>
          </div>
          <div className="bp-actions"><span>Tải ảnh lên</span><span>Tải tất cả</span><span>Ảnh đã ghép</span></div>
          <div className="bp-grid">
            {[0, 1, 2, 3].map((i) => <span key={i} style={{ "--bp-hue": `${i * 70 + 20}` } as CSSProperties} />)}
          </div>
          <div className="bp-bar">
            <span><b>12</b> ảnh</span>
            <em>Chọn frame →</em>
          </div>
        </div>
        <figcaption>Xem trước · trang ảnh của khách</figcaption>
      </figure>
    </div>
  );
}
