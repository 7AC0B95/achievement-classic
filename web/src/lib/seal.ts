/**
 * Tamper-evident ink for Classic Glory SavedVariables.
 * Must stay byte-for-byte compatible with ClassicGlory/Seal.lua.
 *
 * Mix hashes UTF-8 bytes (Lua string.byte). Not cryptographic security.
 *
 * Test vectors:
 *   mix32("abc", 1) === 144903
 *   ticketPayload("Player-4408-0B2C3D4E", 1001, 1722900000, 2)
 *     === "v1|Player-4408-0B2C3D4E|1001|1722900000|2"
 *   makeTicket(...) === "v1:f4864afb0330afb0"
 */

const MOD = 4294967296;
const VERSION = "v1";

const FRAG_A = [0x51f3a91c, 0x0b7c22e5, 0x6d14c083, 0x9a2e17d4];
const FRAG_B = [0x3c08f6b1, 0xe5d40a27, 0xc61a7b0e, 0x47b8d192];

export type SealCompletion = {
  id: string | number;
  earnedOn: number;
  lvl: number;
  ticket: string;
};

export type SealSnapshot = {
  guid: string;
  level: number;
  class: string;
  race: string;
  faction: string;
  status: "Alive" | "Dead";
  deaths: number;
  completed: SealCompletion[];
  visitedZones: string[];
  visitedInstances: string[];
  /** Sparse criteria counters: achievement id -> index -> value */
  progress: Record<string, Record<string, number>>;
};

function u32(n: number): number {
  n = Number(n) || 0;
  n %= MOD;
  if (n < 0) n += MOD;
  return n;
}

function seeds(): [number, number, number, number] {
  return [
    u32(FRAG_A[0]! ^ FRAG_B[0]!),
    u32(FRAG_A[1]! ^ FRAG_B[1]!),
    u32(FRAG_A[2]! ^ FRAG_B[2]!),
    u32(FRAG_A[3]! ^ FRAG_B[3]!),
  ];
}

function utf8Bytes(str: string): Uint8Array {
  return new TextEncoder().encode(str);
}

/** 32-bit djb2-like mix: (h * 33 + b) % 2^32 over UTF-8 bytes. */
export function mix32(str: string, seed: number): number {
  let h = u32(seed);
  const bytes = utf8Bytes(str ?? "");
  for (let i = 0; i < bytes.length; i += 1) {
    h = u32(h * 33 + bytes[i]!);
  }
  return h;
}

function hex8(n: number): string {
  return u32(n).toString(16).padStart(8, "0");
}

function ink64(str: string, s1: number, s2: number): string {
  return hex8(mix32(str, s1)) + hex8(mix32(str, s2));
}

function intstr(n: unknown): string {
  const v = Number(n);
  if (!Number.isFinite(v)) return "0";
  return String(Math.floor(v));
}

export function ticketPayload(
  guid: string,
  id: string | number,
  earnedOn: number,
  lvl: number,
): string {
  return [VERSION, guid ?? "", intstr(id), intstr(earnedOn), intstr(lvl)].join(
    "|",
  );
}

export function makeTicket(
  guid: string,
  id: string | number,
  earnedOn: number,
  lvl: number,
): string {
  const s = seeds();
  return `${VERSION}:${ink64(ticketPayload(guid, id, earnedOn, lvl), s[0], s[1])}`;
}

function sortedTruthyKeys(keys: string[]): string {
  return keys
    .map((k) => String(k).toLowerCase())
    .filter(Boolean)
    .sort((a, b) => (a < b ? -1 : a > b ? 1 : 0))
    .join(",");
}

function progressParts(progress: SealSnapshot["progress"]): string {
  const pids = Object.keys(progress ?? {})
    .map((id) => Number(id))
    .filter((n) => Number.isFinite(n))
    .sort((a, b) => a - b);

  const parts: string[] = [];
  for (const id of pids) {
    const row = progress[String(id)] ?? progress[id as unknown as string];
    if (!row || typeof row !== "object") continue;
    const idxs = Object.keys(row)
      .map((idx) => Number(idx))
      .filter((n) => Number.isFinite(n) && Number.isFinite(Number(row[String(n)])))
      .sort((a, b) => a - b);
    for (const idx of idxs) {
      const val = row[String(idx)] ?? row[idx as unknown as string];
      parts.push(`${id}.${idx}=${intstr(val)}`);
    }
  }
  return parts.join(",");
}

export function canonicalCharacter(snap: SealSnapshot): string {
  const ids = snap.completed
    .map((c) => Number(c.id))
    .filter((n) => Number.isFinite(n))
    .sort((a, b) => a - b);

  const byId = new Map<number, SealCompletion>();
  for (const c of snap.completed) {
    const n = Number(c.id);
    if (Number.isFinite(n)) byId.set(n, c);
  }

  const cparts: string[] = [];
  for (const id of ids) {
    const e = byId.get(id);
    if (!e) continue;
    cparts.push(
      `${id}:${intstr(e.earnedOn)}:${intstr(e.lvl)}:${e.ticket ?? ""}`,
    );
  }

  const status = snap.status === "Dead" ? "Dead" : "Alive";
  return [
    VERSION,
    snap.guid ?? "",
    intstr(snap.level),
    snap.class ?? "",
    snap.race ?? "",
    snap.faction ?? "",
    status,
    intstr(snap.deaths),
    cparts.join(","),
    sortedTruthyKeys(snap.visitedZones ?? []),
    sortedTruthyKeys(snap.visitedInstances ?? []),
    progressParts(snap.progress ?? {}),
  ].join("|");
}

export function computeSeal(snap: SealSnapshot): string {
  const s = seeds();
  return `${VERSION}:${ink64(canonicalCharacter(snap), s[2], s[3])}`;
}

export function ticketsMatch(snap: SealSnapshot): boolean {
  const guid = snap.guid ?? "";
  for (const c of snap.completed) {
    const want = makeTicket(guid, c.id, c.earnedOn, c.lvl);
    if ((c.ticket ?? "") !== want) return false;
  }
  return true;
}

export function verifySeal(snap: SealSnapshot, seal: string | undefined): boolean {
  if (!seal) return false;
  if (!ticketsMatch(snap)) return false;
  return seal === computeSeal(snap);
}
