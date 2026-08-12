"use client";

import {
  Check,
  LayoutGrid,
  List,
  Lock,
  Search,
  SlidersHorizontal,
  X,
} from "lucide-react";
import { useDeferredValue, useMemo, useState, type ReactNode } from "react";
import {
  ACHIEVEMENT_CATEGORIES,
  type AchievementDensity,
  type AchievementProgressFilter,
  type AchievementSort,
} from "@/lib/achievement-filters";
import { getAchievementIcon } from "@/lib/achievement-icons";
import type { AchievementCategory, AchievementRow } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

export interface CatalogAchievement extends AchievementRow {
  unlocked: boolean;
}

interface AchievementsCatalogProps {
  achievements: CatalogAchievement[];
  characterLabel: string | null;
}

export function AchievementsCatalog({
  achievements,
  characterLabel,
}: AchievementsCatalogProps) {
  const [query, setQuery] = useState("");
  const [categories, setCategories] = useState<AchievementCategory[]>([]);
  const [progress, setProgress] = useState<AchievementProgressFilter>("all");
  const [sort, setSort] = useState<AchievementSort>("points_desc");
  const [density, setDensity] = useState<AchievementDensity>("compact");
  const [groupByCategory, setGroupByCategory] = useState(true);

  const deferredQuery = useDeferredValue(query.trim().toLowerCase());

  const totals = useMemo(() => {
    const unlocked = achievements.filter((a) => a.unlocked);
    return {
      count: achievements.length,
      unlocked: unlocked.length,
      points: achievements.reduce((sum, a) => sum + a.points, 0),
      earnedPoints: unlocked.reduce((sum, a) => sum + a.points, 0),
    };
  }, [achievements]);

  const categoryCounts = useMemo(() => {
    const map = new Map<AchievementCategory, { total: number; unlocked: number }>();
    for (const cat of ACHIEVEMENT_CATEGORIES) {
      map.set(cat, { total: 0, unlocked: 0 });
    }
    for (const a of achievements) {
      const entry = map.get(a.category) ?? { total: 0, unlocked: 0 };
      entry.total += 1;
      if (a.unlocked) entry.unlocked += 1;
      map.set(a.category, entry);
    }
    return map;
  }, [achievements]);

  const filtered = useMemo(() => {
    let rows = [...achievements];

    if (deferredQuery) {
      rows = rows.filter((a) => {
        const haystack = `${a.name} ${a.description} ${a.id} ${a.category}`.toLowerCase();
        return haystack.includes(deferredQuery);
      });
    }

    if (categories.length > 0) {
      rows = rows.filter((a) => categories.includes(a.category));
    }

    if (progress === "unlocked") rows = rows.filter((a) => a.unlocked);
    if (progress === "locked") rows = rows.filter((a) => !a.unlocked);

    rows.sort((a, b) => {
      switch (sort) {
        case "points_asc":
          return a.points - b.points || a.name.localeCompare(b.name);
        case "name_asc":
          return a.name.localeCompare(b.name);
        case "category":
          return (
            a.category.localeCompare(b.category) ||
            b.points - a.points ||
            a.name.localeCompare(b.name)
          );
        case "progress":
          if (a.unlocked !== b.unlocked) return a.unlocked ? -1 : 1;
          return b.points - a.points;
        case "points_desc":
        default:
          return b.points - a.points || a.name.localeCompare(b.name);
      }
    });

    return rows;
  }, [achievements, deferredQuery, categories, progress, sort]);

  const grouped = useMemo(() => {
    if (!groupByCategory) return null;
    const order = categories.length > 0 ? categories : ACHIEVEMENT_CATEGORIES;
    return order
      .map((category) => ({
        category,
        items: filtered.filter((a) => a.category === category),
      }))
      .filter((g) => g.items.length > 0);
  }, [filtered, groupByCategory, categories]);

  const hasActiveFilters =
    query.length > 0 || categories.length > 0 || progress !== "all";

  const clearFilters = () => {
    setQuery("");
    setCategories([]);
    setProgress("all");
  };

  const toggleCategory = (category: AchievementCategory) => {
    setCategories((prev) =>
      prev.includes(category)
        ? prev.filter((c) => c !== category)
        : [...prev, category],
    );
  };

  const progressPct =
    totals.count === 0 ? 0 : Math.round((totals.unlocked / totals.count) * 100);

  return (
    <div className="space-y-6">
      {/* Overview */}
      <section className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-5 sm:p-6">
        <div className="flex flex-wrap items-end justify-between gap-4">
          <div>
            <h1 className="font-[family-name:var(--font-display)] text-3xl text-zinc-50">
              Achievement catalog
            </h1>
            <p className="mt-2 max-w-2xl text-sm text-zinc-400">
              Browse, search, and track custom achievements.
              {characterLabel ? (
                <>
                  {" "}
                  Progress shown for{" "}
                  <span className="text-amber-300">{characterLabel}</span>.
                </>
              ) : (
                <> Sync a character on the dashboard to track unlocks.</>
              )}
            </p>
          </div>
          <div className="text-right">
            <div className="text-2xl font-semibold text-amber-400">
              {formatPoints(totals.earnedPoints)}
              <span className="text-base font-normal text-zinc-500">
                {" "}
                / {formatPoints(totals.points)} pts
              </span>
            </div>
            <div className="mt-1 text-sm text-zinc-400">
              {totals.unlocked}/{totals.count} unlocked · {progressPct}%
            </div>
          </div>
        </div>

        <div className="mt-4 h-2 overflow-hidden rounded-full bg-zinc-950">
          <div
            className="h-full rounded-full bg-gradient-to-r from-amber-600 to-amber-400 transition-all duration-500"
            style={{ width: `${progressPct}%` }}
          />
        </div>
      </section>

      {/* Sticky controls */}
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
              onChange={(e) => setSort(e.target.value as AchievementSort)}
              className="rounded-md border border-zinc-700 bg-zinc-900 px-3 py-2.5 text-sm text-zinc-100 outline-none focus:border-amber-500/50"
              aria-label="Sort achievements"
            >
              <option value="points_desc">Points · high to low</option>
              <option value="points_asc">Points · low to high</option>
              <option value="name_asc">Name · A–Z</option>
              <option value="category">Category</option>
              <option value="progress">Unlocked first</option>
            </select>

            <div className="inline-flex rounded-md border border-zinc-700 bg-zinc-900 p-1">
              <DensityButton
                active={density === "compact"}
                onClick={() => setDensity("compact")}
                icon={<List className="h-4 w-4" />}
                label="List"
              />
              <DensityButton
                active={density === "comfortable"}
                onClick={() => setDensity("comfortable")}
                icon={<LayoutGrid className="h-4 w-4" />}
                label="Cards"
              />
            </div>

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
              ] as const
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
              const counts = categoryCounts.get(category);
              const active = categories.includes(category);
              return (
                <button
                  key={category}
                  type="button"
                  onClick={() => toggleCategory(category)}
                  className={cn(
                    "inline-flex items-center gap-1.5 rounded-md border px-2.5 py-1.5 text-xs transition",
                    active
                      ? "border-amber-500/50 bg-amber-500/15 text-amber-200"
                      : "border-zinc-800 bg-zinc-900/80 text-zinc-400 hover:border-zinc-600 hover:text-zinc-200",
                  )}
                >
                  {active ? <Check className="h-3 w-3" /> : null}
                  {category}
                  <span className="text-zinc-500">
                    {counts?.unlocked ?? 0}/{counts?.total ?? 0}
                  </span>
                </button>
              );
            })}
          </div>
        </div>
      </div>

      {/* Results meta */}
      <div className="flex items-center justify-between gap-3 text-sm text-zinc-500">
        <p>
          Showing{" "}
          <span className="font-medium text-zinc-300">{filtered.length}</span> of{" "}
          {totals.count}
          {deferredQuery ? (
            <>
              {" "}
              for “<span className="text-amber-300">{query.trim()}</span>”
            </>
          ) : null}
        </p>
      </div>

      {filtered.length === 0 ? (
        <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-16 text-center">
          <p className="text-zinc-300">No achievements match these filters.</p>
          <button
            type="button"
            onClick={clearFilters}
            className="mt-3 text-sm text-amber-400 hover:text-amber-300"
          >
            Reset filters
          </button>
        </div>
      ) : groupByCategory && grouped ? (
        <div className="space-y-8">
          {grouped.map((group) => (
            <section key={group.category} id={`cat-${group.category}`}>
              <div className="mb-3 flex items-baseline justify-between gap-3">
                <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-100">
                  {group.category}
                </h2>
                <span className="text-xs text-zinc-500">
                  {group.items.length} shown
                </span>
              </div>
              <AchievementResults items={group.items} density={density} />
            </section>
          ))}
        </div>
      ) : (
        <AchievementResults items={filtered} density={density} />
      )}
    </div>
  );
}

function AchievementResults({
  items,
  density,
}: {
  items: CatalogAchievement[];
  density: AchievementDensity;
}) {
  if (density === "comfortable") {
    return (
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {items.map((item) => (
          <AchievementCardRow key={item.id} item={item} />
        ))}
      </div>
    );
  }

  return (
    <ul className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/40 divide-y divide-zinc-800/80">
      {items.map((item) => (
        <AchievementListRow key={item.id} item={item} />
      ))}
    </ul>
  );
}

function AchievementListRow({ item }: { item: CatalogAchievement }) {
  const Icon = getAchievementIcon(item.icon);

  return (
    <li
      className={cn(
        "flex items-start gap-3 px-3 py-3 transition sm:items-center sm:px-4",
        "hover:bg-zinc-800/35",
        !item.unlocked && "opacity-75",
      )}
    >
      <div
        className={cn(
          "mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-md border sm:mt-0",
          item.unlocked
            ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
            : "border-zinc-700 bg-zinc-950 text-zinc-500",
        )}
      >
        {item.unlocked ? <Icon className="h-4 w-4" /> : <Lock className="h-3.5 w-3.5" />}
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
          <h3
            className={cn(
              "truncate font-medium",
              item.unlocked ? "text-zinc-50" : "text-zinc-400",
            )}
          >
            {item.name}
          </h3>
          <span className="rounded border border-zinc-800 px-1.5 py-0.5 text-[10px] uppercase tracking-wider text-zinc-500">
            {item.category}
          </span>
          {item.unlocked ? (
            <span className="rounded bg-emerald-500/15 px-1.5 py-0.5 text-[10px] font-medium text-emerald-300">
              Unlocked
            </span>
          ) : (
            <span className="rounded bg-zinc-800 px-1.5 py-0.5 text-[10px] font-medium text-zinc-500">
              Locked
            </span>
          )}
        </div>
        <p className="mt-0.5 line-clamp-2 text-sm text-zinc-500 sm:line-clamp-1">
          {item.description}
        </p>
      </div>

      <div className="shrink-0 text-right">
        <div className="text-sm font-semibold text-amber-400">
          {formatPoints(item.points)}
        </div>
        <div className="text-[10px] uppercase tracking-wider text-zinc-600">pts</div>
      </div>
    </li>
  );
}

function AchievementCardRow({ item }: { item: CatalogAchievement }) {
  const Icon = getAchievementIcon(item.icon);

  return (
    <article
      className={cn(
        "rounded-xl border bg-zinc-900/60 p-4 transition",
        item.unlocked
          ? "border-amber-500/25 hover:border-amber-400/50"
          : "border-zinc-800 opacity-80 hover:opacity-100",
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div
          className={cn(
            "flex h-10 w-10 items-center justify-center rounded-lg border",
            item.unlocked
              ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
              : "border-zinc-700 bg-zinc-950 text-zinc-500",
          )}
        >
          {item.unlocked ? <Icon className="h-4.5 w-4.5" /> : <Lock className="h-4 w-4" />}
        </div>
        <div className="text-right">
          <div className="font-semibold text-amber-400">{formatPoints(item.points)} pts</div>
          <div className="mt-1 text-[10px] uppercase tracking-wider text-zinc-500">
            {item.category}
          </div>
        </div>
      </div>
      <h3
        className={cn(
          "mt-3 font-[family-name:var(--font-display)] text-lg",
          item.unlocked ? "text-zinc-50" : "text-zinc-400",
        )}
      >
        {item.name}
      </h3>
      <p className="mt-1.5 line-clamp-3 text-sm leading-relaxed text-zinc-400">
        {item.description}
      </p>
      <div className="mt-3 text-xs">
        {item.unlocked ? (
          <span className="text-emerald-400">Unlocked</span>
        ) : (
          <span className="text-zinc-600">Locked</span>
        )}
      </div>
    </article>
  );
}

function DensityButton({
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
      onClick={onClick}
      className={cn(
        "inline-flex items-center gap-1.5 rounded px-2.5 py-1.5 text-xs transition",
        active ? "bg-zinc-100 text-zinc-950" : "text-zinc-400 hover:text-zinc-200",
      )}
      aria-pressed={active}
    >
      {icon}
      <span className="hidden sm:inline">{label}</span>
    </button>
  );
}
