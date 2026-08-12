import type { CharacterProfileAchievement } from "@/lib/types";
import { cn, formatDateTime, formatPoints, formatRelativeTime } from "@/lib/utils";

interface AchievementTimelineProps {
  items: CharacterProfileAchievement[];
}

export function AchievementTimeline({ items }: AchievementTimelineProps) {
  const earned = items
    .filter((item) => item.unlocked && item.unlocked_at)
    .sort(
      (a, b) =>
        new Date(b.unlocked_at!).getTime() - new Date(a.unlocked_at!).getTime(),
    );

  if (!earned.length) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-12 text-center text-sm text-zinc-500">
        No achievements unlocked yet.
      </div>
    );
  }

  return (
    <ol className="relative ml-3 space-y-0 border-l border-zinc-800 sm:ml-4">
      {earned.map((item, index) => {
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
                    {item.category}
                  </p>
                  <h3 className="mt-1 font-[family-name:var(--font-display)] text-lg text-zinc-50">
                    {item.name}
                  </h3>
                  <p className="mt-1.5 text-sm leading-relaxed text-zinc-400">
                    {item.description}
                  </p>
                </div>
                <div className="text-right">
                  <div className="text-sm font-semibold text-amber-400">
                    +{formatPoints(item.points)} pts
                  </div>
                  <div className="mt-1 text-xs text-zinc-500">
                    {formatRelativeTime(item.unlocked_at!)}
                  </div>
                  <div className="mt-0.5 text-[11px] text-zinc-600">
                    {formatDateTime(item.unlocked_at!)}
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
