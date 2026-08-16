"use client";

import { ActivityFeed } from "@/components/activity-feed";
import { ActivityFeedSkeleton, LoadError } from "@/components/loading-ui";
import { useRetryingQuery } from "@/hooks/use-retrying-query";
import { queryRecentActivity } from "@/lib/public-queries";
import { createClient, isSupabaseConfigured } from "@/lib/supabase/client";
import type { CharacterAchievementRow } from "@/lib/types";

function hasItems(items: CharacterAchievementRow[] | undefined) {
  return (items?.length ?? 0) > 0;
}

export function ActivityFeedLoader({
  initialItems,
  limit = 5,
}: {
  initialItems?: CharacterAchievementRow[];
  limit?: number;
}) {
  const { data, error, retry, showPlaceholder } = useRetryingQuery({
    query: async () => {
      if (!isSupabaseConfigured()) return initialItems ?? [];
      return queryRecentActivity(createClient(), limit);
    },
    queryKey: `activity:${limit}`,
    initialData: initialItems,
    isFilled: hasItems,
  });

  if (showPlaceholder) return <ActivityFeedSkeleton rows={limit} />;
  if (error && !hasItems(data)) {
    return <LoadError message="Live activity is still catching up." onRetry={retry} />;
  }

  return <ActivityFeed items={data ?? []} />;
}
