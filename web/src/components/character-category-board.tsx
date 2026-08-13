"use client";

import type { CategoryProgress } from "@/lib/character-profile";
import type { AchievementCategory } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

interface CharacterCategoryBoardProps {
  progress: CategoryProgress[];
  selected: AchievementCategory[];
  onSelect: (category: AchievementCategory) => void;
}

export function CharacterCategoryBoard({
  progress,
  selected,
  onSelect,
}: CharacterCategoryBoardProps) {
  return (
    <section className="space-y-3">
      <div>
        <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50 sm:text-2xl">
          Category progress
        </h2>
        <p className="mt-1 text-sm text-zinc-500">
          Select a category to filter the ledger below.
        </p>
      </div>
      <div className="grid grid-cols-2 gap-2 sm:gap-3 lg:grid-cols-5">
        {progress.map((entry) => {
          const active = selected.includes(entry.category);
          return (
            <button
              key={entry.category}
              type="button"
              onClick={() => onSelect(entry.category)}
              aria-pressed={active}
              className={cn(
                "rounded-xl border bg-zinc-900/60 p-3 text-left transition min-h-11",
                active
                  ? "border-amber-500/50 bg-amber-500/10"
                  : "border-zinc-800 hover:border-amber-500/35",
              )}
            >
              <div className="flex items-baseline justify-between gap-2">
                <h3 className="min-w-0 text-sm font-medium break-words text-zinc-100">{entry.category}</h3>
                <span className="shrink-0 text-xs text-zinc-500">
                  {entry.unlocked}/{entry.total}
                </span>
              </div>
              <div className="mt-2 h-1.5 overflow-hidden rounded-full bg-zinc-950">
                <div
                  className="h-full rounded-full bg-gradient-to-r from-amber-600 to-amber-400"
                  style={{ width: `${entry.percent}%` }}
                />
              </div>
              <p className="mt-2 text-[11px] text-zinc-500">
                {formatPoints(entry.pointsEarned)} / {formatPoints(entry.pointsAvailable)} pts
                <span className="ml-1 text-zinc-600">· {entry.percent}%</span>
              </p>
            </button>
          );
        })}
      </div>
    </section>
  );
}
