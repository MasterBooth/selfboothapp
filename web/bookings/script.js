let rooms = [
  {
    id: "amber",
    name: "Amber Room",
    capacity: "Tối đa 4 người",
    desc: "Ánh sáng mềm, hợp portrait và couple.",
  },
];

let packages = [
  {
    id: "classic",
    roomId: "amber",
    name: "Classic",
    price: 390000,
    note: "20 phút · Gói khởi động",
    minutes: 20,
  },
];

const addons = [
  { id: "print", name: "Thêm bản in", price: 50000, icon: "P" },
  { id: "frame", name: "Frame thiết kế", price: 80000, icon: "F" },
  { id: "touchup", name: "Touch-up 10 phút", price: 120000, icon: "T" },
];

const state = {
  customer: null,
  roomId: rooms[0].id,
  packageId: packages[0].id,
  addons: Object.fromEntries(addons.map((addon) => [addon.id, 0])),
  bookings: [],
};

const currency = new Intl.NumberFormat("vi-VN", {
  style: "currency",
  currency: "VND",
  maximumFractionDigits: 0,
});

function byId(id) {
  return document.getElementById(id);
}

function escapeHtml(value) {
  return String(value ?? "")
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#039;");
}

function formatMoney(value) {
  return currency.format(Number(value || 0)).replace("₫", "d");
}

function normalizeRoom(room) {
  return {
    id: String(room.id),
    name: room.name || "Phòng chụp",
    capacity: room.capacity || "Sẵn sàng nhận lịch",
    desc: room.description || "Chọn phòng này để xem các gói đang mở.",
  };
}

function normalizePackage(pkg) {
  const minutes = Number(pkg.minutes || 0);
  return {
    id: String(pkg.id),
    roomId: String(pkg.room_id || pkg.roomId || ""),
    name: pkg.name || "Gói chụp",
    price: Number(pkg.price_vnd ?? pkg.price ?? 0),
    minutes,
    note: pkg.description || `${minutes} phút`,
  };
}

function packagesForRoom() {
  const filtered = packages.filter((pkg) => pkg.roomId === state.roomId);
  return filtered.length > 0 ? filtered : packages;
}

function selectedRoom() {
  return rooms.find((room) => room.id === state.roomId) || rooms[0];
}

function selectedPackage() {
  return packages.find((pkg) => pkg.id === state.packageId) || packagesForRoom()[0] || packages[0];
}

function ensureSelection() {
  if (!rooms.some((room) => room.id === state.roomId)) {
    state.roomId = rooms[0]?.id || "";
  }
  const visiblePackages = packagesForRoom();
  if (!visiblePackages.some((pkg) => pkg.id === state.packageId)) {
    state.packageId = visiblePackages[0]?.id || "";
  }
}

function addonsTotal() {
  return addons.reduce((sum, addon) => sum + addon.price * state.addons[addon.id], 0);
}

function bookingTotal() {
  return (selectedPackage()?.price || 0) + addonsTotal();
}

function renderChoices() {
  ensureSelection();
  byId("roomChoices").innerHTML = rooms
    .map(
      (room) => `
        <label class="choice ${room.id === state.roomId ? "is-selected" : ""}">
          <input type="radio" name="room" value="${escapeHtml(room.id)}" ${room.id === state.roomId ? "checked" : ""}>
          <span class="choice-top">
            <strong>${escapeHtml(room.name)}</strong>
            <small>${escapeHtml(room.capacity)}</small>
          </span>
          <small>${escapeHtml(room.desc)}</small>
        </label>
      `,
    )
    .join("");

  byId("packageChoices").innerHTML = packagesForRoom()
    .map(
      (pkg) => `
        <label class="choice ${pkg.id === state.packageId ? "is-selected" : ""}">
          <input type="radio" name="package" value="${escapeHtml(pkg.id)}" ${pkg.id === state.packageId ? "checked" : ""}>
          <span class="choice-top">
            <strong>${escapeHtml(pkg.name)}</strong>
            <span class="price">${formatMoney(pkg.price)}</span>
          </span>
          <small>${escapeHtml(pkg.note)}</small>
        </label>
      `,
    )
    .join("");

  byId("addonChoices").innerHTML = addons
    .map(
      (addon) => `
        <div class="addon-row">
          <span class="addon-icon" aria-hidden="true">${escapeHtml(addon.icon)}</span>
          <div class="addon-meta">
            <div class="addon-name">${escapeHtml(addon.name)}</div>
            <small>${formatMoney(addon.price)}</small>
          </div>
          <div class="stepper" aria-label="${escapeHtml(addon.name)}">
            <button type="button" data-addon="${escapeHtml(addon.id)}" data-step="-1" aria-label="Giảm ${escapeHtml(addon.name)}">-</button>
            <span aria-live="polite">${state.addons[addon.id]}</span>
            <button type="button" data-addon="${escapeHtml(addon.id)}" data-step="1" aria-label="Tăng ${escapeHtml(addon.name)}">+</button>
          </div>
        </div>
      `,
    )
    .join("");

  renderReceipt();
}

function renderReceipt() {
  byId("receiptRoom").textContent = selectedRoom()?.name || "Chưa chọn";
  byId("receiptPackage").textContent = selectedPackage()?.name || "Chưa chọn";
  byId("receiptAddons").textContent = formatMoney(addonsTotal());
  byId("receiptTotal").textContent = formatMoney(bookingTotal());
}

function renderDashboard() {
  if (!state.customer) return;
  byId("dashboard").hidden = false;
  byId("customerName").textContent = state.customer.name;
  byId("emptyHistory").hidden = state.bookings.length > 0;
  byId("bookingList").innerHTML = state.bookings
    .map(
      (booking) => `
        <li>
          <strong>${escapeHtml(booking.code)}</strong>
          <span>${escapeHtml(booking.room)} · ${escapeHtml(booking.package)} · ${formatMoney(booking.total)}</span>
          <small>Chờ thanh toán · vừa tạo</small>
        </li>
      `,
    )
    .join("");
}

function createCode() {
  return `VB-${Math.floor(1000 + Math.random() * 9000)}`;
}

async function loadBookingOptions() {
  try {
    const response = await fetch("/v1/public/booking/options", { cache: "no-store" });
    if (!response.ok) return;
    const data = await response.json();
    const nextRooms = Array.isArray(data.rooms) ? data.rooms.map(normalizeRoom) : [];
    const nextPackages = Array.isArray(data.packages) ? data.packages.map(normalizePackage) : [];
    if (nextRooms.length > 0 && nextPackages.length > 0) {
      rooms = nextRooms;
      packages = nextPackages;
      state.roomId = rooms[0].id;
      state.packageId = packagesForRoom()[0]?.id || packages[0].id;
    }
  } catch {
    // Fallback data keeps the page usable while the API is being configured.
  } finally {
    renderChoices();
  }
}

byId("loginForm").addEventListener("submit", (event) => {
  event.preventDefault();
  const phone = byId("phoneInput").value.trim();
  const name = byId("nameInput").value.trim() || "bạn";

  if (!phone) return;
  state.customer = { phone, name };
  renderDashboard();
  byId("dashboard").scrollIntoView({ behavior: "smooth", block: "nearest" });
});

document.addEventListener("change", (event) => {
  const target = event.target;

  if (target.name === "room") {
    state.roomId = target.value;
    ensureSelection();
    renderChoices();
  }

  if (target.name === "package") {
    state.packageId = target.value;
    renderChoices();
  }

  if (target.name === "payment") {
    document.querySelectorAll(".method").forEach((method) => method.classList.remove("is-selected"));
    target.closest(".method").classList.add("is-selected");
  }
});

document.addEventListener("click", (event) => {
  const button = event.target.closest("[data-addon]");
  if (!button) return;

  const addonId = button.dataset.addon;
  const step = Number(button.dataset.step);
  state.addons[addonId] = Math.max(0, state.addons[addonId] + step);
  renderChoices();
});

byId("bookingForm").addEventListener("submit", (event) => {
  event.preventDefault();
  if (!selectedRoom() || !selectedPackage()) return;

  const booking = {
    code: createCode(),
    room: selectedRoom().name,
    package: selectedPackage().name,
    total: bookingTotal(),
  };

  state.bookings.unshift(booking);
  byId("confirmCode").textContent = booking.code;
  byId("confirmMeta").textContent = `${booking.room} · ${booking.package} · ${formatMoney(booking.total)}`;
  byId("confirmation").hidden = false;
  renderDashboard();
  byId("confirmation").scrollIntoView({ behavior: "smooth", block: "start" });
});

loadBookingOptions();
