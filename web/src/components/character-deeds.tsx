import type { ProfileHighlights } from "@/lib/character-profile";
import type { CharacterProfileAchievement } from "@/lib/types";
import { cn, formatPoints, formatRelativeTime } from "@/lib/utils";

interface CharacterDeedsProps {
  highlights: ProfileHighlights;
}

export function CharacterDeeds({ highlights }: CharacterDeedsProps) {
  const { latest, highest, first, strongestCategory, suggestedNext, recent } =
    highlights;
  const hasDeeds = latest || highest || first || strongestCategory;

  return (
    <section className="space-y-4">
      <div>
        <h2 className="font-[family-name:var(--font-display)] text-2xl text-zinc-50">
          Notable deeds
        </h2>
        <p className="mt-1 text-sm text-zinc-500">
          Highlights from this character&apos;s catalog, plus a few next targets.
        </p>
      </div>

      {hasDeeds ? (
        <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
          <DeedCard
            label="Latest unlock"
            title={latest?.name ?? "—"}
            detail={
              latest?.unlocked_at ? formatRelativeTime(latest.unlocked_at) : "No unlocks yet"
            }
          />
          <DeedCard
            label="Highest point"
            title={highest?.name ?? "—"}
            detail={highest ? `${formatPoints(highest.points)} pts` : "No unlocks yet"}
          />
          <DeedCard
            label="Strongest category"
            title={strongestCategory?.category ?? "—"}
            detail={
              strongestCategory
                ? `${strongestCategory.unlocked}/${strongestCategory.total} · ${strongestCategory.percent}%`
                : "No progress yet"
            }
          />
          <DeedCard
            label="First unlock"
            title={first?.name ?? "—"}
            detail={
              first?.unlocked_at
                ? new Date(first.unlocked_at).toLocaleDateString()
                : "Career not started"
            }
          />
        </div>
      ) : (
        <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-10 text-center text-sm text-zinc-500">
          No unlocks yet. Sync this character to start the dossier.
        </div>
      )}

      {suggestedNext.length > 0 ? (
        <div>
          <h3 className="text-xs uppercase tracking-wider text-zinc-500">Suggested next</h3>
          <ul className="mt-2 grid gap-2 sm:grid-cols-3">
            {suggestedNext.map((item) => (
              <li
                key={item.id}
                className="rounded-lg border border-zinc-800 bg-zinc-900/50 px-3 py-2.5"
              >
                <p className="text-[11px] uppercase tracking-wider text-zinc-500">
                  {item.category}
                </p>
                <p className="mt-1 font-medium text-zinc-100">{item.name}</p>
                <p className="mt-1 line-clamp-2 text-xs text-zinc-500">{item.description}</p>
                <p className="mt-2 text-xs font-semibold text-amber-400">
                  {formatPoints(item.points)} pts
                </p>
              </li>
            ))}
          </ul>
        </div>
      ) : null}

      {recent.length > 0 ? (
        <div>
          <h3 className="text-xs uppercase tracking-wider text-zinc-500">Recent unlocks</h3>
          <ul className="mt-2 grid gap-2 sm:grid-cols-2 lg:grid-cols-5">
            {recent.map((item, index) => (
              <RecentUnlockCard key={item.id} item={item} featured={index === 0} />
            ))}
          </ul>
        </div>
      ) : null}
    </section>
  );
}

function DeedCard({
  label,
  title,
  detail,
}: {
  label: string;
  title: string;
  detail: string;
}) {
  return (
    <article className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-4">
      <p className="text-[11px] uppercase tracking-wider text-zinc-500">{label}</p>
      <h3 className="mt-1.5 font-[family-name:var(--font-display)] text-lg text-zinc-50">
        {title}
      </h3>
      <p className="mt-1 text-xs text-zinc-500">{detail}</p>
    </article>
  );
}

function RecentUnlockCard({
  item,
  featured,
}: {
  item: CharacterProfileAchievement;
  featured: boolean;
}) {
  return (
    <li
      className={cn(
        "rounded-xl border bg-zinc-900/60 p-3",
        featured ? "border-amber-500/30" : "border-zinc-800",
      )}
    >
      <p className="text-[10px] uppercase tracking-wider text-zinc-500">{item.category}</p>
      <h4 className="mt-1 line-clamp-2 text-sm font-medium text-zinc-100">{item.name}</h4>
      <div className="mt-2 flex items-baseline justify-between gap-2">
        <span className="text-xs font-semibold text-amber-400">
          +{formatPoints(item.points)}
        </span>
        <span className="text-[11px] text-zinc-500">
          {item.unlocked_at ? formatRelativeTime(item.unlocked_at) : ""}
        </span>
      </div>
    </li>
  );
}
