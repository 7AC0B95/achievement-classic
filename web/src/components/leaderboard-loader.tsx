"use client";

import { Suspense } from "react";
import { LeaderboardFilters } from "@/components/leaderboard-filters";
import { LeaderboardTable } from "@/components/leaderboard-table";
import {
  LeaderboardFiltersSkeleton,
  LeaderboardTableSkeleton,
  LoadError,
} from "@/components/loading-ui";
import { useRetryingQuery } from "@/hooks/use-retrying-query";
import { queryLeaderboard, queryRealms } from "@/lib/public-queries";
import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import type { CharacterRow, LeaderboardSort } from "@/lib/types";

interface LeaderboardState {
  rows: CharacterRow[];
  realms: string[];
}

function hasRows(state: LeaderboardState | undefined) {
  return (state?.rows.length ?? 0) > 0;
}

export function LeaderboardLoader({
  initialRows,
  initialRealms,
  realm,
  classToken,
  status,
  sort = "total_points",
  limit = 100,
  showFilters = false,
}: {
  initialRows?: CharacterRow[];
  initialRealms?: string[];
  realm?: string;
  classToken?: string;
  status?: string;
  sort?: LeaderboardSort;
  limit?: number;
  showFilters?: boolean;
}) {
  const { data, error, retry, showPlaceholder } = useRetryingQuery({
    query: async (): Promise<LeaderboardState> => {
      if (!isSupabaseConfigured()) {
        return {
          rows: initialRows ?? [],
          realms: initialRealms ?? [],
        };
      }
      const supabase = createClient();
      const [rows, realms] = await Promise.all([
        queryLeaderboard(supabase, {
          realm,
          classToken,
          status,
          sort,
          limit,
        }),
        showFilters ? queryRealms(supabase) : Promise.resolve(initialRealms ?? []),
      ]);
      return { rows, realms };
    },
    queryKey: `leaderboard:${realm ?? ""}:${classToken ?? ""}:${status ?? ""}:${sort}:${limit}:${showFilters}`,
    initialData:
      initialRows || initialRealms
        ? { rows: initialRows ?? [], realms: initialRealms ?? [] }
        : undefined,
    isFilled: hasRows,
  });

  if (showPlaceholder) {
    return (
      <div className="space-y-4">
        {showFilters ? <LeaderboardFiltersSkeleton /> : null}
        <LeaderboardTableSkeleton rows={Math.min(limit, 8)} />
      </div>
    );
  }

  if (error && !hasRows(data)) {
    return (
      <LoadError
        message="The leaderboard is still catching up."
        onRetry={retry}
      />
    );
  }

  return (
    <div className="space-y-4">
      {showFilters ? (
        <Suspense fallback={<LeaderboardFiltersSkeleton />}>
          <LeaderboardFilters realms={data?.realms ?? initialRealms ?? []} />
        </Suspense>
      ) : null}
      <LeaderboardTable rows={data?.rows ?? []} />
    </div>
  );
}
