"use client";

import { ACHIEVEMENT_CATEGORIES } from "@/lib/achievement-filters";
import { getAchievementIcon } from "@/lib/achievement-icons";
import type { CharacterProfileAchievement } from "@/lib/types";
import { cn, formatDate, formatPoints, formatTime } from "@/lib/utils";
import { Lock } from "lucide-react";
import { createElement, Fragment } from "react";

interface CharacterAchievementsTableProps {
  items: CharacterProfileAchievement[];
  grouped: boolean;
}

export function CharacterAchievementsTable({
  items,
  grouped,
}: CharacterAchievementsTableProps) {
  if (!items.length) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-4 py-12 text-center text-sm text-zinc-500 sm:px-6">
        No achievements match these filters.
      </div>
    );
  }

  const groups = grouped
    ? ACHIEVEMENT_CATEGORIES.map((category) => ({
        category,
        items: items.filter((item) => item.category === category),
      })).filter((group) => group.items.length > 0)
    : null;

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/50">
      <div className="md:hidden">
        {groups ? (
          groups.map((group) => (
            <div key={group.category}>
              <div className="bg-zinc-950/70 px-3 py-2 text-xs font-medium uppercase tracking-wider text-zinc-400">
                {group.category}
                <span className="ml-2 font-normal text-zinc-600">
                  {group.items.length}
                </span>
              </div>
              <ul className="divide-y divide-zinc-800/80">
                {group.items.map((item) => (
                  <AchievementCardRow key={item.id} item={item} />
                ))}
              </ul>
            </div>
          ))
        ) : (
          <ul className="divide-y divide-zinc-800/80">
            {items.map((item) => (
              <AchievementCardRow key={item.id} item={item} />
            ))}
          </ul>
        )}
      </div>

      <div className="hidden overflow-x-auto md:block">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-800 bg-zinc-950/80 text-xs uppercase tracking-wider text-zinc-500">
            <tr>
              <th className="px-4 py-3 font-medium">Achievement</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium text-right">Points</th>
              <th className="px-4 py-3 font-medium text-right">Unlocked</th>
            </tr>
          </thead>
          {groups ? (
            groups.map((group) => (
              <Fragment key={group.category}>
                <tbody>
                  <tr className="bg-zinc-950/70">
                    <th
                      colSpan={4}
                      className="px-4 py-2 text-left text-xs font-medium uppercase tracking-wider text-zinc-400"
                    >
                      {group.category}
                      <span className="ml-2 font-normal text-zinc-600">
                        {group.items.length}
                      </span>
                    </th>
                  </tr>
                  {group.items.map((item) => (
                    <AchievementRow key={item.id} item={item} />
                  ))}
                </tbody>
              </Fragment>
            ))
          ) : (
            <tbody>
              {items.map((item) => (
                <AchievementRow key={item.id} item={item} />
              ))}
            </tbody>
          )}
        </table>
      </div>
    </div>
  );
}

function AchievementCardRow({ item }: { item: CharacterProfileAchievement }) {
  return (
    <li
      className={cn(
        "flex items-start gap-3 px-3 py-3",
        !item.unlocked && "opacity-70",
      )}
    >
      <AchievementIcon item={item} />
      <div className="min-w-0 flex-1">
        <div
          className={cn(
            "font-medium",
            item.unlocked ? "text-zinc-100" : "text-zinc-400",
          )}
        >
          {item.name}
        </div>
        <p className="mt-0.5 line-clamp-2 text-xs text-zinc-500">
          {item.description}
        </p>
        <div className="mt-1.5 flex flex-wrap items-center gap-x-2 gap-y-1 text-xs text-zinc-500">
          <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2 py-0.5 text-zinc-300">
            {item.category}
          </span>
          {item.unlocked && item.unlocked_at ? (
            <span>
              {formatDate(item.unlocked_at)} · {formatTime(item.unlocked_at)}
            </span>
          ) : (
            <span className="text-zinc-600">Locked</span>
          )}
        </div>
      </div>
      <div className="shrink-0 text-right">
        <div className="text-sm font-semibold text-amber-400">
          {formatPoints(item.points)}
        </div>
        <div className="text-[10px] uppercase tracking-wider text-zinc-600">
          pts
        </div>
      </div>
    </li>
  );
}

function AchievementRow({ item }: { item: CharacterProfileAchievement }) {
  return (
    <tr
      className={cn(
        "border-b border-zinc-800/80 transition hover:bg-zinc-800/40",
        !item.unlocked && "opacity-70",
      )}
    >
      <td className="px-4 py-3">
        <div className="flex items-start gap-3">
          <AchievementIcon item={item} />
          <div className="min-w-0">
            <div className={cn("font-medium", item.unlocked ? "text-zinc-100" : "text-zinc-400")}>
              {item.name}
            </div>
            <div className="mt-0.5 max-w-md text-xs text-zinc-500">{item.description}</div>
          </div>
        </div>
      </td>
      <td className="px-4 py-3">
        <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2 py-0.5 text-xs text-zinc-300">
          {item.category}
        </span>
      </td>
      <td className="px-4 py-3 text-right font-semibold text-amber-400">
        {formatPoints(item.points)}
      </td>
      <td className="px-4 py-3 text-right text-zinc-400">
        {item.unlocked && item.unlocked_at ? (
          <>
            <div>{formatDate(item.unlocked_at)}</div>
            <div className="text-[11px] text-zinc-600">
              {formatTime(item.unlocked_at)}
            </div>
          </>
        ) : (
          <span className="text-xs text-zinc-600">Locked</span>
        )}
      </td>
    </tr>
  );
}

function AchievementIcon({ item }: { item: CharacterProfileAchievement }) {
  return (
    <div
      className={cn(
        "mt-0.5 flex h-8 w-8 shrink-0 items-center justify-center rounded-md border",
        item.unlocked
          ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
          : "border-zinc-700 bg-zinc-950 text-zinc-500",
      )}
    >
      {item.unlocked
        ? createElement(getAchievementIcon(item.icon), { className: "h-4 w-4" })
        : <Lock className="h-3.5 w-3.5" />}
    </div>
  );
}
