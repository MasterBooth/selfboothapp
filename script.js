const rooms = [
  {
    id: "amber",
    name: "Amber Room",
    capacity: "Tối đa 4 người",
    desc: "Ánh sáng mềm, hợp portrait và couple.",
  },
  {
    id: "flash",
    name: "Flash Room",
    capacity: "Tối đa 6 người",
    desc: "Đèn trực diện, hợp nhóm bạn và sinh nhật.",
  },
];

const packages = [
  { id: "classic", name: "Classic", price: 390000, note: "20 phút · 8 ảnh gốc · 2 bản in" },
  { id: "signature", name: "Signature", price: 590000, note: "35 phút · 16 ảnh gốc · 4 bản in" },
  { id: "party", name: "Party", price: 890000, note: "50 phút · all file · 8 bản in" },
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

function formatMoney(value) {
  return currency.format(value).replace("₫", "d");
}

function selectedRoom() {
  return rooms.find((room) => room.id === state.roomId);
}

function selectedPackage() {
  return packages.find((pkg) => pkg.id === state.packageId);
}

function addonsTotal() {
  return addons.reduce((sum, addon) => sum + addon.price * state.addons[addon.id], 0);
}

function bookingTotal() {
  return selectedPackage().price + addonsTotal();
}

function renderChoices() {
  byId("roomChoices").innerHTML = rooms
    .map(
      (room) => `
        <label class="choice ${room.id === state.roomId ? "is-selected" : ""}">
          <input type="radio" name="room" value="${room.id}" ${room.id === state.roomId ? "checked" : ""}>
          <span class="choice-top">
            <strong>${room.name}</strong>
            <small>${room.capacity}</small>
          </span>
          <small>${room.desc}</small>
        </label>
      `,
    )
    .join("");

  byId("packageChoices").innerHTML = packages
    .map(
      (pkg) => `
        <label class="choice ${pkg.id === state.packageId ? "is-selected" : ""}">
          <input type="radio" name="package" value="${pkg.id}" ${pkg.id === state.packageId ? "checked" : ""}>
          <span class="choice-top">
            <strong>${pkg.name}</strong>
            <span class="price">${formatMoney(pkg.price)}</span>
          </span>
          <small>${pkg.note}</small>
        </label>
      `,
    )
    .join("");

  byId("addonChoices").innerHTML = addons
    .map(
      (addon) => `
        <div class="addon-row">
          <span class="addon-icon" aria-hidden="true">${addon.icon}</span>
          <div class="addon-meta">
            <div class="addon-name">${addon.name}</div>
            <small>${formatMoney(addon.price)}</small>
          </div>
          <div class="stepper" aria-label="${addon.name}">
            <button type="button" data-addon="${addon.id}" data-step="-1" aria-label="Giảm ${addon.name}">-</button>
            <span aria-live="polite">${state.addons[addon.id]}</span>
            <button type="button" data-addon="${addon.id}" data-step="1" aria-label="Tăng ${addon.name}">+</button>
          </div>
        </div>
      `,
    )
    .join("");

  renderReceipt();
}

function renderReceipt() {
  byId("receiptRoom").textContent = selectedRoom().name;
  byId("receiptPackage").textContent = selectedPackage().name;
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
          <strong>${booking.code}</strong>
          <span>${booking.room} · ${booking.package} · ${formatMoney(booking.total)}</span>
          <small>Chờ thanh toán · vừa tạo</small>
        </li>
      `,
    )
    .join("");
}

function createCode() {
  return `VB-${Math.floor(1000 + Math.random() * 9000)}`;
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

renderChoices();
