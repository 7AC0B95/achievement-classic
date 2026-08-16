import { ACHIEVEMENT_CATALOG } from "@/lib/achievements";
import {
  queryLeaderboard,
  queryRealms,
  queryRecentActivity,
} from "@/lib/public-queries";
import { createClient } from "@/lib/supabase/server";
import type {
  AchievementRow,
  CharacterAchievementRow,
  CharacterRow,
  CharacterStatsRow,
  CommunityStats,
  LeaderboardSort,
} from "@/lib/types";
import { cache } from "react";

function rethrowIfPrerenderInterrupt(error: unknown) {
  if (error instanceof Error) {
    if (
      error.message.includes("Dynamic server usage") ||
      error.message.includes("during prerendering")
    ) {
      throw error;
    }
  }
  if (error && typeof error === "object" && "digest" in error) {
    const digest = String((error as { digest: unknown }).digest);
    if (
      digest.startsWith("NEXT_") ||
      digest === "DYNAMIC_SERVER_USAGE" ||
      digest === "BAILOUT_TO_CLIENT_SIDE_RENDERING" ||
      digest === "HANGING_PROMISE_REJECTION"
    ) {
      throw error;
    }
  }
}

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
  limit?: number;
}): Promise<CharacterRow[]> {
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    return await queryLeaderboard(supabase, filters);
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return [];
  }
}

export async function fetchRecentActivity(limit = 12): Promise<CharacterAchievementRow[]> {
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    return await queryRecentActivity(supabase, limit);
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
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
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return ACHIEVEMENT_CATALOG.map((a) => ({
      ...a,
      icon: a.icon ?? null,
      created_at: new Date().toISOString(),
    }));
  }
}

export const getCurrentUser = cache(async () => {
  if (!isSupabaseEnvReady()) return null;

  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();
    return user;
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return null;
  }
});

export const fetchUserCharacters = cache(async (): Promise<CharacterRow[]> => {
  const user = await getCurrentUser();
  if (!user) return [];

  try {
    const supabase = await createClient();
    const { data } = await supabase
      .from("characters")
      .select("*")
      .eq("user_id", user.id)
      .order("updated_at", { ascending: false });

    return (data as CharacterRow[]) ?? [];
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
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
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
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
  if (!isSupabaseEnvReady()) return [];

  try {
    const supabase = await createClient();
    return await queryRealms(supabase);
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return [];
  }
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
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
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
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return [];
  }
}

export async function fetchCommunityStats(): Promise<CommunityStats | null> {
  if (!isSupabaseEnvReady()) return null;

  try {
    const supabase = await createClient();
    const { data, error } = await supabase.rpc("get_community_stats");
    if (error || !data || typeof data !== "object") return null;
    return data as CommunityStats;
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return null;
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
  } catch (error) {
    rethrowIfPrerenderInterrupt(error);
    return null;
  }
}
