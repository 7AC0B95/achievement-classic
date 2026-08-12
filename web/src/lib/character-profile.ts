import { ACHIEVEMENT_CATEGORIES } from "@/lib/achievement-filters";
import type {
  AchievementCategory,
  AchievementRow,
  CharacterAchievementRow,
  CharacterProfileAchievement,
} from "@/lib/types";

export function joinCatalogWithUnlocks(
  catalog: AchievementRow[],
  unlocks: CharacterAchievementRow[],
): CharacterProfileAchievement[] {
  const unlockedAt = new Map<string, string>();
  for (const row of unlocks) {
    unlockedAt.set(row.achievement_id, row.unlocked_at);
  }

  return catalog.map((achievement) => {
    const at = unlockedAt.get(achievement.id) ?? null;
    return {
      ...achievement,
      unlocked: Boolean(at),
      unlocked_at: at,
    };
  });
}

export interface CategoryProgress {
  category: AchievementCategory;
  total: number;
  unlocked: number;
  pointsAvailable: number;
  pointsEarned: number;
  percent: number;
}

export function buildCategoryProgress(
  items: CharacterProfileAchievement[],
): CategoryProgress[] {
  const map = new Map<AchievementCategory, CategoryProgress>();
  for (const category of ACHIEVEMENT_CATEGORIES) {
    map.set(category, {
      category,
      total: 0,
      unlocked: 0,
      pointsAvailable: 0,
      pointsEarned: 0,
      percent: 0,
    });
  }

  for (const item of items) {
    const entry = map.get(item.category);
    if (!entry) continue;
    entry.total += 1;
    entry.pointsAvailable += item.points;
    if (item.unlocked) {
      entry.unlocked += 1;
      entry.pointsEarned += item.points;
    }
  }

  return ACHIEVEMENT_CATEGORIES.map((category) => {
    const entry = map.get(category)!;
    entry.percent =
      entry.total === 0 ? 0 : Math.round((entry.unlocked / entry.total) * 100);
    return entry;
  });
}

export function titleCaseZone(value: string) {
  return value
    .split(/\s+/)
    .filter(Boolean)
    .map((word) => word.charAt(0).toUpperCase() + word.slice(1).toLowerCase())
    .join(" ");
}

export function getVisitedInstances(raw: Record<string, unknown> | null | undefined) {
  if (!raw) return [] as string[];
  const value = raw.visitedInstances;
  if (!value) return [];
  if (Array.isArray(value)) return value.map(String);
  if (typeof value === "object") {
    return Object.entries(value as Record<string, unknown>)
      .filter(([, flag]) => Boolean(flag))
      .map(([name]) => name);
  }
  return [];
}

export interface ProfileHighlights {
  latest: CharacterProfileAchievement | null;
  highest: CharacterProfileAchievement | null;
  first: CharacterProfileAchievement | null;
  strongestCategory: CategoryProgress | null;
  suggestedNext: CharacterProfileAchievement[];
  recent: CharacterProfileAchievement[];
}

export function buildProfileHighlights(
  items: CharacterProfileAchievement[],
  categoryProgress: CategoryProgress[],
): ProfileHighlights {
  const unlocked = items
    .filter((item) => item.unlocked && item.unlocked_at)
    .sort(
      (a, b) =>
        new Date(b.unlocked_at!).getTime() - new Date(a.unlocked_at!).getTime(),
    );

  const latest = unlocked[0] ?? null;
  const first =
    unlocked.length > 0
      ? [...unlocked].sort(
          (a, b) =>
            new Date(a.unlocked_at!).getTime() -
            new Date(b.unlocked_at!).getTime(),
        )[0]
      : null;
  const highest =
    unlocked.length > 0
      ? [...unlocked].sort(
          (a, b) => b.points - a.points || a.name.localeCompare(b.name),
        )[0]
      : null;

  const strongestCategory =
    [...categoryProgress]
      .filter((c) => c.total > 0)
      .sort(
        (a, b) =>
          b.percent - a.percent ||
          b.pointsEarned - a.pointsEarned ||
          a.category.localeCompare(b.category),
      )[0] ?? null;

  const startedCategories = new Set(
    categoryProgress
      .filter((c) => c.unlocked > 0 && c.unlocked < c.total)
      .map((c) => c.category),
  );

  const suggestedNext = items
    .filter((item) => !item.unlocked && startedCategories.has(item.category))
    .sort((a, b) => b.points - a.points || a.name.localeCompare(b.name))
    .slice(0, 3);

  return {
    latest,
    highest,
    first,
    strongestCategory,
    suggestedNext,
    recent: unlocked.slice(0, 5),
  };
}

export type ProfileLedgerSort = "newest" | "points" | "name" | "category";
export type ProfileProgressFilter = "all" | "unlocked" | "locked";

export function filterProfileAchievements(
  items: CharacterProfileAchievement[],
  opts: {
    query: string;
    categories: AchievementCategory[];
    progress: ProfileProgressFilter;
    sort: ProfileLedgerSort;
  },
): CharacterProfileAchievement[] {
  const needle = opts.query.trim().toLowerCase();
  let rows = [...items];

  if (needle) {
    rows = rows.filter((item) => {
      const haystack =
        `${item.name} ${item.description} ${item.id} ${item.category}`.toLowerCase();
      return haystack.includes(needle);
    });
  }

  if (opts.categories.length > 0) {
    rows = rows.filter((item) => opts.categories.includes(item.category));
  }

  if (opts.progress === "unlocked") rows = rows.filter((item) => item.unlocked);
  if (opts.progress === "locked") rows = rows.filter((item) => !item.unlocked);

  rows.sort((a, b) => {
    switch (opts.sort) {
      case "points":
        return b.points - a.points || a.name.localeCompare(b.name);
      case "name":
        return a.name.localeCompare(b.name);
      case "category":
        return (
          a.category.localeCompare(b.category) ||
          b.points - a.points ||
          a.name.localeCompare(b.name)
        );
      case "newest":
      default: {
        if (a.unlocked !== b.unlocked) return a.unlocked ? -1 : 1;
        if (a.unlocked_at && b.unlocked_at) {
          return (
            new Date(b.unlocked_at).getTime() - new Date(a.unlocked_at).getTime()
          );
        }
        return a.name.localeCompare(b.name);
      }
    }
  });

  return rows;
}
