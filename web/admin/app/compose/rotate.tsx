"use client";

import { RotateCw } from "lucide-react";
import { useRef } from "react";
import type { KeyboardEvent, PointerEvent } from "react";
import { normalizeAngle } from "./layout";

/** Within this many degrees of 0 / 90 / 180 / 270 the dial clicks onto the right angle. */
const SNAP_DEGREES = 4;

function snap(angle: number) {
  const right = Math.round(angle / 90) * 90;
  return Math.abs(angle - right) <= SNAP_DEGREES ? normalizeAngle(right) : Math.round(angle);
}

/**
 * Turn the photo by holding the knob and dragging it around the dial: the photo
 * follows the finger, any angle, clicking onto the right angles. Arrow keys nudge
 * 1° (Shift: 15°).
 */
export function RotateDial({ value, onChange }: { value: number; onChange: (degrees: number) => void }) {
  const ref = useRef<HTMLDivElement | null>(null);
  const drag = useRef<{ id: number; last: number; angle: number } | null>(null);

  const pointerAngle = (event: PointerEvent<HTMLDivElement>) => {
    const box = ref.current!.getBoundingClientRect();
    // 0° at the top, clockwise, like the photo's rotation.
    return (Math.atan2(event.clientY - (box.top + box.height / 2), event.clientX - (box.left + box.width / 2)) * 180) / Math.PI + 90;
  };

  const onPointerDown = (event: PointerEvent<HTMLDivElement>) => {
    event.preventDefault();
    event.currentTarget.setPointerCapture(event.pointerId);
    drag.current = { id: event.pointerId, last: pointerAngle(event), angle: value };
  };

  const onPointerMove = (event: PointerEvent<HTMLDivElement>) => {
    const active = drag.current;
    if (!active || active.id !== event.pointerId) return;
    const now = pointerAngle(event);
    // Add the small step since the last move, so crossing ±180° never jumps.
    active.angle += normalizeAngle(now - active.last);
    active.last = now;
    onChange(snap(normalizeAngle(active.angle)));
  };

  const onPointerEnd = (event: PointerEvent<HTMLDivElement>) => {
    if (drag.current?.id === event.pointerId) drag.current = null;
  };

  const onKeyDown = (event: KeyboardEvent<HTMLDivElement>) => {
    const step = event.shiftKey ? 15 : 1;
    if (event.key === "ArrowRight" || event.key === "ArrowUp") onChange(normalizeAngle(value + step));
    else if (event.key === "ArrowLeft" || event.key === "ArrowDown") onChange(normalizeAngle(value - step));
    else if (event.key === "Home") onChange(0);
    else return;
    event.preventDefault();
  };

  return (
    <div
      aria-label="Góc xoay ảnh"
      aria-valuemax={180}
      aria-valuemin={-180}
      aria-valuenow={Math.round(value)}
      aria-valuetext={`${Math.round(value)} độ`}
      className="rotate-dial"
      onKeyDown={onKeyDown}
      onPointerCancel={onPointerEnd}
      onPointerDown={onPointerDown}
      onPointerMove={onPointerMove}
      onPointerUp={onPointerEnd}
      ref={ref}
      role="slider"
      tabIndex={0}
    >
      <span aria-hidden="true" className="rotate-dial-ticks" />
      <span aria-hidden="true" className="rotate-dial-arm" style={{ transform: `rotate(${value}deg)` }}>
        <i><RotateCw size={16} strokeWidth={2.5} /></i>
      </span>
      <strong>{Math.round(value)}°</strong>
    </div>
  );
}
