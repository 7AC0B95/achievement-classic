import { Suspense } from "react";
import { LeaderboardLoader } from "@/components/leaderboard-loader";
import {
  LeaderboardFiltersSkeleton,
  LeaderboardTableSkeleton,
} from "@/components/loading-ui";
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

      <Suspense
        fallback={
          <div className="space-y-4">
            <LeaderboardFiltersSkeleton />
            <LeaderboardTableSkeleton rows={8} />
          </div>
        }
      >
        <LeaderboardLoader
          key={`${params.realm ?? ""}-${params.class ?? ""}-${params.status ?? ""}-${sort}`}
          realm={params.realm}
          classToken={params.class}
          status={params.status}
          sort={sort}
          showFilters
        />
      </Suspense>
    </div>
  );
}
