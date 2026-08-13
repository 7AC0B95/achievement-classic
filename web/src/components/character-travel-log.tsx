import {
  getVisitedInstances,
  titleCaseZone,
} from "@/lib/character-profile";
import type { CharacterStatsRow } from "@/lib/types";

interface CharacterTravelLogProps {
  stats: CharacterStatsRow | null;
}

export function CharacterTravelLog({ stats }: CharacterTravelLogProps) {
  const zones = (stats?.zones_visited ?? []).map(titleCaseZone);
  const instances = getVisitedInstances(stats?.raw).map(titleCaseZone);
  const empty = zones.length === 0 && instances.length === 0;

  return (
    <section className="space-y-3">
      <div>
        <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50 sm:text-2xl">
          Travel log
        </h2>
        <p className="mt-1 text-sm text-zinc-500">
          Zones and instances recorded in the last sync.
        </p>
      </div>

      {empty ? (
        <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-10 text-center text-sm text-zinc-500">
          No zones visited yet.
        </div>
      ) : (
        <div className="space-y-4 rounded-xl border border-zinc-800 bg-zinc-900/50 p-4 sm:p-5">
          {zones.length > 0 ? (
            <ChipGroup label="Zones" items={zones} />
          ) : null}
          {instances.length > 0 ? (
            <ChipGroup label="Instances" items={instances} />
          ) : null}
        </div>
      )}
    </section>
  );
}

function ChipGroup({ label, items }: { label: string; items: string[] }) {
  return (
    <div>
      <p className="text-[11px] uppercase tracking-wider text-zinc-500">
        {label} · {items.length}
      </p>
      <ul className="mt-2 flex flex-wrap gap-1.5">
        {items.map((item) => (
          <li
            key={item}
            className="rounded-md border border-zinc-700 bg-zinc-950 px-2.5 py-1 text-xs text-zinc-300"
          >
            {item}
          </li>
        ))}
      </ul>
    </div>
  );
}
