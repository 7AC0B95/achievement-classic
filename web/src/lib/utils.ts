export function cn(...parts: Array<string | false | null | undefined>) {
  return parts.filter(Boolean).join(" ");
}

export function formatPoints(points: number) {
  return new Intl.NumberFormat("en-US").format(points);
}

function asDate(isoOrDate: string | Date) {
  return isoOrDate instanceof Date ? isoOrDate : new Date(isoOrDate);
}

export function formatDateTime(isoOrDate: string | Date) {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "short",
    timeStyle: "medium",
  }).format(asDate(isoOrDate));
}

export function formatDate(isoOrDate: string | Date) {
  return new Intl.DateTimeFormat("en-US", {
    dateStyle: "short",
  }).format(asDate(isoOrDate));
}

export function formatTime(isoOrDate: string | Date) {
  return new Intl.DateTimeFormat("en-US", {
    timeStyle: "medium",
  }).format(asDate(isoOrDate));
}

export function formatRelativeTime(isoOrUnix: string | number) {
  const date =
    typeof isoOrUnix === "number"
      ? new Date(isoOrUnix * 1000)
      : new Date(isoOrUnix);
  const diffMs = date.getTime() - Date.now();
  const abs = Math.abs(diffMs);
  const minutes = Math.round(abs / 60_000);
  const hours = Math.round(abs / 3_600_000);
  const days = Math.round(abs / 86_400_000);
  const rtf = new Intl.RelativeTimeFormat("en", { numeric: "auto" });

  if (minutes < 60) return rtf.format(Math.sign(diffMs) * minutes, "minute");
  if (hours < 48) return rtf.format(Math.sign(diffMs) * hours, "hour");
  return rtf.format(Math.sign(diffMs) * days, "day");
}
