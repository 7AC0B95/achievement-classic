"use client";

import { useRouter, useSearchParams } from "next/navigation";
import { WOW_CLASSES, getClassLabel } from "@/lib/class-colors";
import type { LeaderboardSort } from "@/lib/types";

interface LeaderboardFiltersProps {
  realms: string[];
}

export function LeaderboardFilters({ realms }: LeaderboardFiltersProps) {
  const router = useRouter();
  const params = useSearchParams();

  const update = (key: string, value: string) => {
    const next = new URLSearchParams(params.toString());
    if (!value) next.delete(key);
    else next.set(key, value);
    router.push(`/leaderboard?${next.toString()}`);
  };

  return (
    <div className="grid gap-3 rounded-xl border border-zinc-800 bg-zinc-900/50 p-4 sm:grid-cols-2 lg:grid-cols-4">
      <FilterSelect
        label="Realm"
        value={params.get("realm") ?? ""}
        onChange={(v) => update("realm", v)}
        options={[
          { value: "", label: "All realms" },
          ...realms.map((r) => ({ value: r, label: r })),
        ]}
      />
      <FilterSelect
        label="Class"
        value={params.get("class") ?? ""}
        onChange={(v) => update("class", v)}
        options={[
          { value: "", label: "All classes" },
          ...WOW_CLASSES.map((c) => ({ value: c, label: getClassLabel(c) })),
        ]}
      />
      <FilterSelect
        label="Status"
        value={params.get("status") ?? ""}
        onChange={(v) => update("status", v)}
        options={[
          { value: "", label: "Alive & Dead" },
          { value: "Alive", label: "Alive" },
          { value: "Dead", label: "Dead" },
        ]}
      />
      <FilterSelect
        label="Sort"
        value={(params.get("sort") as LeaderboardSort) ?? "total_points"}
        onChange={(v) => update("sort", v)}
        options={[
          { value: "total_points", label: "Total points" },
          { value: "achievement_count", label: "Achievements" },
        ]}
      />
    </div>
  );
}

function FilterSelect({
  label,
  value,
  onChange,
  options,
}: {
  label: string;
  value: string;
  onChange: (value: string) => void;
  options: Array<{ value: string; label: string }>;
}) {
  return (
    <label className="block text-xs uppercase tracking-wider text-zinc-500">
      {label}
      <select
        value={value}
        onChange={(e) => onChange(e.target.value)}
        className="mt-1.5 w-full max-w-full rounded-md border border-zinc-700 bg-zinc-950 px-3 py-2.5 text-base normal-case tracking-normal text-zinc-100 outline-none focus:border-amber-500/50 md:text-sm"
      >
        {options.map((opt) => (
          <option key={opt.value || "all"} value={opt.value}>
            {opt.label}
          </option>
        ))}
      </select>
    </label>
  );
}
