import type { SupabaseClient } from "@supabase/supabase-js";
import type {
  CharacterAchievementRow,
  CharacterRow,
  LeaderboardSort,
} from "@/lib/types";

export interface LeaderboardQuery {
  realm?: string;
  classToken?: string;
  status?: string;
  sort?: LeaderboardSort;
  limit?: number;
}

export async function queryLeaderboard(
  supabase: SupabaseClient,
  filters: LeaderboardQuery = {},
): Promise<CharacterRow[]> {
  let query = supabase.from("characters").select("*");

  if (filters.realm) query = query.eq("realm", filters.realm);
  if (filters.classToken) {
    query = query.eq("class", filters.classToken.toUpperCase());
  }
  if (filters.status) query = query.eq("status", filters.status);

  if (filters.sort === "achievement_count") {
    query = query.order("achievement_count", { ascending: false });
  } else {
    query = query.order("total_points", { ascending: false });
  }

  const { data, error } = await query.limit(filters.limit ?? 100);
  if (error) throw error;
  return (data as CharacterRow[]) ?? [];
}

export async function queryRecentActivity(
  supabase: SupabaseClient,
  limit = 12,
): Promise<CharacterAchievementRow[]> {
  const { data, error } = await supabase
    .from("character_achievements")
    .select("*, achievements(*), characters(id, name, realm, class)")
    .order("unlocked_at", { ascending: false })
    .limit(limit);

  if (error) throw error;
  return (data as CharacterAchievementRow[]) ?? [];
}

export async function queryRealms(supabase: SupabaseClient): Promise<string[]> {
  const { data, error } = await supabase
    .from("characters")
    .select("realm")
    .limit(500);

  if (error) throw error;
  return [
    ...new Set((data ?? []).map((row) => String(row.realm)).filter(Boolean)),
  ].sort();
}
