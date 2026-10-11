// selfboothvn-api — API cho app desktop (và sau này web) trên D1 + R2 `selfboothvn`.
// Hợp đồng đầy đủ: web/D1_REPORT.md.

import { Env, HttpError, corsHeaders, fail, json } from "./http";
import {
  handleLogin, handleLogout, handleMachineRegister, handleMe, handleStudioRegister, requireAdmin,
} from "./auth";
import {
  handleWebLogin, handleWebLogout, handleWebMachineRename, handleWebMachines, handleWebMe,
} from "./webAuth";
import {
  handleWebCaptureAssets,
  handleWebCaptureSessions, handleWebFrameDetail, handleWebFramePreview, handleWebFrames, handleWebFramesBulkDelete,
  handlePublicBookingOptions, handleWebCodeDelete, handleWebCodeRevoke, handleWebCodes, handleWebCodesBulkDelete,
  handleWebPackageDelete, handleWebPackages, handleWebRevenue, handleWebRoomDelete, handleWebRooms,
  handleWebSessionGalleryLink,
} from "./webStudio";
import { handleWebFilterDetail, handleWebFilters } from "./webFilters";
import { handleMachineGalleryLink, handlePublicGallery, handlePublicGalleryUnlock, handlePublicThumbnail } from "./publicGallery";
import { handleWebBranding, handleWebBrandingLogo } from "./branding";
import { handleCustomerLogin, handleCustomerLogout, handleCustomerMe, handleCustomerRegister } from "./customers";
import {
  handlePublicAvailability, handlePublicBookingCreate, handleWebBookingDetail, handleWebBookingSettings, handleWebBookings,
} from "./bookings";
import {
  handleCommitAssets, handleFinalizeAssets, handleMedia, handlePrepareAssets,
  handlePresign, handleReconcileAssets, handleUploadObject,
} from "./upload";
import { handleRevenue, handleSessionUpsert } from "./sync";
import {
  handleAdminCreateCodes, handleAdminListCodes, handleAdminListStudios, handleAdminRevokeCode, handleCheck,
  handleOfflineUses, handleRedeem, handleReusableList,
} from "./codes";
import {
  handleAdminLicenseDelete, handleAdminLicenseHistory, handleAdminLicenseIssue, handleAdminLicenseMachines, handleAdminLicenseOtp,
  handleAdminLicenseRevoke, handleAdminLicenseTransfer, handleLicenseRedeem, handleLicenseRequest,
  handleLicenseStatus,
} from "./license";
import {
  handleMachinePrintClaim, handleMachinePrintHistory, handleMachinePrintJobs, handleMachinePrintPatch, handleMachinePrintReprint,
  handlePublicComposedCreate, handlePublicComposedDelete, handlePublicPrintJobCreate, handlePublicPrintPrepare,
} from "./printJobs";

async function route(req: Request, env: Env, url: URL, ctx: ExecutionContext): Promise<Response> {
  const method = req.method.toUpperCase();
  const path = url.pathname.replace(/\/+$/, "") || "/";
  const seg = path.split("/").filter(Boolean).map(decodeURIComponent);

  if (method === "GET" && path === "/health") return json({ success: true });
  if ((method === "GET" || method === "HEAD") && seg[0] === "media") return handleMedia(req, env, url, ctx);
  if (method === "PUT" && path === "/upload/object") return handleUploadObject(req, env, url);

  if (seg[0] !== "v1") return fail(404, "not_found");
  const p = seg.slice(1);
  const is = (m: string, ...parts: string[]) =>
    method === m && p.length === parts.length && parts.every((x, i) => x === "*" || x === p[i]);

  if ((method === "GET" || method === "HEAD") && p[0] === "media") return handleMedia(req, env, url, ctx);
  if (is("PUT", "upload", "object")) return handleUploadObject(req, env, url);

  // Tài khoản / máy
  if (is("POST", "machines", "register")) return handleMachineRegister(req, env);
  if (is("POST", "studios", "register")) return handleStudioRegister(req, env);
  if (is("POST", "auth", "login")) return handleLogin(req, env);
  if (is("POST", "auth", "logout")) return handleLogout(req, env);
  if (is("GET", "machine", "me")) return handleMe(req, env);

  // Web admin browser session
  if (is("POST", "web", "auth", "login")) return handleWebLogin(req, env);
  if (is("GET", "web", "auth", "me")) return handleWebMe(req, env);
  if (is("POST", "web", "auth", "logout")) return handleWebLogout(req, env);
  if (is("GET", "web", "machines")) return handleWebMachines(req, env);
  if (is("PATCH", "web", "machines", "*")) return handleWebMachineRename(req, env, p[2]);
  if ((method === "GET" || method === "POST") && p.length === 2 && p[0] === "web" && p[1] === "rooms") {
    return handleWebRooms(req, env);
  }
  if ((method === "GET" || method === "POST") && p.length === 2 && p[0] === "web" && p[1] === "packages") {
    return handleWebPackages(req, env);
  }
  if ((method === "GET" || method === "POST") && p.length === 2 && p[0] === "web" && p[1] === "codes") {
    return handleWebCodes(req, env, url);
  }
  if (is("POST", "web", "codes", "*", "revoke")) return handleWebCodeRevoke(req, env, p[2]);
  if (is("POST", "web", "codes", "bulk-delete")) return handleWebCodesBulkDelete(req, env);
  if (is("DELETE", "web", "codes", "*")) return handleWebCodeDelete(req, env, p[2]);
  if (is("DELETE", "web", "rooms", "*")) return handleWebRoomDelete(req, env, p[2]);
  if (is("DELETE", "web", "packages", "*")) return handleWebPackageDelete(req, env, p[2]);
  if ((method === "GET" || method === "POST") && is(method, "web", "frames")) return handleWebFrames(req, env, url);
  if (is("POST", "web", "frames", "bulk-delete")) return handleWebFramesBulkDelete(req, env);
  if (is("PUT", "web", "frames", "*", "preview")) return handleWebFramePreview(req, env, url, p[2]);
  if ((method === "PATCH" || method === "DELETE") && p.length === 3 && p[0] === "web" && p[1] === "frames") {
    return handleWebFrameDetail(req, env, url, p[2]);
  }
  if ((method === "GET" || method === "POST") && is(method, "web", "filters")) return handleWebFilters(req, env, url);
  if ((method === "PATCH" || method === "DELETE") && is(method, "web", "filters", "*")) {
    return handleWebFilterDetail(req, env, url, p[2]);
  }
  if (is("GET", "web", "revenue")) return handleWebRevenue(req, env);
  if (is("GET", "web", "capture-sessions")) return handleWebCaptureSessions(req, env, url);
  if (is("POST", "web", "capture-sessions", "*", "*", "gallery-link")) {
    return handleWebSessionGalleryLink(req, env, url, p[2], p[3]);
  }
  if (is("GET", "web", "capture-sessions", "*", "*", "assets")) {
    return handleWebCaptureAssets(req, env, url, p[2], p[3]);
  }
  if (is("GET", "public", "booking", "options")) return handlePublicBookingOptions(env, url);
  if (is("GET", "public", "gallery", "*")) return handlePublicGallery(req, env, url, p[2], "assets");
  if (is("GET", "public", "gallery", "*", "frames")) return handlePublicGallery(req, env, url, p[2], "frames");
  if (is("GET", "public", "gallery", "*", "filters")) return handlePublicGallery(req, env, url, p[2], "filters");
  if (is("POST", "public", "gallery", "*", "prints", "prepare")) return handlePublicPrintPrepare(req, env, url, p[2]);
  if (is("POST", "public", "gallery", "*", "print-jobs")) return handlePublicPrintJobCreate(req, env, p[2]);
  if (is("POST", "public", "gallery", "*", "composed")) return handlePublicComposedCreate(req, env, p[2]);
  if (is("DELETE", "public", "gallery", "*", "composed", "*")) return handlePublicComposedDelete(req, env, p[2], p[4]);
  if (is("PUT", "public", "gallery", "*", "thumbnails", "*")) return handlePublicThumbnail(req, env, p[2], p[4]);
  if (is("GET", "public", "gallery", "*", "branding")) return handlePublicGallery(req, env, url, p[2], "branding");
  if (is("GET", "public", "booking", "availability")) return handlePublicAvailability(env, url);
  if (is("POST", "public", "booking")) return handlePublicBookingCreate(req, env);
  if (is("POST", "public", "gallery", "*", "unlock")) return handlePublicGalleryUnlock(req, env, p[2]);
  if (is("POST", "public", "customers", "register")) return handleCustomerRegister(req, env);
  if (is("POST", "public", "customers", "login")) return handleCustomerLogin(req, env);
  if (is("POST", "public", "customers", "logout")) return handleCustomerLogout(req, env);
  if (is("GET", "public", "customers", "me")) return handleCustomerMe(req, env, url);

  // Branding + bookings (web admin)
  if ((method === "GET" || method === "PUT") && is(method, "web", "branding")) return handleWebBranding(req, env, url);
  if ((method === "PUT" || method === "DELETE") && is(method, "web", "branding", "logo")) return handleWebBrandingLogo(req, env, url);
  if ((method === "GET" || method === "POST") && is(method, "web", "bookings")) return handleWebBookings(req, env, url);
  if (is("PATCH", "web", "bookings", "*")) return handleWebBookingDetail(req, env, p[2]);
  if ((method === "GET" || method === "PUT") && is(method, "web", "booking-settings")) return handleWebBookingSettings(req, env);

  // Dữ liệu từ máy
  if (is("POST", "uploads", "presign")) return handlePresign(req, env, url);
  if (is("PUT", "machine", "sessions", "*")) return handleSessionUpsert(req, env, p[2]);
  if (is("POST", "machine", "sessions", "*", "assets", "prepare")) return handlePrepareAssets(req, env, url, p[2]);
  if (is("POST", "machine", "sessions", "*", "assets", "commit")) return handleCommitAssets(req, env, p[2]);
  if (is("POST", "machine", "sessions", "*", "finalize")) return handleFinalizeAssets(req, env, p[2]);
  if (is("POST", "machine", "sessions", "*", "gallery-link")) return handleMachineGalleryLink(req, env, url, p[2]);
  if (is("GET", "machine", "sessions", "*", "assets", "reconcile")) return handleReconcileAssets(req, env, p[2]);
  if (is("POST", "machine", "revenue")) return handleRevenue(req, env);
  if (is("POST", "machine", "codes", "check")) return handleCheck(req, env);
  if (is("POST", "machine", "codes", "redeem")) return handleRedeem(req, env);
  if (is("POST", "machine", "codes", "uses")) return handleOfflineUses(req, env);
  if (is("GET", "machine", "codes", "reusable")) return handleReusableList(req, env);
  if (is("GET", "machine", "print-jobs")) return handleMachinePrintJobs(req, env, url);
  if (is("GET", "machine", "print-jobs", "history")) return handleMachinePrintHistory(req, env, url);
  if (is("POST", "machine", "print-jobs", "*", "claim")) return handleMachinePrintClaim(req, env, url, p[2]);
  if (is("POST", "machine", "print-jobs", "*", "reprint")) return handleMachinePrintReprint(req, env, url, p[2]);
  if (is("PATCH", "machine", "print-jobs", "*")) return handleMachinePrintPatch(req, env, p[2]);

  // Giấy phép máy (OTP kích hoạt)
  if (is("POST", "machine", "license", "request")) return handleLicenseRequest(req, env);
  if (is("POST", "machine", "license", "redeem")) return handleLicenseRedeem(req, env);
  if (is("GET", "machine", "license", "status")) return handleLicenseStatus(req, env);

  // Admin
  if (p[0] === "admin") {
    requireAdmin(req, env);
    if (is("GET", "admin", "studios")) return handleAdminListStudios(env);
    if (is("POST", "admin", "studios", "*", "codes")) return handleAdminCreateCodes(req, env, p[2]);
    if (is("GET", "admin", "studios", "*", "codes")) return handleAdminListCodes(env, p[2], url);
    if (is("POST", "admin", "codes", "*", "revoke")) return handleAdminRevokeCode(env, p[2]);
    if (is("GET", "admin", "licenses", "machines")) return handleAdminLicenseMachines(env);
    if (is("DELETE", "admin", "licenses", "machines", "*")) return handleAdminLicenseDelete(env, p[3]);
    if (is("GET", "admin", "licenses", "machines", "*")) return handleAdminLicenseHistory(env, p[3]);
    if (is("POST", "admin", "licenses", "issue")) return handleAdminLicenseIssue(req, env);
    if (is("POST", "admin", "licenses", "otp")) return handleAdminLicenseOtp(req, env);
    if (is("POST", "admin", "licenses", "revoke")) return handleAdminLicenseRevoke(req, env);
    if (is("POST", "admin", "licenses", "transfer")) return handleAdminLicenseTransfer(req, env);
  }
  return fail(404, "not_found");
}

export default {
  async fetch(req: Request, env: Env, ctx: ExecutionContext): Promise<Response> {
    if (req.method === "OPTIONS") return new Response(null, { status: 204, headers: corsHeaders });
    const url = new URL(req.url);
    try {
      return await route(req, env, url, ctx);
    } catch (err) {
      if (err instanceof HttpError) return fail(err.status, err.code, err.message !== err.code ? err.message : undefined);
      console.error("[selfboothvn-api]", req.method, url.pathname, err);
      return fail(500, "internal_error");
    }
  },
};
