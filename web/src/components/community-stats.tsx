import Link from "next/link";
import type { ReactNode } from "react";
import { AddonDownloadButton } from "@/components/addon-download-button";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import { getFactionColor, getRaceLabel } from "@/lib/factions";
import type {
  CommunityAchievementStat,
  CommunityCategoryStat,
  CommunityClassStat,
  CommunityFactionStat,
  CommunityRaceStat,
  CommunityRealmStat,
  CommunityStats,
} from "@/lib/types";
import { cn, formatPoints, formatRelativeTime } from "@/lib/utils";

interface CommunityStatsViewProps {
  stats: CommunityStats | null;
}

export function CommunityStatsView({ stats }: CommunityStatsViewProps) {
  if (!stats || stats.overview.characters === 0) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/40 px-4 py-12 text-center text-sm text-zinc-400 sm:px-6 sm:py-16 sm:text-base">
        No published characters yet.{" "}
        <AddonDownloadButton variant="link">Download the addon</AddonDownloadButton>
        , play, then{" "}
        <Link href="/dashboard" className="font-medium text-amber-400 hover:text-amber-300">
          connect
        </Link>{" "}
        to sync progress.
      </div>
    );
  }

  const { overview } = stats;
  const total = overview.characters;

  return (
    <div className="space-y-6">
      <div className="grid gap-3 sm:grid-cols-2 lg:grid-cols-4">
        <KpiChip
          label="Characters"
          value={formatPoints(overview.characters)}
          hint={`${overview.alive} alive · ${overview.dead} fallen`}
          accent
        />
        <KpiChip
          label="Unlocks"
          value={formatPoints(overview.totalUnlocks)}
          hint={`${formatPoints(overview.catalogSize)} in the catalog`}
        />
        <KpiChip
          label="Avg points"
          value={formatDecimal(overview.avgPoints)}
          hint={`${formatPoints(overview.totalPoints)} total`}
          accent
        />
        <KpiChip
          label="Avg level"
          value={formatDecimal(overview.avgLevel)}
          hint={
            overview.maxLevel > 0
              ? `${overview.maxLevel} at 60`
              : "Nobody at 60 yet"
          }
        />
      </div>

      {overview.lastSyncedAt ? (
        <p className="text-xs text-zinc-500">
          Last published sync {formatRelativeTime(overview.lastSyncedAt)}
        </p>
      ) : null}

      <div className="grid gap-6 lg:grid-cols-2">
        <Panel
          title="Classes"
          subtitle="Share of published characters, with survival and average points"
        >
          <BarList>
            {stats.classes.map((row) => (
              <ClassRow key={row.class} row={row} total={total} />
            ))}
          </BarList>
        </Panel>

        <Panel
          title="Races"
          subtitle="Vanilla races, with Scourge counted as Undead"
        >
          <BarList>
            {stats.races.map((row) => (
              <RaceRow key={row.race} row={row} total={total} />
            ))}
          </BarList>
        </Panel>
      </div>

      <Panel title="Factions" subtitle="Derived from race — Alliance vs Horde">
        <div className="grid gap-3 sm:grid-cols-2">
          {stats.factions.map((row) => (
            <FactionCard key={row.faction} row={row} total={total} />
          ))}
        </div>
      </Panel>

      <div className="grid gap-6 lg:grid-cols-2">
        <Panel title="Levels" subtitle="Where the community sits on the climb to 60">
          <BarList>
            {stats.levels.map((row) => (
              <SimpleBar
                key={row.band}
                label={row.band}
                count={row.count}
                total={total}
                color="#f59e0b"
              />
            ))}
          </BarList>
        </Panel>

        <Panel title="Realms" subtitle="Published characters by home realm">
          {stats.realms.length === 0 ? (
            <p className="text-sm text-zinc-500">No realms yet.</p>
          ) : (
            <BarList>
              {stats.realms.map((row) => (
                <RealmRow key={row.realm} row={row} total={total} />
              ))}
            </BarList>
          )}
        </Panel>
      </div>

      <div className="grid gap-6 lg:grid-cols-2">
        <Panel
          title="Most common"
          subtitle="Achievements earned by the largest share of characters"
        >
          <AchievementList items={stats.commonest} empty="No unlocks recorded yet." />
        </Panel>
        <Panel
          title="Rarest earned"
          subtitle="Unlocked by at least one character, fewest first"
        >
          <AchievementList
            items={stats.rarest}
            empty="Nothing rare to show until the first uncommon unlock lands."
          />
        </Panel>
      </div>

      <Panel
        title="Still locked"
        subtitle={`${formatPoints(stats.neverEarned)} achievements nobody has published yet`}
      >
        {stats.neverEarnedExamples.length === 0 ? (
          <p className="text-sm text-zinc-500">The catalog has been fully earned. Impressive.</p>
        ) : (
          <AchievementList items={stats.neverEarnedExamples} empty="" />
        )}
      </Panel>

      <Panel
        title="Category coverage"
        subtitle="How much of each category anyone has earned, plus average unlocks per character"
      >
        <BarList>
          {stats.categories.map((row) => (
            <CategoryRow key={row.category} row={row} />
          ))}
        </BarList>
      </Panel>
    </div>
  );
}

function Panel({
  title,
  subtitle,
  children,
}: {
  title: string;
  subtitle?: string;
  children: ReactNode;
}) {
  return (
    <section className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-4 sm:p-5">
      <h2 className="font-[family-name:var(--font-display)] text-lg text-zinc-50 sm:text-xl">
        {title}
      </h2>
      {subtitle ? <p className="mt-1 text-sm text-zinc-500">{subtitle}</p> : null}
      <div className="mt-4">{children}</div>
    </section>
  );
}

function KpiChip({
  label,
  value,
  hint,
  accent,
}: {
  label: string;
  value: string;
  hint?: string;
  accent?: boolean;
}) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/50 px-4 py-3">
      <div className="text-[10px] uppercase tracking-wider text-zinc-500">{label}</div>
      <div
        className={cn(
          "mt-1 text-2xl font-semibold",
          accent ? "text-amber-400" : "text-zinc-100",
        )}
      >
        {value}
      </div>
      {hint ? <div className="mt-1 text-xs text-zinc-500">{hint}</div> : null}
    </div>
  );
}

function BarList({ children }: { children: ReactNode }) {
  return <ul className="space-y-3">{children}</ul>;
}

function ClassRow({ row, total }: { row: CommunityClassStat; total: number }) {
  const color = getClassColor(row.class);
  const survival =
    row.count === 0 ? null : `${Math.round((row.alive / row.count) * 100)}% alive`;

  return (
    <li>
      <BarHeader
        label={getClassLabel(row.class)}
        labelColor={color}
        count={row.count}
        total={total}
      />
      <Meter value={share(row.count, total)} color={color} />
      <p className="mt-1 text-[11px] text-zinc-500">
        {survival ? `${survival} · ` : "No characters yet · "}
        avg {formatDecimal(row.avgPoints)} pts · L{formatDecimal(row.avgLevel)}
      </p>
    </li>
  );
}

function RaceRow({ row, total }: { row: CommunityRaceStat; total: number }) {
  const color = getFactionColor(row.faction);
  return (
    <li>
      <BarHeader label={getRaceLabel(row.race)} count={row.count} total={total} />
      <Meter value={share(row.count, total)} color={color} />
      <p className="mt-1 text-[11px] text-zinc-500">
        {row.faction}
        {row.count > 0 ? ` · avg ${formatDecimal(row.avgPoints)} pts` : ""}
      </p>
    </li>
  );
}

function RealmRow({ row, total }: { row: CommunityRealmStat; total: number }) {
  return (
    <li>
      <BarHeader label={row.realm} count={row.count} total={total} />
      <Meter value={share(row.count, total)} color="#f59e0b" />
      <p className="mt-1 text-[11px] text-zinc-500">
        avg {formatDecimal(row.avgPoints)} pts
      </p>
    </li>
  );
}

function SimpleBar({
  label,
  count,
  total,
  color,
}: {
  label: string;
  count: number;
  total: number;
  color: string;
}) {
  return (
    <li>
      <BarHeader label={label} count={count} total={total} />
      <Meter value={share(count, total)} color={color} />
    </li>
  );
}

function CategoryRow({ row }: { row: CommunityCategoryStat }) {
  return (
    <li>
      <div className="flex items-baseline justify-between gap-3 text-sm">
        <span className="font-medium text-zinc-200">{row.category}</span>
        <span className="shrink-0 tabular-nums text-zinc-400">
          {row.earnedByAnyone}/{row.catalog}{" "}
          <span className="text-zinc-500">({formatPercent(row.earnedPercent)})</span>
        </span>
      </div>
      <Meter value={Number(row.earnedPercent) || 0} color="#f59e0b" />
      <p className="mt-1 text-[11px] text-zinc-500">
        {formatDecimal(row.avgUnlocksPerCharacter)} unlocks / character
      </p>
    </li>
  );
}

function FactionCard({ row, total }: { row: CommunityFactionStat; total: number }) {
  const color = getFactionColor(row.faction);
  const pct = share(row.count, total);
  const survival =
    row.count === 0 ? "—" : `${Math.round((row.alive / row.count) * 100)}% alive`;

  return (
    <div
      className="rounded-lg border border-zinc-800 bg-zinc-950/70 p-4"
      style={{ boxShadow: `inset 3px 0 0 ${color}` }}
    >
      <p className="text-xs uppercase tracking-wider text-zinc-500">{row.faction}</p>
      <p className="mt-1 text-3xl font-semibold" style={{ color }}>
        {formatPercent(pct)}
      </p>
      <p className="mt-1 text-sm text-zinc-400">
        {row.count} character{row.count === 1 ? "" : "s"} · {survival}
      </p>
      <Meter value={pct} color={color} className="mt-3" />
      {row.count > 0 ? (
        <p className="mt-2 text-[11px] text-zinc-500">
          avg {formatDecimal(row.avgPoints)} pts · {row.dead} fallen
        </p>
      ) : (
        <p className="mt-2 text-[11px] text-zinc-500">Nobody published yet</p>
      )}
    </div>
  );
}

function AchievementList({
  items,
  empty,
}: {
  items: CommunityAchievementStat[];
  empty: string;
}) {
  if (items.length === 0) {
    return empty ? <p className="text-sm text-zinc-500">{empty}</p> : null;
  }

  return (
    <ul className="divide-y divide-zinc-800/80 overflow-hidden rounded-lg border border-zinc-800/80">
      {items.map((item) => (
        <li
          key={item.id}
          className="flex items-start justify-between gap-3 px-3 py-2.5"
        >
          <div className="min-w-0">
            <p className="truncate font-medium text-zinc-100">{item.name}</p>
            <p className="mt-0.5 text-[11px] uppercase tracking-wider text-zinc-500">
              {item.category}
            </p>
          </div>
          <div className="shrink-0 text-right">
            <p className="text-sm font-semibold text-amber-400">
              {formatPercent(item.percent)}
            </p>
            <p className="text-[11px] text-zinc-500">
              {item.unlocks} · {formatPoints(item.points)} pts
            </p>
          </div>
        </li>
      ))}
    </ul>
  );
}

function BarHeader({
  label,
  labelColor,
  count,
  total,
}: {
  label: string;
  labelColor?: string;
  count: number;
  total: number;
}) {
  return (
    <div className="flex items-baseline justify-between gap-3 text-sm">
      <span className="font-medium text-zinc-200" style={labelColor ? { color: labelColor } : undefined}>
        {label}
      </span>
      <span className="shrink-0 tabular-nums text-zinc-400">
        {count}{" "}
        <span className="text-zinc-500">({formatPercent(share(count, total))})</span>
      </span>
    </div>
  );
}

function Meter({
  value,
  color,
  className,
}: {
  value: number;
  color: string;
  className?: string;
}) {
  const width = Math.max(0, Math.min(100, value));
  return (
    <div className={cn("mt-1.5 h-2 overflow-hidden rounded-full bg-zinc-950", className)}>
      <div
        className="h-full rounded-full transition-all duration-500"
        style={{ width: `${width}%`, backgroundColor: color }}
      />
    </div>
  );
}

function share(count: number, total: number) {
  if (total <= 0) return 0;
  return Math.round((count / total) * 1000) / 10;
}

function formatDecimal(value: number) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "0";
  return n.toLocaleString("en-US", { maximumFractionDigits: 1 });
}

function formatPercent(value: number) {
  const n = Number(value);
  if (!Number.isFinite(n)) return "0%";
  return `${n.toLocaleString("en-US", { maximumFractionDigits: 1 })}%`;
}
