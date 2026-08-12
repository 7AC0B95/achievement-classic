"use client";

import { LayoutList, Search, SlidersHorizontal, Table2, X } from "lucide-react";
import { useDeferredValue, useMemo, useState, type ReactNode } from "react";
import { AchievementTimeline } from "@/components/achievement-timeline";
import { CharacterAchievementsTable } from "@/components/character-achievements-table";
import { ACHIEVEMENT_CATEGORIES } from "@/lib/achievement-filters";
import {
  filterProfileAchievements,
  type ProfileLedgerSort,
  type ProfileProgressFilter,
} from "@/lib/character-profile";
import type { AchievementCategory, CharacterProfileAchievement } from "@/lib/types";
import { cn } from "@/lib/utils";

type ProfileView = "table" | "timeline";

interface CharacterAchievementsPanelProps {
  items: CharacterProfileAchievement[];
  categories: AchievementCategory[];
  onCategoriesChange: (categories: AchievementCategory[]) => void;
}

export function CharacterAchievementsPanel({
  items,
  categories,
  onCategoriesChange,
}: CharacterAchievementsPanelProps) {
  const [view, setView] = useState<ProfileView>("table");
  const [query, setQuery] = useState("");
  const [progress, setProgress] = useState<ProfileProgressFilter>("all");
  const [sort, setSort] = useState<ProfileLedgerSort>("newest");
  const [groupByCategory, setGroupByCategory] = useState(true);
  const deferredQuery = useDeferredValue(query);

  const unlockedCount = items.filter((item) => item.unlocked).length;

  const filtered = useMemo(
    () =>
      filterProfileAchievements(items, {
        query: deferredQuery,
        categories,
        progress,
        sort,
      }),
    [items, deferredQuery, categories, progress, sort],
  );

  const hasActiveFilters =
    query.length > 0 || categories.length > 0 || progress !== "all";

  const clearFilters = () => {
    setQuery("");
    onCategoriesChange([]);
    setProgress("all");
  };

  const toggleCategory = (category: AchievementCategory) => {
    onCategoriesChange(
      categories.includes(category)
        ? categories.filter((c) => c !== category)
        : [...categories, category],
    );
  };

  return (
    <section id="achievement-ledger" className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="font-[family-name:var(--font-display)] text-2xl text-zinc-50">
            Achievement ledger
          </h2>
          <p className="mt-1 text-sm text-zinc-500">
            {unlockedCount}/{items.length} unlocked · search, filter, and sort the catalog
          </p>
        </div>

        <div
          className="inline-flex rounded-lg border border-zinc-800 bg-zinc-950 p-1"
          role="tablist"
          aria-label="Achievement view"
        >
          <ViewTab
            active={view === "table"}
            onClick={() => setView("table")}
            icon={<Table2 className="h-4 w-4" />}
            label="Table"
          />
          <ViewTab
            active={view === "timeline"}
            onClick={() => setView("timeline")}
            icon={<LayoutList className="h-4 w-4" />}
            label="History"
          />
        </div>
      </div>

      {view === "table" ? (
        <>
          <div className="sticky top-16 z-40 -mx-4 border-y border-zinc-800/80 bg-zinc-950/90 px-4 py-3 backdrop-blur-xl sm:-mx-0 sm:rounded-xl sm:border sm:px-4">
            <div className="flex flex-col gap-3">
              <div className="flex flex-wrap items-center gap-2">
                <label className="relative min-w-[220px] flex-1">
                  <Search className="pointer-events-none absolute top-1/2 left-3 h-4 w-4 -translate-y-1/2 text-zinc-500" />
                  <input
                    type="search"
                    value={query}
                    onChange={(e) => setQuery(e.target.value)}
                    placeholder="Search name, description, or ID…"
                    className="w-full rounded-md border border-zinc-700 bg-zinc-900 py-2.5 pr-3 pl-10 text-sm text-zinc-100 outline-none placeholder:text-zinc-600 focus:border-amber-500/50"
                  />
                </label>

                <select
                  value={sort}
                  onChange={(e) => setSort(e.target.value as ProfileLedgerSort)}
                  className="rounded-md border border-zinc-700 bg-zinc-900 px-3 py-2.5 text-sm text-zinc-100 outline-none focus:border-amber-500/50"
                  aria-label="Sort achievements"
                >
                  <option value="newest">Newest unlocks</option>
                  <option value="points">Points · high to low</option>
                  <option value="name">Name · A–Z</option>
                  <option value="category">Category</option>
                </select>

                <button
                  type="button"
                  onClick={() => setGroupByCategory((v) => !v)}
                  className={cn(
                    "inline-flex items-center gap-2 rounded-md border px-3 py-2.5 text-sm transition",
                    groupByCategory
                      ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
                      : "border-zinc-700 bg-zinc-900 text-zinc-300 hover:border-zinc-600",
                  )}
                >
                  <SlidersHorizontal className="h-4 w-4" />
                  Group
                </button>

                {hasActiveFilters ? (
                  <button
                    type="button"
                    onClick={clearFilters}
                    className="inline-flex items-center gap-1.5 rounded-md border border-zinc-700 px-3 py-2.5 text-sm text-zinc-400 hover:border-rose-500/40 hover:text-rose-300"
                  >
                    <X className="h-4 w-4" />
                    Clear
                  </button>
                ) : null}
              </div>

              <div className="flex flex-wrap items-center gap-2">
                {(
                  [
                    ["all", "All"],
                    ["unlocked", "Unlocked"],
                    ["locked", "Locked"],
                  ] as Array<[ProfileProgressFilter, string]>
                ).map(([value, label]) => (
                  <button
                    key={value}
                    type="button"
                    onClick={() => setProgress(value)}
                    className={cn(
                      "rounded-md px-3 py-1.5 text-xs font-medium transition",
                      progress === value
                        ? "bg-zinc-100 text-zinc-950"
                        : "bg-zinc-900 text-zinc-400 hover:bg-zinc-800 hover:text-zinc-200",
                    )}
                  >
                    {label}
                  </button>
                ))}

                <span className="mx-1 hidden h-4 w-px bg-zinc-800 sm:inline-block" />

                {ACHIEVEMENT_CATEGORIES.map((category) => {
                  const active = categories.includes(category);
                  return (
                    <button
                      key={category}
                      type="button"
                      onClick={() => toggleCategory(category)}
                      className={cn(
                        "rounded-md border px-2.5 py-1.5 text-xs transition",
                        active
                          ? "border-amber-500/50 bg-amber-500/15 text-amber-200"
                          : "border-zinc-800 bg-zinc-900/80 text-zinc-400 hover:border-zinc-600 hover:text-zinc-200",
                      )}
                    >
                      {category}
                    </button>
                  );
                })}
              </div>
            </div>
          </div>

          <p className="text-sm text-zinc-500">
            Showing{" "}
            <span className="font-medium text-zinc-300">{filtered.length}</span> of{" "}
            {items.length}
            {deferredQuery.trim() ? (
              <>
                {" "}
                for “<span className="text-amber-300">{query.trim()}</span>”
              </>
            ) : null}
          </p>

          <CharacterAchievementsTable items={filtered} grouped={groupByCategory} />
        </>
      ) : (
        <AchievementTimeline items={items} />
      )}
    </section>
  );
}

function ViewTab({
  active,
  onClick,
  icon,
  label,
}: {
  active: boolean;
  onClick: () => void;
  icon: ReactNode;
  label: string;
}) {
  return (
    <button
      type="button"
      role="tab"
      aria-selected={active}
      onClick={onClick}
      className={cn(
        "inline-flex items-center gap-2 rounded-md px-3 py-2 text-sm transition",
        active
          ? "bg-amber-500/15 text-amber-300"
          : "text-zinc-400 hover:text-zinc-200",
      )}
    >
      {icon}
      {label}
    </button>
  );
}
