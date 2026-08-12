"use client";

import { LayoutList, Table2 } from "lucide-react";
import { useState, type ReactNode } from "react";
import { AchievementTimeline } from "@/components/achievement-timeline";
import { CharacterAchievementsTable } from "@/components/character-achievements-table";
import type { CharacterAchievementRow } from "@/lib/types";
import { cn } from "@/lib/utils";

type ProfileView = "timeline" | "table";

interface CharacterAchievementsPanelProps {
  items: CharacterAchievementRow[];
}

export function CharacterAchievementsPanel({
  items,
}: CharacterAchievementsPanelProps) {
  const [view, setView] = useState<ProfileView>("timeline");

  return (
    <section className="space-y-4">
      <div className="flex flex-wrap items-center justify-between gap-3">
        <div>
          <h2 className="font-[family-name:var(--font-display)] text-2xl text-zinc-50">
            Earned achievements
          </h2>
          <p className="mt-1 text-sm text-zinc-500">
            {items.length} unlock{items.length === 1 ? "" : "s"} · switch between
            timeline and table
          </p>
        </div>

        <div
          className="inline-flex rounded-lg border border-zinc-800 bg-zinc-950 p-1"
          role="tablist"
          aria-label="Achievement view"
        >
          <ViewTab
            active={view === "timeline"}
            onClick={() => setView("timeline")}
            icon={<LayoutList className="h-4 w-4" />}
            label="Timeline"
          />
          <ViewTab
            active={view === "table"}
            onClick={() => setView("table")}
            icon={<Table2 className="h-4 w-4" />}
            label="Table"
          />
        </div>
      </div>

      {view === "timeline" ? (
        <AchievementTimeline items={items} />
      ) : (
        <CharacterAchievementsTable items={items} />
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
