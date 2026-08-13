import type { SealSnapshot } from "./seal";

export type HardcoreStatus = "Alive" | "Dead";

export type AchievementCategory =
  | "General"
  | "Quests"
  | "Combat"
  | "Exploration"
  | "Wealth"
  | "Professions"
  | "Dungeons"
  | "Player vs Player"
  | "Hardcore"
  | "Feats of Strength";

export type WowClass =
  | "WARRIOR"
  | "PALADIN"
  | "HUNTER"
  | "ROGUE"
  | "PRIEST"
  | "SHAMAN"
  | "MAGE"
  | "WARLOCK"
  | "DRUID";

export interface AchievementDefinition {
  id: string;
  name: string;
  description: string;
  category: AchievementCategory;
  points: number;
  icon?: string;
}

export interface ParsedCharacter {
  name: string;
  realm: string;
  class: string;
  race?: string;
  guid: string;
  level: number;
  status: HardcoreStatus;
  faction?: string;
  lastUpdated?: number;
  seal?: string;
}

export interface ParsedCompletedAchievement {
  id: string;
  name?: string;
  points?: number;
  category?: string;
  unlockedAt: number;
  earnedLevel?: number;
  ticket?: string;
  extra?: Record<string, unknown>;
}

export interface ParsedStats {
  zonesVisited: string[];
  deaths: number;
  visitedInstances?: string[];
  progress?: Record<string, Record<string, number>>;
  raw?: Record<string, unknown>;
}

export interface ParsedCharacterBundle {
  key: string;
  character: ParsedCharacter;
  completed: ParsedCompletedAchievement[];
  stats: ParsedStats;
  snapshot: SealSnapshot;
}

export interface ParsedClassicGloryDB {
  version: number;
  characters: ParsedCharacterBundle[];
}

export interface CharacterRow {
  id: string;
  user_id: string | null;
  guid: string;
  name: string;
  realm: string;
  class: string;
  race: string | null;
  level: number;
  status: HardcoreStatus;
  total_points: number;
  achievement_count: number;
  last_synced_at: string | null;
  created_at: string;
  updated_at: string;
}

export interface AchievementRow {
  id: string;
  name: string;
  description: string;
  category: AchievementCategory;
  points: number;
  icon: string | null;
  created_at: string;
}

export interface CharacterAchievementRow {
  id: string;
  character_id: string;
  achievement_id: string;
  unlocked_at: string;
  meta: Record<string, unknown>;
  created_at: string;
  achievements?: AchievementRow;
  characters?: Pick<CharacterRow, "id" | "name" | "realm" | "class">;
}

export interface CharacterStatsRow {
  character_id: string;
  zones_visited: string[];
  deaths: number;
  raw: Record<string, unknown>;
  updated_at: string;
}

/** Catalog achievement joined with a character's unlock state for the profile dossier. */
export interface CharacterProfileAchievement extends AchievementRow {
  unlocked: boolean;
  unlocked_at: string | null;
}

export type LeaderboardSort =
  | "total_points"
  | "achievement_count"
  | "recent"
  | "boss_kills";

export interface SyncPayload {
  character: ParsedCharacter;
  completed: ParsedCompletedAchievement[];
  stats: ParsedStats;
  snapshot: SealSnapshot;
  seal?: string;
}
