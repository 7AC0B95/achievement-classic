import Link from "next/link";
import { ArrowRight } from "lucide-react";
import { ActivityFeed } from "@/components/activity-feed";
import { AddonDownloadButton } from "@/components/addon-download-button";
import { LeaderboardTable } from "@/components/leaderboard-table";
import { fetchLeaderboard, fetchRecentActivity } from "@/lib/data";

export default async function HomePage() {
  const [leaders, activity] = await Promise.all([
    fetchLeaderboard({ sort: "total_points" }),
    fetchRecentActivity(5),
  ]);

  return (
    <div>
      <section className="relative overflow-hidden border-b border-zinc-800/80">
        <div
          className="pointer-events-none absolute inset-0 opacity-40"
          style={{
            backgroundImage:
              "radial-gradient(circle at 20% 20%, rgba(245,158,11,0.15), transparent 35%), radial-gradient(circle at 80% 30%, rgba(113,113,122,0.2), transparent 40%), linear-gradient(to bottom, transparent, #09090b)",
          }}
        />
        <div className="relative mx-auto grid max-w-6xl gap-10 px-4 py-10 sm:px-6 sm:py-16 lg:grid-cols-[1.2fr_0.8fr] lg:py-20">
          <div className="animate-rise">
            <p className="mb-4 text-xs uppercase tracking-[0.18em] text-amber-500/90 sm:text-sm sm:tracking-[0.25em]">
              Classic Era / Hardcore · Addon + website
            </p>
            <h1 className="font-[family-name:var(--font-display)] text-4xl leading-tight text-zinc-50 sm:text-5xl lg:text-6xl">
              <span className="gold-shimmer">Classic Glory</span>
            </h1>
            <p className="mt-5 max-w-xl text-base leading-relaxed text-zinc-400 sm:text-lg">
              The in-game addon tracks 190+ custom achievements. This website
              publishes them — upload your progress and climb the global
              leaderboards.
            </p>
            <div className="mt-8 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
              <AddonDownloadButton className="w-full justify-center sm:w-auto">Download the addon</AddonDownloadButton>
              <Link
                href="/dashboard"
                className="inline-flex w-full items-center justify-center gap-2 rounded-md border border-zinc-700 bg-zinc-950/60 px-5 py-3 text-sm font-medium text-zinc-200 transition hover:border-amber-500/40 sm:w-auto"
              >
                Connect character
                <ArrowRight className="h-4 w-4" />
              </Link>
              <Link
                href="/leaderboard"
                className="inline-flex w-full items-center justify-center gap-2 rounded-md border border-zinc-700 bg-zinc-950/60 px-5 py-3 text-sm font-medium text-zinc-200 transition hover:border-amber-500/40 sm:w-auto"
              >
                View leaderboards
              </Link>
            </div>
          </div>

          <div className="animate-rise-delay-1 grid gap-3 self-end">
            <HowStep
              n="1"
              title="Install the addon"
              body="Download ClassicGlory, drop it into Interface\AddOns, then /reload."
            />
            <HowStep
              n="2"
              title="Play and unlock"
              body="Open /cg in-game. Achievements track as you quest, explore, and fight — 190+ feats across leveling, dungeons, PvP, and Hardcore."
            />
            <HowStep
              n="3"
              title="Publish on the web"
              body="Log out, then Connect and upload ClassicGlory.lua once to sync every character to the leaderboard."
            />
          </div>
        </div>
      </section>

      <section className="mx-auto grid max-w-6xl gap-8 px-4 py-14 sm:px-6 lg:grid-cols-[0.9fr_1.1fr]">
        <div className="animate-rise-delay-1">
          <ActivityFeed items={activity} />
        </div>
        <div className="animate-rise-delay-2">
          <div className="mb-4 flex items-end justify-between gap-3">
            <div className="min-w-0">
              <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50 sm:text-2xl">
                Overall leaderboard
              </h2>
              <p className="mt-1 text-sm text-zinc-500">Sorted by total achievement points</p>
            </div>
            <div className="flex shrink-0 flex-col items-end gap-1 sm:flex-row sm:items-center sm:gap-3">
              <Link
                href="/stats"
                className="text-sm text-amber-400 hover:text-amber-300"
              >
                Community stats →
              </Link>
              <Link
                href="/leaderboard"
                className="text-sm text-amber-400 hover:text-amber-300"
              >
                Full table →
              </Link>
            </div>
          </div>
          <LeaderboardTable rows={leaders.slice(0, 8)} />
        </div>
      </section>
    </div>
  );
}

function HowStep({
  n,
  title,
  body,
}: {
  n: string;
  title: string;
  body: string;
}) {
  return (
    <div className="rounded-xl border border-zinc-800 bg-zinc-900/40 px-4 py-4">
      <p className="text-xs font-semibold uppercase tracking-[0.18em] text-amber-400/90">
        {n}
      </p>
      <h3 className="mt-1 font-[family-name:var(--font-display)] text-lg text-zinc-100">
        {title}
      </h3>
      <p className="mt-1 text-sm leading-relaxed text-zinc-400">{body}</p>
    </div>
  );
}
