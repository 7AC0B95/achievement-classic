"use client";

import { cn } from "@/lib/utils";

export function SkeletonLine({ className }: { className?: string }) {
  return <div className={cn("skeleton-line rounded-md", className)} />;
}

export function ActivityFeedSkeleton({ rows = 5 }: { rows?: number }) {
  return (
    <section
      className="rounded-xl border border-zinc-800 bg-zinc-900/50 p-4 sm:p-5"
      aria-busy="true"
      aria-live="polite"
    >
      <div className="mb-4 flex items-center justify-between gap-3">
        <h2 className="font-[family-name:var(--font-display)] text-lg text-zinc-50 sm:text-xl">
          Live activity
        </h2>
        <span className="inline-flex items-center gap-2 text-xs uppercase tracking-wider text-amber-400/90">
          <span className="relative flex h-2 w-2">
            <span className="absolute inline-flex h-full w-full animate-ping rounded-full bg-amber-400 opacity-60" />
            <span className="relative inline-flex h-2 w-2 rounded-full bg-amber-400" />
          </span>
          Loading
        </span>
      </div>
      <p className="sr-only">Loading live activity</p>
      <ul className="space-y-3">
        {Array.from({ length: rows }, (_, index) => (
          <li
            key={index}
            className="flex items-start justify-between gap-3 rounded-lg border border-zinc-800/80 bg-zinc-950/50 px-3 py-3"
          >
            <div className="min-w-0 flex-1 space-y-2">
              <SkeletonLine className="h-4 w-2/3" />
              <SkeletonLine className="h-3 w-1/2" />
            </div>
            <div className="space-y-2">
              <SkeletonLine className="ml-auto h-4 w-10" />
              <SkeletonLine className="ml-auto h-3 w-14" />
            </div>
          </li>
        ))}
      </ul>
    </section>
  );
}

export function LeaderboardTableSkeleton({ rows = 8 }: { rows?: number }) {
  return (
    <div
      className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/50"
      aria-busy="true"
      aria-live="polite"
    >
      <p className="sr-only">Loading leaderboard</p>
      <ul className="divide-y divide-zinc-800/80 md:hidden">
        {Array.from({ length: rows }, (_, index) => (
          <li key={index} className="flex items-start gap-3 px-3 py-3">
            <SkeletonLine className="h-7 w-7 shrink-0 rounded-md" />
            <div className="min-w-0 flex-1 space-y-2">
              <SkeletonLine className="h-4 w-32" />
              <SkeletonLine className="h-3 w-48" />
            </div>
            <SkeletonLine className="h-4 w-10" />
          </li>
        ))}
      </ul>
      <div className="hidden md:block">
        <div className="border-b border-zinc-800 bg-zinc-950/80 px-4 py-3">
          <SkeletonLine className="h-3 w-40" />
        </div>
        <ul className="divide-y divide-zinc-800/80">
          {Array.from({ length: rows }, (_, index) => (
            <li key={index} className="grid grid-cols-8 items-center gap-3 px-4 py-3">
              <SkeletonLine className="h-4 w-6" />
              <SkeletonLine className="col-span-2 h-4 w-28" />
              <SkeletonLine className="h-4 w-16" />
              <SkeletonLine className="h-4 w-20" />
              <SkeletonLine className="h-4 w-8" />
              <SkeletonLine className="h-4 w-12" />
              <SkeletonLine className="ml-auto h-4 w-10" />
            </li>
          ))}
        </ul>
      </div>
    </div>
  );
}

export function LeaderboardFiltersSkeleton() {
  return (
    <div className="grid gap-3 rounded-xl border border-zinc-800 bg-zinc-900/50 p-4 sm:grid-cols-2 lg:grid-cols-4">
      {Array.from({ length: 4 }, (_, index) => (
        <div key={index} className="space-y-2">
          <SkeletonLine className="h-3 w-14" />
          <SkeletonLine className="h-10 w-full" />
        </div>
      ))}
    </div>
  );
}

export function LoadError({
  message,
  onRetry,
}: {
  message?: string;
  onRetry: () => void;
}) {
  return (
    <div className="rounded-xl border border-dashed border-zinc-800 bg-zinc-950/40 px-4 py-10 text-center text-sm text-zinc-400">
      <p>{message ?? "Could not load this data yet."}</p>
      <button
        type="button"
        onClick={onRetry}
        className="mt-3 rounded-md border border-amber-500/40 bg-amber-500/10 px-3 py-1.5 text-sm font-medium text-amber-300 transition hover:bg-amber-500/20"
      >
        Try again
      </button>
    </div>
  );
}
