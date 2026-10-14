"use client";

import { Console } from "../admin/Console";

/** Staff portal: username sign-in, sections and buttons limited to what the owner granted. */
export default function StaffPortalPage() {
  return <Console portal="staff" />;
}
