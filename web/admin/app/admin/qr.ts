/** QR helpers shared by the booking page QR and the per-session album QR. */

import qrcode from "qrcode-generator";

/** QR of `text` as an SVG path of dark modules (quiet zone included). */
export function qrPath(text: string) {
  const qr = qrcode(0, "M");
  qr.addData(text);
  qr.make();
  const count = qr.getModuleCount();
  const quiet = 4;
  let d = "";
  for (let r = 0; r < count; r++) {
    for (let c = 0; c < count; c++) if (qr.isDark(r, c)) d += `M${c + quiet} ${r + quiet}h1v1h-1z`;
  }
  return { d, size: count + quiet * 2, qr, count, quiet };
}

/** A print-ready PNG: QR on white, a title and a call to action under it. */
export function downloadQr(text: string, title: string, caption: string, fileName: string) {
  const { qr, count, quiet } = qrPath(text);
  const cell = Math.floor(1000 / (count + quiet * 2));
  const side = cell * (count + quiet * 2);
  const canvas = document.createElement("canvas");
  canvas.width = side;
  canvas.height = side + 170;
  const ctx = canvas.getContext("2d");
  if (!ctx) return;
  ctx.fillStyle = "#ffffff";
  ctx.fillRect(0, 0, canvas.width, canvas.height);
  ctx.fillStyle = "#111111";
  for (let r = 0; r < count; r++) {
    for (let c = 0; c < count; c++) if (qr.isDark(r, c)) ctx.fillRect((c + quiet) * cell, (r + quiet) * cell, cell, cell);
  }
  ctx.textAlign = "center";
  ctx.font = "700 54px system-ui, sans-serif";
  ctx.fillText(title, side / 2, side + 60);
  ctx.font = "500 40px system-ui, sans-serif";
  ctx.fillStyle = "#444444";
  ctx.fillText(caption, side / 2, side + 125);
  canvas.toBlob((blob) => {
    if (!blob) return;
    const url = URL.createObjectURL(blob);
    const a = document.createElement("a");
    a.href = url;
    a.download = fileName;
    a.click();
    window.setTimeout(() => URL.revokeObjectURL(url), 2000);
  }, "image/png");
}

/**
 * Copies text that may still be loading. Safari only allows a clipboard write started
 * inside the tap, so it gets the pending text; other browsers fall back to writeText.
 */
export async function copyPending(text: Promise<string>) {
  if (typeof ClipboardItem !== "undefined" && navigator.clipboard?.write) {
    try {
      await navigator.clipboard.write([new ClipboardItem({ "text/plain": text.then((value) => new Blob([value], { type: "text/plain" })) })]);
      return;
    } catch {
      // Fall through: some browsers reject a pending ClipboardItem.
    }
  }
  await navigator.clipboard.writeText(await text);
}
