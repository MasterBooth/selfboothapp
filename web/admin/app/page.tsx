"use client";

import { Console } from "./admin/Console";

/** Studio owner admin: signs in with the studio email. Staff use /staff. */
export default function AdminPage() {
  return <Console portal="owner" />;
}
