import type { CharacterAchievementRow } from "@/lib/types";
import { cn, formatPoints, formatRelativeTime } from "@/lib/utils";

interface AchievementTimelineProps {
  items: CharacterAchievementRow[];
}

export function AchievementTimeline({ items }: AchievementTimelineProps) {
  if (!items.length) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-12 text-center text-sm text-zinc-500">
        No achievements unlocked yet.
      </div>
    );
  }

  return (
    <ol className="relative ml-3 space-y-0 border-l border-zinc-800 sm:ml-4">
      {items.map((item, index) => {
        const points = item.achievements?.points ?? 0;
        const isLatest = index === 0;
        return (
          <li key={item.id} className="relative pb-8 pl-6 last:pb-0 sm:pl-8">
            <span
              className={cn(
                "absolute top-1.5 -left-[5px] h-2.5 w-2.5 rounded-full border-2",
                isLatest
                  ? "border-amber-400 bg-amber-500 shadow-[0_0_12px_rgba(245,158,11,0.55)]"
                  : "border-zinc-600 bg-zinc-800",
              )}
            />
            <div
              className={cn(
                "rounded-xl border bg-zinc-900/60 p-4 transition hover:border-amber-500/35",
                isLatest ? "border-amber-500/30" : "border-zinc-800",
              )}
            >
              <div className="flex flex-wrap items-start justify-between gap-3">
                <div>
                  <p className="text-[11px] uppercase tracking-wider text-zinc-500">
                    {item.achievements?.category ?? "Achievement"}
                  </p>
                  <h3 className="mt-1 font-[family-name:var(--font-display)] text-lg text-zinc-50">
                    {item.achievements?.name ?? item.achievement_id}
                  </h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-zinc-400">
                    {item.achievements?.description ?? "Unlocked achievement."}
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-sm font-semibold text-amber-400">
                    +{formatPoints(points)} pts
                  </div>
                  <div className="mt-1 text-xs text-zinc-500">
                    {formatRelativeTime(item.unlocked_at)}
                  </div>
                  <div className="mt-0.5 text-[11px] text-zinc-600">
                    {new Date(item.unlocked_at).toLocaleString()}
                  </div>
                </div>
              </div>
            </div>
          </li>
        );
      })}
    </ol>
  );
}
