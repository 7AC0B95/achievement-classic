import { Lock } from "lucide-react";
import { getAchievementIcon } from "@/lib/achievement-icons";
import type { AchievementCategory } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

interface AchievementCardProps {
  id: string;
  name: string;
  description: string;
  category: AchievementCategory;
  points: number;
  icon?: string | null;
  unlocked?: boolean;
  unlockedAt?: string | null;
}

export function AchievementCard({
  name,
  description,
  category,
  points,
  icon,
  unlocked = false,
  unlockedAt,
}: AchievementCardProps) {
  const Icon = getAchievementIcon(icon);

  return (
    <article
      className={cn(
        "group relative overflow-hidden rounded-xl border bg-zinc-900/60 p-5 transition duration-300",
        unlocked
          ? "border-amber-500/30 hover:border-amber-400/60 hover:shadow-[0_0_28px_rgba(245,158,11,0.12)]"
          : "border-zinc-800 opacity-70 hover:border-zinc-700 hover:opacity-90",
      )}
    >
      <div className="mb-4 flex items-start justify-between gap-3">
        <div
          className={cn(
            "flex h-11 w-11 items-center justify-center rounded-lg border",
            unlocked
              ? "border-amber-500/40 bg-amber-500/10 text-amber-300"
              : "border-zinc-700 bg-zinc-950 text-zinc-500",
          )}
        >
          {unlocked ? <Icon className="h-5 w-5" /> : <Lock className="h-4 w-4" />}
        </div>
        <div className="text-right">
          <div className="font-semibold text-amber-400">{formatPoints(points)} pts</div>
          <div className="mt-1 text-[11px] uppercase tracking-wider text-zinc-500">
            {category}
          </div>
        </div>
      </div>

      <h3
        className={cn(
          "font-[family-name:var(--font-display)] text-lg",
          unlocked ? "text-zinc-50" : "text-zinc-400",
        )}
      >
        {name}
      </h3>
      <p className="mt-2 text-sm leading-relaxed text-zinc-400">{description}</p>

      {unlocked && unlockedAt ? (
        <p className="mt-4 text-xs text-emerald-400/90">
          Unlocked {new Date(unlockedAt).toLocaleString()}
        </p>
      ) : null}
    </article>
  );
}
