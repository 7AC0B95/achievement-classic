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
      <div className="rounded-xl border border-zinc-800 bg-zinc-900/40 px-6 py-16 text-center text-zinc-400">
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
      <div className="overflow-x-auto">
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
                    <span
                      className={cn(
                        "inline-flex h-7 w-7 items-center justify-center rounded-md text-xs font-bold",
                        index === 0 && "bg-amber-500/20 text-amber-300",
                        index === 1 && "bg-zinc-300/10 text-zinc-200",
                        index === 2 && "bg-orange-700/20 text-orange-300",
                        index > 2 && "text-zinc-500",
                      )}
                    >
                      {index + 1}
                    </span>
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
                    <span
                      className={cn(
                        "rounded-md px-2 py-0.5 text-xs font-medium",
                        row.status === "Alive"
                          ? "bg-emerald-500/15 text-emerald-300"
                          : "bg-rose-500/15 text-rose-300",
                      )}
                    >
                      {row.status}
                    </span>
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
