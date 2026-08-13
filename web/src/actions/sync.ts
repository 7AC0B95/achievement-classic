"use server";

import { getAchievementById } from "@/lib/achievements";
import { createClient } from "@/lib/supabase/server";
import type { SyncPayload } from "@/lib/types";

export type SyncResult =
  | {
      ok: true;
      characterId: string;
      totalPoints: number;
      achievementCount: number;
      message: string;
    }
  | {
      ok: false;
      message: string;
      needsAuth?: boolean;
    };

export async function syncCharacterFromAddon(
  payload: SyncPayload,
): Promise<SyncResult> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return {
        ok: false,
        needsAuth: true,
        message: "Sign in to sync your character to Classic Glory.",
      };
    }

    const { character, completed, stats } = payload;
    if (!character.guid || !character.name || !character.realm) {
      return { ok: false, message: "Character GUID/name/realm missing from addon data." };
    }

    const knownCompleted = completed.filter((entry) => getAchievementById(entry.id));

    const totalPoints = knownCompleted.reduce((sum, entry) => {
      const catalogPts = getAchievementById(entry.id)?.points ?? 0;
      return sum + (entry.points ?? catalogPts);
    }, 0);

    const hasLiveIdentity =
      Boolean(character.lastUpdated) &&
      Boolean(character.class) &&
      character.class.toUpperCase() !== "UNKNOWN";

    const fields: {
      user_id: string;
      guid: string;
      name: string;
      realm: string;
      status?: "Alive" | "Dead";
      total_points: number;
      achievement_count: number;
      last_synced_at: string;
      class?: string;
      race?: string | null;
      level?: number;
    } = {
      user_id: user.id,
      guid: character.guid,
      name: character.name,
      realm: character.realm,
      total_points: totalPoints,
      achievement_count: knownCompleted.length,
      last_synced_at: new Date().toISOString(),
    };

    if (hasLiveIdentity) {
      fields.class = character.class;
      fields.race = character.race ?? null;
      fields.level = character.level;
    }

    const { data: byGuid, error: guidLookupError } = await supabase
      .from("characters")
      .select("id, status")
      .eq("guid", character.guid)
      .maybeSingle();

    if (guidLookupError) {
      return { ok: false, message: guidLookupError.message };
    }

    let existingId = byGuid?.id as string | undefined;
    let existingStatus = byGuid?.status as "Alive" | "Dead" | undefined;

    if (!existingId) {
      const { data: byName, error: nameLookupError } = await supabase
        .from("characters")
        .select("id, status")
        .eq("name", character.name)
        .eq("realm", character.realm)
        .maybeSingle();

      if (nameLookupError) {
        return { ok: false, message: nameLookupError.message };
      }
      existingId = byName?.id as string | undefined;
      existingStatus = byName?.status as "Alive" | "Dead" | undefined;
    }

    if (!existingId) {
      fields.class = fields.class ?? "UNKNOWN";
      fields.level = fields.level ?? 1;
      fields.race = fields.race ?? character.race ?? null;
    }

    // Dead from the web toggle (or a prior addon death) must not be resurrected
    // by a later lua sync that still says Alive.
    if (existingStatus !== "Dead" || character.status === "Dead") {
      fields.status = character.status;
    }

    const characterQuery = existingId
      ? supabase.from("characters").update(fields).eq("id", existingId)
      : supabase.from("characters").insert(fields);

    const { data: upserted, error: charError } = await characterQuery
      .select("id")
      .single();

    if (charError || !upserted) {
      return {
        ok: false,
        message: charError?.message ?? "Failed to upsert character.",
      };
    }

    const characterId = upserted.id as string;

    if (knownCompleted.length > 0) {
      const rows = knownCompleted.map((entry) => ({
        character_id: characterId,
        achievement_id: entry.id,
        unlocked_at: new Date(entry.unlockedAt * 1000).toISOString(),
        meta: entry.extra ?? {},
      }));

      const { error: achError } = await supabase
        .from("character_achievements")
        .upsert(rows, { onConflict: "character_id,achievement_id" });

      if (achError) {
        return { ok: false, message: achError.message };
      }
    }

    const { error: statsError } = await supabase.from("character_stats").upsert(
      {
        character_id: characterId,
        zones_visited: stats.zonesVisited,
        deaths: stats.deaths,
        raw: stats.raw ?? stats,
      },
      { onConflict: "character_id" },
    );

    if (statsError) {
      return { ok: false, message: statsError.message };
    }

    return {
      ok: true,
      characterId,
      totalPoints,
      achievementCount: knownCompleted.length,
      message: `Synced ${character.name}-${character.realm}: ${knownCompleted.length} achievements, ${totalPoints} pts.`,
    };
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown sync error";
    return { ok: false, message };
  }
}

export async function updateCharacterStatus(
  characterId: string,
  status: "Alive" | "Dead",
): Promise<{ ok: boolean; message: string }> {
  try {
    const supabase = await createClient();
    const {
      data: { user },
    } = await supabase.auth.getUser();

    if (!user) {
      return { ok: false, message: "Sign in required." };
    }

    const { error } = await supabase
      .from("characters")
      .update({ status })
      .eq("id", characterId)
      .eq("user_id", user.id);

    if (error) return { ok: false, message: error.message };
    return { ok: true, message: `Status set to ${status}.` };
  } catch (error) {
    return {
      ok: false,
      message: error instanceof Error ? error.message : "Failed to update status.",
    };
  }
}
