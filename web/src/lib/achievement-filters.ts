import type { AchievementCategory } from "@/lib/types";

export const ACHIEVEMENT_CATEGORIES: AchievementCategory[] = [
  "General",
  "Quests",
  "Combat",
  "Exploration",
  "Wealth",
  "Professions",
  "Dungeons",
  "Player vs Player",
  "Hardcore",
  "Feats of Strength",
];

export type AchievementProgressFilter = "all" | "unlocked" | "locked";

export type AchievementSort =
  | "points_desc"
  | "points_asc"
  | "name_asc"
  | "category"
  | "progress";

export type AchievementDensity = "comfortable" | "compact";
