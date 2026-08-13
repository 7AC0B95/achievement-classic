import Link from "next/link";
import { AddonDownloadButton } from "@/components/addon-download-button";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import type { CharacterRow } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

interface LeaderboardTableProps {
  rows: CharacterRow[];
}

export function LeaderboardTable({ rows }: LeaderboardTableProps) {
  if (!rows.length) {
    return (
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/40 px-4 py-12 text-center text-sm text-zinc-400 sm:px-6 sm:py-16 sm:text-base">
        No characters match these filters yet.{" "}
        <AddonDownloadButton variant="link">Download the addon</AddonDownloadButton>
        , play, then{" "}
        <Link href="/dashboard" className="font-medium text-amber-400 hover:text-amber-300">
          connect
        </Link>{" "}
        to sync progress.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/50 shadow-[0_0_0_1px_rgba(245,158,11,0.04)]">
      <ul className="divide-y divide-zinc-800/80 md:hidden">
        {rows.map((row, index) => (
          <LeaderboardCard key={row.id} row={row} rank={index + 1} />
        ))}
      </ul>
      <div className="hidden overflow-x-auto md:block">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-800 bg-zinc-950/80 text-xs uppercase tracking-wider text-zinc-500">
            <tr>
              <th className="px-4 py-3 font-medium">Rank</th>
              <th className="px-4 py-3 font-medium">Character</th>
              <th className="px-4 py-3 font-medium">Class</th>
              <th className="px-4 py-3 font-medium">Realm</th>
              <th className="px-4 py-3 font-medium">Level</th>
              <th className="px-4 py-3 font-medium">Status</th>
              <th className="px-4 py-3 font-medium text-right">Achievements</th>
              <th className="px-4 py-3 font-medium text-right">Points</th>
            </tr>
          </thead>
          <tbody>
            {rows.map((row, index) => {
              const color = getClassColor(row.class);
              return (
                <tr
                  key={row.id}
                  className="border-b border-zinc-800/80 transition hover:bg-zinc-800/40"
                >
                  <td className="px-4 py-3">
                    <RankBadge rank={index + 1} />
                  </td>
                  <td className="px-4 py-3">
                    <Link
                      href={`/characters/${row.id}`}
                      className="font-semibold underline-offset-2 hover:underline"
                      style={{ color }}
                    >
                      {row.name}
                    </Link>
                  </td>
                  <td className="px-4 py-3">
                    <span
                      className="rounded-md border px-2 py-0.5 text-xs"
                      style={{
                        color,
                        borderColor: `${color}55`,
                        backgroundColor: `${color}14`,
                      }}
                    >
                      {getClassLabel(row.class)}
                    </span>
                  </td>
                  <td className="px-4 py-3 text-zinc-400">{row.realm}</td>
                  <td className="px-4 py-3 text-zinc-300">{row.level}</td>
                  <td className="px-4 py-3">
                    <StatusBadge status={row.status} />
                  </td>
                  <td className="px-4 py-3 text-right text-zinc-300">
                    {row.achievement_count}
                  </td>
                  <td className="px-4 py-3 text-right font-semibold text-amber-400">
                    {formatPoints(row.total_points)}
                  </td>
                </tr>
              );
            })}
          </tbody>
        </table>
      </div>
    </div>
  );
}

function LeaderboardCard({ row, rank }: { row: CharacterRow; rank: number }) {
  const color = getClassColor(row.class);

  return (
    <li>
      <Link
        href={`/characters/${row.id}`}
        className="flex items-start gap-3 px-3 py-3 transition hover:bg-zinc-800/40"
      >
        <RankBadge rank={rank} />
        <div className="min-w-0 flex-1">
          <p className="truncate font-semibold" style={{ color }}>
            {row.name}
          </p>
          <p className="mt-0.5 text-xs leading-relaxed text-zinc-400">
            {getClassLabel(row.class)} · {row.realm} · L{row.level}
          </p>
          <div className="mt-1.5 flex flex-wrap items-center gap-2">
            <StatusBadge status={row.status} />
            <span className="text-xs text-zinc-500">
              {row.achievement_count} achievements
            </span>
          </div>
        </div>
        <div className="shrink-0 text-right">
          <div className="text-sm font-semibold text-amber-400">
            {formatPoints(row.total_points)}
          </div>
          <div className="text-[10px] uppercase tracking-wider text-zinc-600">
            pts
          </div>
        </div>
      </Link>
    </li>
  );
}

function RankBadge({ rank }: { rank: number }) {
  return (
    <span
      className={cn(
        "inline-flex h-7 w-7 shrink-0 items-center justify-center rounded-md text-xs font-bold",
        rank === 1 && "bg-amber-500/20 text-amber-300",
        rank === 2 && "bg-zinc-300/10 text-zinc-200",
        rank === 3 && "bg-orange-700/20 text-orange-300",
        rank > 3 && "text-zinc-500",
      )}
    >
      {rank}
    </span>
  );
}

function StatusBadge({ status }: { status: CharacterRow["status"] }) {
  return (
    <span
      className={cn(
        "rounded-md px-2 py-0.5 text-xs font-medium",
        status === "Alive"
          ? "bg-emerald-500/15 text-emerald-300"
          : "bg-rose-500/15 text-rose-300",
      )}
    >
      {status}
    </span>
  );
}
