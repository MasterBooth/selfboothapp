.pragma library

// ========================================================================
// Dynamic Exposure Triangle Controller
// Uses ACTUAL camera property lists from Canon EDSDK API
//
// Nguyên lý Tam Giác Phơi Sáng (Exposure Triangle):
//   Shutter Speed  ↔  Aperture (F)  ↔  ISO
//
// Tăng sáng: Shutter (chậm lại) → Aperture (mở khẩu) → ISO (tăng)
// Giảm sáng: ISO (giảm) → Shutter (nhanh lên) → Aperture (khép khẩu)
// ========================================================================

// --- Safety thresholds (chụp tay) ---
var SHUTTER_SLOWEST_SECONDS = 1.0 / 100;  // Không chậm hơn 1/100s
var APERTURE_WIDEST_FNUM    = 5.0;         // Không mở rộng hơn f/5

// -----------------------------------------------------------------------
// Parsing helpers
// -----------------------------------------------------------------------

// "1/125" → 0.008,  "1/60" → 0.01667,  "2" → 2.0,  "0\"5" → 0.5
function parseShutterToSeconds(str) {
    if (!str) return -1;
    str = str.toString().trim();

    // Fraction: "1/125"
    var m = str.match(/^(\d+)\/(\d+)$/);
    if (m) return parseInt(m[1]) / parseInt(m[2]);

    // Long exposure notation: "1\"6" = 1.6s, "0\"5" = 0.5s
    var q = str.match(/^(\d+)"(\d+)$/);
    if (q) return parseInt(q[1]) + parseInt(q[2]) / 10.0;

    // Plain seconds: "2", "30", "0.5"
    var v = parseFloat(str);
    return isNaN(v) ? -1 : v;
}

// "5.6" → 5.6,  "f/5.6" → 5.6,  "F5.6" → 5.6
function parseApertureToFnum(str) {
    if (!str) return -1;
    str = str.toString().replace(/^[fF]\/?\s*/, "").trim();
    var v = parseFloat(str);
    return isNaN(v) ? -1 : v;
}

// "200" → 200
function parseISOToNumber(str) {
    if (!str) return -1;
    var v = parseInt(str.toString().trim());
    return isNaN(v) ? -1 : v;
}

// -----------------------------------------------------------------------
// Build sorted index arrays from API lists
// All arrays sorted: index 0 = darkest,  last = brightest
// -----------------------------------------------------------------------

// Sorted fastest → slowest  (darkest → brightest)
function buildShutterIndex(rawList) {
    var arr = [];
    for (var i = 0; i < rawList.length; i++) {
        var s = parseShutterToSeconds(rawList[i]);
        if (s > 0) arr.push({ value: rawList[i], seconds: s });
    }
    arr.sort(function(a, b) { return a.seconds - b.seconds; });
    return arr;
}

// Sorted most-closed → most-open  (darkest → brightest)
// f/22 → f/16 → f/11 → f/8 → f/5.6 → f/5 → f/4 → ...
function buildApertureIndex(rawList) {
    var arr = [];
    for (var i = 0; i < rawList.length; i++) {
        var f = parseApertureToFnum(rawList[i]);
        if (f > 0) arr.push({ value: rawList[i], fnum: f });
    }
    arr.sort(function(a, b) { return b.fnum - a.fnum; });   // descending f-number
    return arr;
}

// Sorted lowest → highest  (darkest → brightest)
function buildISOIndex(rawList) {
    var arr = [];
    for (var i = 0; i < rawList.length; i++) {
        var n = parseISOToNumber(rawList[i]);
        if (n > 0) arr.push({ value: rawList[i], iso: n });
    }
    arr.sort(function(a, b) { return a.iso - b.iso; });
    return arr;
}

// -----------------------------------------------------------------------
// Find current value position in sorted array
// -----------------------------------------------------------------------

function findInSorted(sorted, current, parseFunc, numericKey) {
    if (!current) return -1;
    var cv = current.toString().trim();

    // 1. Exact string match
    for (var i = 0; i < sorted.length; i++) {
        if (sorted[i].value === cv) return i;
    }

    // 2. Stripped match (e.g., "f/5.6" vs "5.6")
    var stripped = cv.replace(/^[fF]\/?\s*/, "").trim();
    for (var k = 0; k < sorted.length; k++) {
        if (sorted[k].value === stripped) return k;
    }

    // 3. Closest numeric match
    var parsed = parseFunc(cv);
    if (parsed <= 0) return -1;

    var best = -1, bestDiff = Infinity;
    for (var j = 0; j < sorted.length; j++) {
        var diff = Math.abs(sorted[j][numericKey] - parsed);
        if (diff < bestDiff) { bestDiff = diff; best = j; }
    }
    return best;
}

// -----------------------------------------------------------------------
// CORE: Exposure Triangle Logic
// -----------------------------------------------------------------------

// Tăng sáng (ảnh bị tối)
// Ưu tiên: Shutter Speed (chậm lại) → Aperture (mở khẩu) → ISO (tăng)
//
// Params:
//   currentShutter, currentAperture, currentIso  – giá trị hiện tại (string)
//   shutterList, apertureList, isoList            – QStringList từ cameraController
//
// Returns: { param: "shutter"|"aperture"|"iso", value: string } hoặc null

function increaseExposure(currentShutter, currentAperture, currentIso,
                          shutterList, apertureList, isoList) {
    var ss = buildShutterIndex(shutterList || []);
    var ap = buildApertureIndex(apertureList || []);
    var iso = buildISOIndex(isoList || []);

    var si = findInSorted(ss, currentShutter, parseShutterToSeconds, "seconds");
    var ai = findInSorted(ap, currentAperture, parseApertureToFnum, "fnum");
    var ii = findInSorted(iso, currentIso, parseISOToNumber, "iso");

    // 1. Chậm shutter (tăng index) – giới hạn ≤ 1/100s
    if (si >= 0 && si < ss.length - 1) {
        var nextS = ss[si + 1];
        if (nextS.seconds <= SHUTTER_SLOWEST_SECONDS) {
            return { param: "shutter", value: nextS.value };
        }
    }

    // 2. Mở khẩu độ (tăng index) – giới hạn ≥ f/5
    if (ai >= 0 && ai < ap.length - 1) {
        var nextA = ap[ai + 1];
        if (nextA.fnum >= APERTURE_WIDEST_FNUM) {
            return { param: "aperture", value: nextA.value };
        }
    }

    // 3. Tăng ISO (tăng index)
    if (ii >= 0 && ii < iso.length - 1) {
        return { param: "iso", value: iso[ii + 1].value };
    }

    return null; // Đã đạt giới hạn tối đa
}


// Giảm sáng (ảnh bị dư sáng)
// Ưu tiên: ISO (giảm) → Shutter Speed (nhanh lên) → Aperture (khép khẩu)

function decreaseExposure(currentShutter, currentAperture, currentIso,
                          shutterList, apertureList, isoList) {
    var ss = buildShutterIndex(shutterList || []);
    var ap = buildApertureIndex(apertureList || []);
    var iso = buildISOIndex(isoList || []);

    var si = findInSorted(ss, currentShutter, parseShutterToSeconds, "seconds");
    var ai = findInSorted(ap, currentAperture, parseApertureToFnum, "fnum");
    var ii = findInSorted(iso, currentIso, parseISOToNumber, "iso");

    // 1. Giảm ISO (giảm index) – ưu tiên về 100
    if (ii > 0) {
        return { param: "iso", value: iso[ii - 1].value };
    }

    // 2. Nhanh shutter (giảm index)
    if (si > 0) {
        return { param: "shutter", value: ss[si - 1].value };
    }

    // 3. Khép khẩu độ (giảm index = f-number lớn hơn)
    if (ai > 0) {
        return { param: "aperture", value: ap[ai - 1].value };
    }

    return null; // Đã đạt giới hạn tối thiểu
}
