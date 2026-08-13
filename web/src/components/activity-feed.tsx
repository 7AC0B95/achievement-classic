import Link from "next/link";
import { AddonDownloadButton } from "@/components/addon-download-button";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import type { CharacterAchievementRow } from "@/lib/types";
import { formatPoints, formatRelativeTime } from "@/lib/utils";

interface ActivityFeedProps {
  items: CharacterAchievementRow[];
  title?: string;
}

export function ActivityFeed({ items, title = "Live activity" }: ActivityFeedProps) {
  return (
    <section className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-5">
      <div className="mb-4 flex items-center justify-between">
        <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50">
          {title}
        </h2>
        <span className="inline-flex items-center gap-2 text-xs uppercase tracking-wider text-emerald-400">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-emerald-400 opacity-60" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-emerald-400" />
          </span>
          Live
        </span>
      </div>

      {items.length === 0 ? (
        <p className="rounded-lg border border-dashed border-zinc-800 bg-zinc-950/40 px-4 py-10 text-center text-sm text-zinc-500">
          No unlocks yet.{" "}
          <AddonDownloadButton variant="link">Download the addon</AddonDownloadButton>
          , play, then{" "}
          <Link href="/dashboard" className="font-medium text-amber-400 hover:text-amber-300">
            sync SavedVariables
          </Link>{" "}
          from the dashboard.
        </p>
      ) : (
        <ul className="space-y-3">
          {items.map((item) => {
            const classColor = getClassColor(item.characters?.class ?? "WARRIOR");
            const profileHref = item.characters?.id
              ? `/characters/${item.characters.id}`
              : null;
            const name = (
              <span className="font-semibold" style={{ color: classColor }}>
                {item.characters?.name ?? "Unknown"}
              </span>
            );

            return (
              <li
                key={item.id}
                className="flex items-start justify-between gap-4 rounded-lg border border-zinc-800/80 bg-zinc-950/50 px-3 py-3 transition hover:border-amber-500/30"
              >
                <div>
                  <p className="text-sm text-zinc-200">
                    {profileHref ? (
                      <Link href={profileHref} className="hover:underline">
                        {name}
                      </Link>
                    ) : (
                      name
                    )}
                    <span className="text-zinc-500">
                      {" "}
                      ({item.characters?.realm}) ·{" "}
                      {getClassLabel(item.characters?.class ?? "")}
                    </span>
                  </p>
                  <p className="mt-1 text-sm text-zinc-400">
                    unlocked{" "}
                    <span className="text-amber-300">
                      {item.achievements?.name ?? item.achievement_id}
                    </span>
                  </p>
                </div>
                <div className="shrink-0 text-right">
                  <div className="text-sm font-semibold text-amber-400">
                    +{formatPoints(item.achievements?.points ?? 0)}
                  </div>
                  <div className="mt-1 text-[11px] text-zinc-500">
                    {formatRelativeTime(item.unlocked_at)}
                  </div>
                </div>
              </li>
            );
          })}
        </ul>
      )}
    </section>
  );
}
