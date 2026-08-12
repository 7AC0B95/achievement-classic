import type { CharacterAchievementRow } from "@/lib/types";
import { formatPoints } from "@/lib/utils";

interface CharacterAchievementsTableProps {
  items: CharacterAchievementRow[];
}

export function CharacterAchievementsTable({
  items,
}: CharacterAchievementsTableProps) {
  if (!items.length) {
    return (
      <div className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-12 text-center text-sm text-zinc-500">
        No achievements unlocked yet.
      </div>
    );
  }

  return (
    <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/50">
      <div className="overflow-x-auto">
        <table className="min-w-full text-left text-sm">
          <thead className="border-b border-zinc-800 bg-zinc-950/80 text-xs uppercase tracking-wider text-zinc-500">
            <tr>
              <th className="px-4 py-3 font-medium">Achievement</th>
              <th className="px-4 py-3 font-medium">Category</th>
              <th className="px-4 py-3 font-medium text-right">Points</th>
              <th className="px-4 py-3 font-medium text-right">Unlocked</th>
            </tr>
          </thead>
          <tbody>
            {items.map((item) => (
              <tr
                key={item.id}
                className="border-b border-zinc-800/80 transition hover:bg-zinc-800/40"
              >
                <td className="px-4 py-3">
                  <div className="font-medium text-zinc-100">
                    {item.achievements?.name ?? item.achievement_id}
                  </div>
                  <div className="mt-0.5 max-w-md text-xs text-zinc-500">
                    {item.achievements?.description}
                  </div>
                </td>
                <td className="px-4 py-3">
                  <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2 py-0.5 text-xs text-zinc-300">
                    {item.achievements?.category ?? "—"}
                  </span>
                </td>
                <td className="px-4 py-3 text-right font-semibold text-amber-400">
                  {formatPoints(item.achievements?.points ?? 0)}
                </td>
                <td className="px-4 py-3 text-right text-zinc-400">
                  <div>{new Date(item.unlocked_at).toLocaleDateString()}</div>
                  <div className="text-[11px] text-zinc-600">
                    {new Date(item.unlocked_at).toLocaleTimeString()}
                  </div>
                </td>
              </tr>
            ))}
          </tbody>
        </table>
      </div>
    </div>
  );
}
