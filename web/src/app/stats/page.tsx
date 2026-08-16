import type { Metadata } from "next";
import { CommunityStatsView } from "@/components/community-stats";
import { fetchCommunityStats } from "@/lib/data";

export const metadata: Metadata = {
  title: "Community stats | Classic Glory",
  description:
    "Class, race, faction, and achievement statistics from characters published to Classic Glory.",
};

export default async function StatsPage() {
  const stats = await fetchCommunityStats();

  return (
    <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6 sm:py-10">
      <div>
        <h1 className="font-[family-name:var(--font-display)] text-2xl text-zinc-50 sm:text-3xl">
          Community stats
        </h1>
        <p className="mt-2 max-w-2xl text-zinc-400">
          How published Classic Glory characters break down by class, race,
          faction, and what they have actually unlocked. Figures update as
          players sync from the addon.
        </p>
      </div>

      <CommunityStatsView stats={stats} />
    </div>
  );
}
