import { getClassColor, getClassLabel } from "@/lib/class-colors";
import type { CharacterRow, CharacterStatsRow } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

interface CharacterProfileHeaderProps {
  character: CharacterRow;
  stats: CharacterStatsRow | null;
}

export function CharacterProfileHeader({
  character,
  stats,
}: CharacterProfileHeaderProps) {
  const color = getClassColor(character.class);

  return (
    <header
      className="relative overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/60 p-6 sm:p-8"
      style={{ boxShadow: `inset 4px 0 0 ${color}` }}
    >
      <div
        className="pointer-events-none absolute inset-0 opacity-40"
        style={{
          background: `radial-gradient(ellipse 60% 80% at 100% 0%, ${color}22, transparent 55%)`,
        }}
      />

      <div className="relative flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-[0.2em] text-zinc-500">
            Character profile
          </p>
          <h1
            className="mt-2 font-[family-name:var(--font-display)] text-4xl sm:text-5xl"
            style={{ color }}
          >
            {character.name}
          </h1>
          <p className="mt-2 text-zinc-400">
            {character.realm} · {getClassLabel(character.class)}
            {character.race ? ` · ${character.race}` : ""}
          </p>

          <div className="mt-4 flex flex-wrap gap-2 text-xs">
            <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2.5 py-1 text-zinc-300">
              Level {character.level}
            </span>
            <span
              className={cn(
                "rounded-md px-2.5 py-1 font-medium",
                character.status === "Alive"
                  ? "bg-emerald-500/15 text-emerald-300"
                  : "bg-rose-500/15 text-rose-300",
              )}
            >
              {character.status}
            </span>
            <span
              className="rounded-md border px-2.5 py-1"
              style={{
                color,
                borderColor: `${color}55`,
                backgroundColor: `${color}14`,
              }}
            >
              {getClassLabel(character.class)}
            </span>
          </div>
        </div>

        <div className="grid grid-cols-2 gap-3 sm:min-w-[220px]">
          <StatChip label="Points" value={formatPoints(character.total_points)} accent />
          <StatChip label="Unlocks" value={String(character.achievement_count)} />
          {stats ? (
            <>
              <StatChip label="Zones" value={String(stats.zones_visited.length)} />
              <StatChip label="Deaths" value={String(stats.deaths)} />
            </>
          ) : null}
        </div>
      </div>

      {character.last_synced_at ? (
        <p className="relative mt-5 text-xs text-zinc-500">
          Last synced {new Date(character.last_synced_at).toLocaleString()}
        </p>
      ) : null}
    </header>
  );
}

function StatChip({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: boolean;
}) {
  return (
    <div className="rounded-lg border border-zinc-800 bg-zinc-950/70 px-3 py-2.5">
      <div className="text-[10px] uppercase tracking-wider text-zinc-500">{label}</div>
      <div
        className={cn(
          "mt-0.5 text-sm font-semibold",
          accent ? "text-amber-400" : "text-zinc-100",
        )}
      >
        {value}
      </div>
    </div>
  );
}
