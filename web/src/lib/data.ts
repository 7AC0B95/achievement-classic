import { ACHIEVEMENT_CATALOG, BOSS_ACHIEVEMENT_IDS } from "@/lib/achievements";
import { createClient } from "@/lib/supabase/server";
import type {
  AchievementRow,
  CharacterAchievementRow,
  CharacterRow,
  CharacterStatsRow,
  LeaderboardSort,
} from "@/lib/types";
import { cache } from "react";

export function isSupabaseEnvReady() {
  return Boolean(
    process.env.NEXT_PUBLIC_SUPABASE_URL && process.env.NEXT_PUBLIC_SUPABASE_ANON_KEY,
  );
}

export async function fetchLeaderboard(filters: {
  realm?: string;
  classToken?: string;
  status?: string;
  sort?: LeaderboardSort;
}): Promise<CharacterRow[]> {
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    let query = supabase.from("characters").select("*");

    if (filters.realm) query = query.eq("realm", filters.realm);
    if (filters.classToken) query = query.eq("class", filters.classToken.toUpperCase());
    if (filters.status) query = query.eq("status", filters.status);

    if (filters.sort === "achievement_count") {
      query = query.order("achievement_count", { ascending: false });
    } else if (filters.sort === "recent") {
      query = query.order("last_synced_at", { ascending: false, nullsFirst: false });
    } else {
      query = query.order("total_points", { ascending: false });
    }

    const { data, error } = await query.limit(100);
    if (error || !data) return [];

    if (filters.sort === "boss_kills") {
      const { data: bossRows } = await supabase
        .from("character_achievements")
        .select("character_id")
        .in("achievement_id", [...BOSS_ACHIEVEMENT_IDS]);

      const counts = new Map<string, number>();
      for (const row of bossRows ?? []) {
        counts.set(row.character_id, (counts.get(row.character_id) ?? 0) + 1);
      }

      return [...(data as CharacterRow[])].sort(
        (a, b) => (counts.get(b.id) ?? 0) - (counts.get(a.id) ?? 0),
      );
    }

    return data as CharacterRow[];
  } catch {
    return [];
  }
}

export async function fetchRecentActivity(limit = 12): Promise<CharacterAchievementRow[]> {
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("character_achievements")
      .select("*, achievements(*), characters(id, name, realm, class)")
      .order("unlocked_at", { ascending: false })
      .limit(limit);

    if (error || !data) return [];
    return data as CharacterAchievementRow[];
  } catch {
    return [];
  }
}

export async function fetchAchievements(): Promise<AchievementRow[]> {
  if (!isSupabaseEnvReady()) {
    return ACHIEVEMENT_CATALOG.map((a) => ({
      ...a,
      icon: a.icon ?? null,
      created_at: new Date().toISOString(),
    }));
  }

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("achievements")
      .select("*")
      .order("points", { ascending: false });

    if (error || !data?.length) {
      return ACHIEVEMENT_CATALOG.map((a) => ({
        ...a,
        icon: a.icon ?? null,
        created_at: new Date().toISOString(),
      }));
    }
    return data as AchievementRow[];
  } catch {
    return ACHIEVEMENT_CATALOG.map((a) => ({
      ...a,
      icon: a.icon ?? null,
      created_at: new Date().toISOString(),
    }));
  }
}

export const fetchUserCharacters = cache(async (): Promise<CharacterRow[]> => {
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    if (!user) return [];

    const { data } = await supabase
      .from("characters")
      .select("*")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    return (data as CharacterRow[]) ?? [];
  } catch {
    return [];
  }
});

export async function fetchUnlockedIdsForCharacters(
  characterIds: string[],
): Promise<Map<string, Set<string>>> {
  const unlocked = new Map<string, Set<string>>();
  const ids = [...new Set(characterIds.filter(Boolean))];
  for (const id of ids) unlocked.set(id, new Set());
  if (ids.length === 0 || !isSupabaseEnvReady()) return unlocked;

  try {
    const supabase = await createClient();
    const { data } = await supabase
      .from("character_achievements")
      .select("character_id, achievement_id")
      .in("character_id", ids);

    for (const row of data ?? []) {
      unlocked.get(row.character_id as string)?.add(row.achievement_id as string);
    }
    return unlocked;
  } catch {
    return unlocked;
  }
}

export async function fetchUnlockedIdsForCharacter(
  characterId: string | null,
): Promise<Set<string>> {
  if (!characterId) return new Set();
  const unlocked = await fetchUnlockedIdsForCharacters([characterId]);
  return unlocked.get(characterId) ?? new Set();
}

export async function fetchRealms(): Promise<string[]> {
  const rows = await fetchLeaderboard({});
  return [...new Set(rows.map((r) => r.realm))].sort();
}

export const fetchCharacterById = cache(async function fetchCharacterById(
  id: string,
): Promise<CharacterRow | null> {
  if (!isSupabaseEnvReady()) return null;

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("characters")
      .select("*")
      .eq("id", id)
      .maybeSingle();

    if (error || !data) return null;
    return data as CharacterRow;
  } catch {
    return null;
  }
});

export async function fetchCharacterAchievements(
  characterId: string,
): Promise<CharacterAchievementRow[]> {
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("character_achievements")
      .select("*, achievements(*)")
      .eq("character_id", characterId)
      .order("unlocked_at", { ascending: false });

    if (error || !data) return [];
    return data as CharacterAchievementRow[];
  } catch {
    return [];
  }
}

export async function fetchCharacterStats(
  characterId: string,
): Promise<CharacterStatsRow | null> {
  if (!isSupabaseEnvReady()) return null;

  try {
    const supabase = await createClient();
    const { data, error } = await supabase
      .from("character_stats")
      .select("*")
      .eq("character_id", characterId)
      .maybeSingle();

    if (error || !data) return null;
    return data as CharacterStatsRow;
  } catch {
    return null;
  }
}
