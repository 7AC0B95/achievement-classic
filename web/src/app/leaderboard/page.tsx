import { Suspense } from "react";
import { LeaderboardFilters } from "@/components/leaderboard-filters";
import { LeaderboardTable } from "@/components/leaderboard-table";
import { fetchLeaderboard, fetchRealms } from "@/lib/data";
import type { LeaderboardSort } from "@/lib/types";

interface LeaderboardPageProps {
  searchParams: Promise<{
    realm?: string;
    class?: string;
    status?: string;
    sort?: string;
  }>;
}

export default async function LeaderboardPage({ searchParams }: LeaderboardPageProps) {
  const params = await searchParams;
  const sort = (params.sort as LeaderboardSort) || "total_points";
  const [rows, realms] = await Promise.all([
    fetchLeaderboard({
      realm: params.realm,
      classToken: params.class,
      status: params.status,
      sort,
    }),
    fetchRealms(),
  ]);

  return (
    <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6 sm:py-10">
      <div>
        <h1 className="font-[family-name:var(--font-display)] text-2xl text-zinc-50 sm:text-3xl">
          Leaderboard
        </h1>
        <p className="mt-2 text-zinc-400">
          Characters published from the in-game addon. Filter by realm, class,
          and Alive/Dead status, and sort by points or achievement count.
        </p>
      </div>

      <Suspense fallback={<div className="h-24 rounded-xl border border-zinc-800 bg-zinc-900/40" />}>
        <LeaderboardFilters realms={realms} />
      </Suspense>

      <LeaderboardTable rows={rows} />
    </div>
  );
}
