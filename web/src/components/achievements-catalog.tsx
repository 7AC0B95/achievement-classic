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
import { useDeferredValue, useMemo, useState, type ReactNode, createElement } from "react";
import { CharacterSelect } from "@/components/character-select";
import {
  ACHIEVEMENT_CATEGORIES,
  type AchievementDensity,
  type AchievementProgressFilter,
  type AchievementSort,
} from "@/lib/achievement-filters";
import { getAchievementIcon } from "@/lib/achievement-icons";
import {
  formatCharacterLabel,
  getCompareOutcome,
  type CompareOutcome,
} from "@/lib/active-character";
import type { AchievementCategory, AchievementRow, CharacterRow } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

export interface CatalogAchievement extends AchievementRow {
  unlocked: boolean;
  compareUnlocked?: boolean;
}

interface AchievementsCatalogProps {
  achievements: CatalogAchievement[];
  characters: CharacterRow[];
  selected: CharacterRow | null;
  compareCharacter: CharacterRow | null;
}

export function AchievementsCatalog({
  achievements,
  characters,
  selected,
  compareCharacter,
}: AchievementsCatalogProps) {
  const [query, setQuery] = useState("");
  const [categories, setCategories] = useState<AchievementCategory[]>([]);
  const [progress, setProgress] = useState<AchievementProgressFilter>("all");
  const [sort, setSort] = useState<AchievementSort>("points_desc");
  const [density, setDensity] = useState<AchievementDensity>("compact");
  const [groupByCategory, setGroupByCategory] = useState(true);

  const deferredQuery = useDeferredValue(query.trim().toLowerCase());
  const comparing = Boolean(compareCharacter);
  const characterLabel = selected ? formatCharacterLabel(selected) : null;
  const compareLabel = compareCharacter
    ? formatCharacterLabel(compareCharacter)
    : null;
  const compareOptions = [
    ...(compareCharacter &&
    !characters.some((character) => character.id === compareCharacter.id)
      ? [compareCharacter]
      : []),
    ...characters.filter((character) => character.id !== selected?.id),
  ];

  const totals = useMemo(() => {
    const unlocked = achievements.filter((a) => a.unlocked);
    const compareUnlocked = achievements.filter((a) => a.compareUnlocked);
    const shared = achievements.filter((a) => a.unlocked && a.compareUnlocked);
    const onlyYou = achievements.filter((a) => a.unlocked && !a.compareUnlocked);
    const onlyThem = achievements.filter((a) => !a.unlocked && a.compareUnlocked);
    return {
      count: achievements.length,
      unlocked: unlocked.length,
      points: achievements.reduce((sum, a) => sum + a.points, 0),
      earnedPoints: unlocked.reduce((sum, a) => sum + a.points, 0),
      compareCount: compareUnlocked.length,
      comparePoints: compareUnlocked.reduce((sum, a) => sum + a.points, 0),
      shared: shared.length,
      onlyYou: onlyYou.length,
      onlyThem: onlyThem.length,
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

    const mode =
      comparing ||
      progress === "all" ||
      progress === "unlocked" ||
      progress === "locked"
        ? progress
        : "all";

    if (mode === "unlocked") rows = rows.filter((a) => a.unlocked);
    if (mode === "locked") rows = rows.filter((a) => !a.unlocked);
    if (mode === "shared") {
      rows = rows.filter((a) => a.unlocked && a.compareUnlocked);
    }
    if (mode === "only_you") {
      rows = rows.filter((a) => a.unlocked && !a.compareUnlocked);
    }
    if (mode === "only_them") {
      rows = rows.filter((a) => !a.unlocked && a.compareUnlocked);
    }

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
  }, [achievements, deferredQuery, categories, progress, sort, comparing]);

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
  const comparePct =
    totals.count === 0 ? 0 : Math.round((totals.compareCount / totals.count) * 100);

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
              {characterLabel ? null : (
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

        {characters.length > 0 ? (
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <CharacterSelect
              characters={characters}
              selectedId={selected?.id ?? null}
              persistActive
              urlParam="character"
              label="Active character"
            />
            {compareOptions.length > 0 || compareCharacter ? (
              <CharacterSelect
                characters={compareOptions}
                selectedId={compareCharacter?.id ?? null}
                allowEmpty
                emptyLabel="No comparison"
                urlParam="compare"
                label="Compare with"
              />
            ) : (
              <p className="self-end text-sm text-zinc-500">
                Sync another character, or open a public profile to compare.
              </p>
            )}
          </div>
        ) : null}

        {comparing && compareLabel && characterLabel ? (
          <div className="mt-5 grid gap-3 sm:grid-cols-2">
            <CompareMeter
              label={characterLabel}
              caption={`${totals.unlocked}/${totals.count} · ${formatPoints(totals.earnedPoints)} pts`}
              percent={progressPct}
              tone="you"
            />
            <CompareMeter
              label={compareLabel}
              caption={`${totals.compareCount}/${totals.count} · ${formatPoints(totals.comparePoints)} pts`}
              percent={comparePct}
              tone="them"
            />
          </div>
        ) : (
          <div className="mt-4 h-2 overflow-hidden rounded-full bg-zinc-950">
            <div
              className="h-full rounded-full bg-gradient-to-r from-amber-600 to-amber-400 transition-all duration-500"
              style={{ width: `${progressPct}%` }}
            />
          </div>
        )}

        {comparing ? (
          <div className="mt-4 flex flex-wrap gap-2 text-xs">
            <span className="rounded-md bg-emerald-500/15 px-2 py-1 text-emerald-300">
              Shared {totals.shared}
            </span>
            <span className="rounded-md bg-sky-500/15 px-2 py-1 text-sky-300">
              Only {selected?.name ?? "you"} {totals.onlyYou}
            </span>
            <span className="rounded-md bg-lime-500/15 px-2 py-1 text-lime-300">
              Only {compareCharacter?.name ?? "them"} {totals.onlyThem}
            </span>
          </div>
        ) : null}
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
              ] as Array<[AchievementProgressFilter, string]>
            )
              .concat(
                comparing
                  ? [
                      ["shared", "Shared"],
                      ["only_you", `Only ${selected?.name ?? "you"}`],
                      ["only_them", `Only ${compareCharacter?.name ?? "them"}`],
                    ]
                  : [],
              )
              .map(([value, filterLabel]) => (
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
                {filterLabel}
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
              <AchievementResults
                items={group.items}
                density={density}
                comparing={comparing}
                youName={selected?.name ?? "You"}
                themName={compareCharacter?.name ?? "Them"}
              />
            </section>
          ))}
        </div>
      ) : (
        <AchievementResults
          items={filtered}
          density={density}
          comparing={comparing}
          youName={selected?.name ?? "You"}
          themName={compareCharacter?.name ?? "Them"}
        />
      )}
    </div>
  );
}

function AchievementResults({
  items,
  density,
  comparing,
  youName,
  themName,
}: {
  items: CatalogAchievement[];
  density: AchievementDensity;
  comparing: boolean;
  youName: string;
  themName: string;
}) {
  if (density === "comfortable") {
    return (
      <div className="grid gap-3 sm:grid-cols-2 xl:grid-cols-3">
        {items.map((item) => (
          <AchievementCardRow
            key={item.id}
            item={item}
            comparing={comparing}
            youName={youName}
            themName={themName}
          />
        ))}
      </div>
    );
  }

  return (
    <ul className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/40 divide-y divide-zinc-800/80">
      {items.map((item) => (
        <AchievementListRow
          key={item.id}
          item={item}
          comparing={comparing}
          youName={youName}
          themName={themName}
        />
      ))}
    </ul>
  );
}

function AchievementListRow({
  item,
  comparing,
  youName,
  themName,
}: {
  item: CatalogAchievement;
  comparing: boolean;
  youName: string;
  themName: string;
}) {
  const themUnlocked = Boolean(item.compareUnlocked);
  const earned = item.unlocked || (comparing && themUnlocked);
  const outcome = comparing
    ? getCompareOutcome(item.unlocked, themUnlocked)
    : null;

  return (
    <li
      className={cn(
        "flex items-start gap-3 px-3 py-3 transition sm:items-center sm:px-4",
        "hover:bg-zinc-800/35",
        !earned && "opacity-75",
      )}
    >
      <div
        className={cn(
          "mt-0.5 flex h-9 w-9 shrink-0 items-center justify-center rounded-md border sm:mt-0",
          earned
            ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
            : "border-zinc-700 bg-zinc-950 text-zinc-500",
        )}
      >
        {earned
          ? createElement(getAchievementIcon(item.icon), { className: "h-4 w-4" })
          : <Lock className="h-3.5 w-3.5" />}
      </div>

      <div className="min-w-0 flex-1">
        <div className="flex flex-wrap items-center gap-x-2 gap-y-1">
          <h3
            className={cn(
              "truncate font-medium",
              earned ? "text-zinc-50" : "text-zinc-400",
            )}
          >
            {item.name}
          </h3>
          <span className="rounded border border-zinc-800 px-1.5 py-0.5 text-[10px] uppercase tracking-wider text-zinc-500">
            {item.category}
          </span>
          {comparing && outcome ? (
            <CompareTag outcome={outcome} />
          ) : item.unlocked ? (
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
        {comparing ? (
          <div className="mt-1.5">
            <ComparePills
              you={item.unlocked}
              them={themUnlocked}
              youName={youName}
              themName={themName}
            />
          </div>
        ) : null}
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

function AchievementCardRow({
  item,
  comparing,
  youName,
  themName,
}: {
  item: CatalogAchievement;
  comparing: boolean;
  youName: string;
  themName: string;
}) {
  const themUnlocked = Boolean(item.compareUnlocked);
  const earned = item.unlocked || (comparing && themUnlocked);
  const outcome = comparing
    ? getCompareOutcome(item.unlocked, themUnlocked)
    : null;

  return (
    <article
      className={cn(
        "rounded-xl border bg-zinc-900/60 p-4 transition",
        earned
          ? "border-amber-500/25 hover:border-amber-400/50"
          : "border-zinc-800 opacity-80 hover:opacity-100",
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div
          className={cn(
            "flex h-10 w-10 items-center justify-center rounded-lg border",
            earned
              ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
              : "border-zinc-700 bg-zinc-950 text-zinc-500",
          )}
        >
          {earned
            ? createElement(getAchievementIcon(item.icon), { className: "h-4.5 w-4.5" })
            : <Lock className="h-4 w-4" />}
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
          earned ? "text-zinc-50" : "text-zinc-400",
        )}
      >
        {item.name}
      </h3>
      <p className="mt-1.5 line-clamp-3 text-sm leading-relaxed text-zinc-400">
        {item.description}
      </p>
      <div className="mt-3">
        {comparing && outcome ? (
          <div className="flex flex-col gap-2">
            <ComparePills
              you={item.unlocked}
              them={themUnlocked}
              youName={youName}
              themName={themName}
            />
            <CompareTag outcome={outcome} />
          </div>
        ) : item.unlocked ? (
          <span className="text-xs text-emerald-400">Unlocked</span>
        ) : (
          <span className="text-xs text-zinc-600">Locked</span>
        )}
      </div>
    </article>
  );
}

function CompareMeter({
  label,
  caption,
  percent,
  tone,
}: {
  label: string;
  caption: string;
  percent: number;
  tone: "you" | "them";
}) {
  return (
    <div>
      <div className="flex items-baseline justify-between gap-2 text-sm">
        <span className="truncate font-medium text-zinc-200">{label}</span>
        <span className="shrink-0 text-xs text-zinc-500">{caption}</span>
      </div>
      <div className="mt-1.5 h-2 overflow-hidden rounded-full bg-zinc-950">
        <div
          className={cn(
            "h-full rounded-full transition-all duration-500",
            tone === "you"
              ? "bg-gradient-to-r from-sky-600 to-sky-400"
              : "bg-gradient-to-r from-lime-700 to-lime-400",
          )}
          style={{ width: `${percent}%` }}
        />
      </div>
    </div>
  );
}

function ComparePills({
  you,
  them,
  youName,
  themName,
}: {
  you: boolean;
  them: boolean;
  youName: string;
  themName: string;
}) {
  return (
    <div className="flex flex-wrap gap-1.5">
      <span
        className={cn(
          "rounded px-1.5 py-0.5 text-[10px] font-medium",
          you ? "bg-sky-500/15 text-sky-300" : "bg-zinc-800 text-zinc-600",
        )}
      >
        {youName}
      </span>
      <span
        className={cn(
          "rounded px-1.5 py-0.5 text-[10px] font-medium",
          them ? "bg-lime-500/15 text-lime-300" : "bg-zinc-800 text-zinc-600",
        )}
      >
        {themName}
      </span>
    </div>
  );
}

function CompareTag({ outcome }: { outcome: CompareOutcome }) {
  if (outcome === "none") {
    return (
      <span className="rounded bg-zinc-800 px-1.5 py-0.5 text-[10px] font-medium text-zinc-500">
        Locked
      </span>
    );
  }

  const copy =
    outcome === "shared"
      ? "Shared"
      : outcome === "only_you"
        ? "Only you"
        : "Only them";
  const tone =
    outcome === "shared"
      ? "bg-emerald-500/15 text-emerald-300"
      : outcome === "only_you"
        ? "bg-sky-500/15 text-sky-300"
        : "bg-lime-500/15 text-lime-300";

  return (
    <span className={cn("rounded px-1.5 py-0.5 text-[10px] font-medium", tone)}>
      {copy}
    </span>
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
