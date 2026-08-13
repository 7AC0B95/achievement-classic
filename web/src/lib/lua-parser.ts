import type {
  HardcoreStatus,
  ParsedCharacterBundle,
  ParsedCompletedAchievement,
  ParsedClassicGloryDB,
  ParsedStats,
} from "@/lib/types";

/**
 * Parses WoW SavedVariables Lua for ClassicGloryDB (account-wide) into typed JSON.
 * Also accepts leftover LaucobsAchievementsDB from the previous addon name.
 */
export function parseClassicGloryDB(luaText: string): ParsedClassicGloryDB {
  const assignment =
    extractTableAssignment(luaText, "ClassicGloryDB") ??
    extractTableAssignment(luaText, "LaucobsAchievementsDB");
  if (!assignment) {
    throw new Error(
      "ClassicGloryDB not found in file. Is the addon installed and has it saved once (log out)?",
    );
  }

  const root = parseLuaTable(assignment);
  if (!root || typeof root !== "object" || Array.isArray(root)) {
    throw new Error("ClassicGloryDB is not a table.");
  }

  const charactersRaw = (root.characters ?? {}) as Record<string, unknown>;
  const characters: ParsedCharacterBundle[] = [];

  for (const [key, value] of Object.entries(charactersRaw)) {
    if (!value || typeof value !== "object" || Array.isArray(value)) continue;
    characters.push(parseCharacterRow(key, value as Record<string, unknown>));
  }

  characters.sort((a, b) => {
    const realmCmp = a.character.realm.localeCompare(b.character.realm);
    if (realmCmp !== 0) return realmCmp;
    return a.character.name.localeCompare(b.character.name);
  });

  return {
    version: Number(root.version ?? 1),
    characters,
  };
}

function parseCharacterRow(
  key: string,
  raw: Record<string, unknown>,
): ParsedCharacterBundle {
  const { realm: keyRealm, name: keyName } = splitCharKey(key);

  const status: HardcoreStatus =
    String(raw.status ?? "Alive") === "Dead" ? "Dead" : "Alive";

  const name = String(raw.name ?? keyName ?? "Unknown");
  const realm = String(raw.realm ?? keyRealm ?? "Unknown");

  const parsedLevel = Number(raw.level)
  const level =
    Number.isFinite(parsedLevel) && parsedLevel >= 1
      ? Math.min(60, Math.floor(parsedLevel))
      : 1

  const character = {
    name,
    realm,
    class: raw.class ? String(raw.class).toUpperCase() : "UNKNOWN",
    race: raw.race ? String(raw.race) : undefined,
    guid: String(raw.guid ?? `${name}-${realm}`),
    level,
    status,
    faction: raw.faction ? String(raw.faction) : undefined,
    lastUpdated: raw.lastUpdated ? Number(raw.lastUpdated) : undefined,
  };

  const completedRaw = (raw.completed ?? {}) as Record<string, unknown>;
  const completed: ParsedCompletedAchievement[] = [];
  for (const [idKey, value] of Object.entries(completedRaw)) {
    const id = String(idKey);
    if (!value || typeof value !== "object" || Array.isArray(value)) {
      if (value === true) {
        completed.push({
          id,
          unlockedAt: Math.floor(Date.now() / 1000),
        });
      }
      continue;
    }
    const entry = value as Record<string, unknown>;
    completed.push({
      id: String(entry.id ?? id),
      unlockedAt: Number(
        entry.earnedOn ?? entry.unlockedAt ?? entry.unlocked_at ?? Date.now() / 1000,
      ),
      extra: {},
    });
  }

  completed.sort((a, b) => a.unlockedAt - b.unlockedAt);

  const zonesVisited = mapTruthyKeys(raw.visitedZones);
  const visitedInstances = mapTruthyKeys(raw.visitedInstances);

  const stats: ParsedStats = {
    zonesVisited,
    deaths: Number(raw.deaths ?? 0),
    raw: {
      progress: raw.progress ?? {},
      visitedInstances,
      faction: character.faction,
    },
  };

  return { key, character, completed, stats };
}

function splitCharKey(key: string): { realm?: string; name?: string } {
  const idx = key.indexOf("-");
  if (idx <= 0) return {};
  return { realm: key.slice(0, idx), name: key.slice(idx + 1) };
}

function mapTruthyKeys(value: unknown): string[] {
  const out: string[] = [];
  if (!value || typeof value !== "object") return out;
  if (Array.isArray(value)) {
    out.push(...value.map(String));
    return out;
  }
  for (const [zone, flag] of Object.entries(value as Record<string, unknown>)) {
    if (flag) out.push(zone);
  }
  return out;
}

function extractTableAssignment(lua: string, varName: string): string | null {
  const re = new RegExp(`${varName}\\s*=\\s*\\{`, "m");
  const match = re.exec(lua);
  if (!match || match.index === undefined) return null;

  const start = match.index + match[0].length - 1; // at '{'
  return sliceBalancedTable(lua, start);
}

function sliceBalancedTable(source: string, openBraceIndex: number): string {
  let depth = 0;
  let inString: '"' | "'" | null = null;
  let i = openBraceIndex;

  while (i < source.length) {
    const ch = source[i];
    const prev = source[i - 1];

    if (inString) {
      if (ch === inString && prev !== "\\") inString = null;
      i += 1;
      continue;
    }

    if (ch === '"' || ch === "'") {
      inString = ch;
      i += 1;
      continue;
    }

    if (ch === "-" && source[i + 1] === "-") {
      if (source[i + 2] === "[" && source[i + 3] === "[") {
        const end = source.indexOf("]]", i + 4);
        i = end === -1 ? source.length : end + 2;
        continue;
      }
      const eol = source.indexOf("\n", i);
      i = eol === -1 ? source.length : eol + 1;
      continue;
    }

    if (ch === "{") depth += 1;
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) {
        return source.slice(openBraceIndex, i + 1);
      }
    }
    i += 1;
  }

  throw new Error("Unbalanced Lua table while parsing ClassicGloryDB.");
}

type LuaValue =
  | string
  | number
  | boolean
  | null
  | LuaValue[]
  | { [key: string]: LuaValue };

function parseLuaTable(tableLiteral: string): LuaValue {
  const inner = tableLiteral.trim();
  if (!inner.startsWith("{") || !inner.endsWith("}")) {
    throw new Error("Expected a Lua table literal.");
  }

  const body = inner.slice(1, -1);
  const entries = splitTopLevelEntries(body);
  const obj: Record<string, LuaValue> = {};
  const arr: LuaValue[] = [];
  let arrayMode = true;
  let nextIndex = 1;

  for (const entry of entries) {
    const trimmed = entry.trim();
    if (!trimmed) continue;

    const kv = splitKeyValue(trimmed);
    if (kv) {
      arrayMode = false;
      obj[kv.key] = parseLuaValue(kv.value);
    } else {
      arr.push(parseLuaValue(trimmed));
      obj[String(nextIndex)] = parseLuaValue(trimmed);
      nextIndex += 1;
    }
  }

  if (!arrayMode || Object.keys(obj).some((k) => Number.isNaN(Number(k)))) {
    return obj;
  }
  return Object.keys(obj).length ? obj : arr;
}

function splitTopLevelEntries(body: string): string[] {
  const entries: string[] = [];
  let depth = 0;
  let inString: '"' | "'" | null = null;
  let start = 0;

  for (let i = 0; i < body.length; i += 1) {
    const ch = body[i];
    const prev = body[i - 1];

    if (inString) {
      if (ch === inString && prev !== "\\") inString = null;
      continue;
    }
    if (ch === '"' || ch === "'") {
      inString = ch;
      continue;
    }
    if (ch === "{") depth += 1;
    if (ch === "}") depth -= 1;

    if (ch === "," && depth === 0) {
      entries.push(body.slice(start, i));
      start = i + 1;
    }
  }
  entries.push(body.slice(start));
  return entries;
}

function splitKeyValue(entry: string): { key: string; value: string } | null {
  let depth = 0;
  let inString: '"' | "'" | null = null;

  for (let i = 0; i < entry.length; i += 1) {
    const ch = entry[i];
    const prev = entry[i - 1];

    if (inString) {
      if (ch === inString && prev !== "\\") inString = null;
      continue;
    }
    if (ch === '"' || ch === "'") {
      inString = ch;
      continue;
    }
    if (ch === "{") depth += 1;
    if (ch === "}") depth -= 1;

    if (depth === 0 && ch === "=") {
      if (entry[i + 1] === "=") continue;
      const keyRaw = entry.slice(0, i).trim();
      const value = entry.slice(i + 1).trim();
      return { key: normalizeLuaKey(keyRaw), value };
    }
  }
  return null;
}

function normalizeLuaKey(keyRaw: string): string {
  const bracket = keyRaw.match(/^\[["'](.+)["']\]$/);
  if (bracket) return bracket[1];

  const numBracket = keyRaw.match(/^\[(\d+)\]$/);
  if (numBracket) return numBracket[1];

  return keyRaw.replace(/^\[|\]$/g, "");
}

function parseLuaValue(raw: string): LuaValue {
  const value = raw.trim();
  if (!value) return null;

  if (value.startsWith("{")) {
    return parseLuaTable(sliceBalancedTable(value, 0));
  }

  if (value === "true") return true;
  if (value === "false") return false;
  if (value === "nil") return null;

  if (
    (value.startsWith('"') && value.endsWith('"')) ||
    (value.startsWith("'") && value.endsWith("'"))
  ) {
    return unescapeLuaString(value.slice(1, -1));
  }

  const num = Number(value);
  if (!Number.isNaN(num)) return num;

  return value;
}

function unescapeLuaString(s: string): string {
  return s
    .replace(/\\n/g, "\n")
    .replace(/\\t/g, "\t")
    .replace(/\\"/g, '"')
    .replace(/\\'/g, "'")
    .replace(/\\\\/g, "\\");
}
