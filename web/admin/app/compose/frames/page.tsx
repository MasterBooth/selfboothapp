"use client";

import { ArrowLeft, ArrowRight, Check, Layers3, Loader2, RefreshCw } from "lucide-react";
import { useCallback, useEffect, useMemo, useState } from "react";
import type { CSSProperties } from "react";
import { type ApiError, type FlowContext, type FrameTemplate, FlowSteps, fetchFrames, flowHref, flowParams, readFlowContext } from "../flow";
import { frameGroups } from "../layout";

/** Up to this many frames, each card grows to fill the screen instead of sitting in a dense grid. */
const FEW_FRAMES = 4;

function aspectOf(frame: FrameTemplate) {
  return frame.width && frame.height ? frame.width / frame.height : 4 / 5;
}

function groupsOf(frame: FrameTemplate) {
  return frameGroups(frame.slotRects, aspectOf(frame));
}

/** "8 ô" or, for a frame made of groups, "2 nhóm × 4 ô". */
function frameSummary(frame: FrameTemplate) {
  const { groups, copies } = groupsOf(frame);
  if (groups.length < 2) return `${frame.slots} ô`;
  return copies ? `${groups.length} nhóm × ${groups[0].slots.length} ô` : `${groups.length} nhóm · ${frame.slots} ô`;
}

export default function ComposeFramesPage() {
  const [ctx, setCtx] = useState<FlowContext | null>(null);
  const [frames, setFrames] = useState<FrameTemplate[]>([]);
  const [loading, setLoading] = useState(true);
  const [selectedFrameId, setSelectedFrameId] = useState("");
  const [error, setError] = useState("");

  useEffect(() => {
    const params = new URLSearchParams(window.location.search);
    setCtx(readFlowContext());
    setSelectedFrameId(params.get("frame_id") || "");
  }, []);

  const selectedFrame = useMemo(
    () => frames.find((frame) => frame.frame_id === selectedFrameId) || null,
    [frames, selectedFrameId],
  );

  /** Columns are sized for the widest frame so every frame fits at full height. */
  const widestAspect = useMemo(() => Math.max(0.5, ...frames.map(aspectOf)), [frames]);

  const sessionParams = ctx ? flowParams(ctx) : {};
  const galleryHref = flowHref("/gallery", sessionParams);
  const photosHref = flowHref("/compose/photos", { ...sessionParams, frame_id: selectedFrameId });

  const loadFrames = useCallback(async () => {
    if (!ctx) return;
    setLoading(true);
    setError("");
    try {
      const nextFrames = await fetchFrames(ctx);
      setFrames(nextFrames);
      setSelectedFrameId((current) => nextFrames.some((frame) => frame.frame_id === current) ? current : nextFrames[0]?.frame_id || "");
      if (nextFrames.length === 0) setError("Chưa có frame khả dụng.");
    } catch (err) {
      const apiError = err as ApiError;
      setError(apiError.status === 404 ? "Thư viện frame chưa được kết nối API." : apiError.message);
    } finally {
      setLoading(false);
    }
  }, [ctx]);

  useEffect(() => {
    void loadFrames();
  }, [loadFrames]);

  /**
   * The dense grid shows the small thumbnail (a dozen 1600 px previews would decode to
   * ~80 MB and make a phone stutter); a few large cards still get the sharper preview.
   */
  const few = frames.length <= FEW_FRAMES;
  const cardSrc = (frame: FrameTemplate) => few
    ? frame.preview_url || frame.thumbnail_url
    : frame.thumbnail_url || frame.preview_url;

  const goToPhotos = () => {
    if (!selectedFrame) return;
    window.location.href = photosHref;
  };

  return (
    <main className="compose-shell has-flow-bar">
      <FlowSteps current={1} reach={(index) => index === 0 ? galleryHref : undefined} />

      <header className="compose-header compose-header-row">
        <a className="gallery-icon-button" href={galleryHref} title="Quay lại xem ảnh chụp">
          <ArrowLeft size={18} />
        </a>
        <div className="compose-header-title">
          <h1>Chọn frame</h1>
        </div>
        <button className="gallery-icon-button" disabled={loading} onClick={loadFrames} title="Tải lại danh sách frame" type="button">
          {loading ? <Loader2 className="spin" size={18} /> : <RefreshCw size={18} />}
        </button>
      </header>

      {error ? <div className="inline-message">{error}</div> : null}

      <section className="frame-picker-panel" aria-label="Danh sách frame">
        {loading && frames.length === 0 ? <div className="gallery-frame-status"><Loader2 size={18} /> Đang tải frame</div> : null}

        <div
          className={frames.length > 0 && frames.length <= FEW_FRAMES ? "frame-choice-grid is-few" : "frame-choice-grid"}
          data-count={frames.length}
          style={{ "--frame-aspect": widestAspect } as CSSProperties}
        >
          {frames.map((frame) => {
            const active = frame.frame_id === selectedFrameId;
            return (
              <button
                aria-pressed={active}
                className={active ? "frame-choice-card active" : "frame-choice-card"}
                key={frame.frame_id}
                onClick={() => setSelectedFrameId(frame.frame_id)}
                onDoubleClick={() => { window.location.href = flowHref("/compose/photos", { ...sessionParams, frame_id: frame.frame_id }); }}
                type="button"
              >
                <span className="frame-choice-preview" style={{ "--own-aspect": aspectOf(frame) } as CSSProperties}>
                  {cardSrc(frame) ? (
                    <img alt={frame.name} decoding="async" loading="lazy" src={cardSrc(frame)} />
                  ) : (
                    <Layers3 size={28} />
                  )}
                </span>
                <span className="frame-choice-copy">
                  <strong>{frame.name}</strong>
                  <small>{frameSummary(frame)}</small>
                </span>
                {active ? <Check className="frame-choice-check" size={18} /> : null}
              </button>
            );
          })}
        </div>
      </section>

      <div className="flow-bar">
        <p aria-live="polite" className="flow-pick">
          <strong>{selectedFrame?.name || "Chưa chọn frame"}</strong>
          {selectedFrame ? <span>{frameSummary(selectedFrame)}</span> : null}
        </p>
        <button className="primary-action" disabled={!selectedFrame} onClick={goToPhotos} type="button">
          Chọn ảnh
          <ArrowRight size={18} />
        </button>
      </div>
    </main>
  );
}
