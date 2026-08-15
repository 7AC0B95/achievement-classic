import { ACHIEVEMENT_RULES } from "./achievement-rules";
import { getAchievementById } from "./achievements";
import { verifySeal, type SealSnapshot } from "./seal";
import type { SyncPayload } from "./types";

const UNSIGNED_MESSAGE =
  "This file was not written by Classic Glory. Update the addon to 0.6.0, log in once, log out, then upload.";

const CLOCK_SKEW_SEC = 86400;

function nameMatches(haystack: string, needle: string): boolean {
  if (!needle) return true;
  return haystack.toLowerCase().includes(needle.toLowerCase());
}

function normalizeToken(s: string): string {
  return s.replace(/\s+/g, "").toUpperCase();
}

function progressAt(
  snapshot: SealSnapshot,
  id: string,
  index: number,
): number | undefined {
  const row = snapshot.progress[id] ?? snapshot.progress[String(Number(id))];
  if (!row) return undefined;
  const v = row[String(index)];
  if (v == null) return undefined;
  const n = Number(v);
  return Number.isFinite(n) ? n : undefined;
}

function auditCriteria(snapshot: SealSnapshot, id: string): string | null {
  const rule = ACHIEVEMENT_RULES[id];
  if (!rule) return `Unknown achievement ${id} cannot be published.`;

  if (
    rule.factionOnly &&
    (snapshot.faction || "").toLowerCase() !== rule.factionOnly.toLowerCase()
  ) {
    return `Achievement ${id} is not available to this character's faction.`;
  }

  const entry = snapshot.completed.find((c) => String(c.id) === id);
  const earnedLevel = entry?.lvl ?? 0;
  const completedIds = snapshot.completed.map((c) => String(c.id));

  for (let i = 0; i < rule.criteria.length; i += 1) {
    const crit = rule.criteria[i]!;
    const idx = i + 1;
    const have = progressAt(snapshot, id, idx);

    switch (crit.type) {
      case "LEVEL":
        if (snapshot.level < crit.value || earnedLevel < crit.value) {
          return `Achievement ${id} requires level ${crit.value}.`;
        }
        break;
      case "DEATHLESS":
        // Earned before death and kept after; the addon will not grant these
        // once deaths > 0. Do not reject a later hardcore death on sync.
        if (snapshot.level < crit.value || earnedLevel < crit.value) {
          return `Achievement ${id} requires reaching level ${crit.value} without dying.`;
        }
        break;
      case "CLASS":
        if (
          crit.match &&
          normalizeToken(snapshot.class) !== normalizeToken(crit.match)
        ) {
          return `Achievement ${id} does not match this character's class.`;
        }
        break;
      case "RACE":
        if (
          crit.match &&
          normalizeToken(snapshot.race) !== normalizeToken(crit.match)
        ) {
          return `Achievement ${id} does not match this character's race.`;
        }
        break;
      case "FACTION":
        if (
          crit.match &&
          snapshot.faction.toLowerCase() !== crit.match.toLowerCase()
        ) {
          return `Achievement ${id} does not match this character's faction.`;
        }
        break;
      case "ZONE":
        if (
          crit.match &&
          !snapshot.visitedZones.some((z) => nameMatches(z, crit.match!))
        ) {
          return `Achievement ${id} requires visiting ${crit.match}.`;
        }
        break;
      case "ZONES":
        if (snapshot.visitedZones.length < crit.value) {
          return `Achievement ${id} requires ${crit.value} zones visited.`;
        }
        break;
      case "INSTANCE":
        if (crit.match) {
          if (
            !snapshot.visitedInstances.some((z) => nameMatches(z, crit.match!))
          ) {
            return `Achievement ${id} requires entering ${crit.match}.`;
          }
        } else if (snapshot.visitedInstances.length < crit.value) {
          return `Achievement ${id} requires ${crit.value} dungeons or raids.`;
        }
        break;
      case "META": {
        const others = completedIds.filter((other) => other !== id).length;
        if (others < crit.value) {
          return `Achievement ${id} requires ${crit.value} other achievements.`;
        }
        break;
      }
      default:
        break;
    }

    if (have != null && have < crit.value) {
      return `Achievement ${id} progress does not meet its criteria.`;
    }
  }

  return null;
}

function auditRate(snapshot: SealSnapshot): string | null {
  const times = snapshot.completed
    .map((c) => Math.floor(Number(c.earnedOn) || 0))
    .filter((t) => t > 0)
    .sort((a, b) => a - b);
  if (times.length < 30) return null;

  const counts = new Map<number, number>();
  for (const t of times) {
    counts.set(t, (counts.get(t) ?? 0) + 1);
  }
  let peak = 0;
  for (const n of counts.values()) {
    if (n > peak) peak = n;
  }
  if (peak >= 30) {
    return "Too many achievements share the same unlock time.";
  }

  if (times.length >= 50 && times[times.length - 1]! - times[0]! < 60) {
    return "Too many achievements unlocked in too little time.";
  }
  return null;
}

/** Returns an error message, or null if the payload is acceptable. */
export function validateSyncPayload(payload: SyncPayload): string | null {
  const seal = payload.seal ?? payload.character.seal;
  const snapshot = payload.snapshot;
  if (!seal || !snapshot) {
    return UNSIGNED_MESSAGE;
  }

  if (!snapshot.guid) {
    return UNSIGNED_MESSAGE;
  }

  if (!verifySeal(snapshot, seal)) {
    return UNSIGNED_MESSAGE;
  }

  const now = Math.floor(Date.now() / 1000);
  const level = snapshot.level;

  if (level < 1 || level > 60) {
    return "Character level in the addon file is not plausible.";
  }

  for (const entry of snapshot.completed) {
    const id = String(entry.id);
    if (!getAchievementById(id)) {
      return `Unknown achievement ${id} cannot be published.`;
    }
    const earnedOn = Math.floor(Number(entry.earnedOn) || 0);
    if (earnedOn <= 0) {
      return `Achievement ${id} is missing an unlock time.`;
    }
    if (earnedOn > now + CLOCK_SKEW_SEC) {
      return `Achievement ${id} has an unlock time in the future.`;
    }
    const lvl = Math.floor(Number(entry.lvl) || 0);
    if (lvl < 1 || lvl > 60 || lvl > level) {
      return `Achievement ${id} was earned at an implausible level.`;
    }
    if (!entry.ticket) {
      return UNSIGNED_MESSAGE;
    }
    const critErr = auditCriteria(snapshot, id);
    if (critErr) return critErr;
  }

  return auditRate(snapshot);
}
