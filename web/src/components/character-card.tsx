"use client";

import Link from "next/link";
import { Skull, Sparkles } from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useState, useTransition } from "react";
import { updateCharacterStatus } from "@/actions/sync";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import type { CharacterRow, HardcoreStatus } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";

interface CharacterCardProps {
  character: CharacterRow;
}

export function CharacterCard({ character }: CharacterCardProps) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [status, setStatus] = useState<HardcoreStatus>(character.status);
  const [error, setError] = useState<string | null>(null);
  const color = getClassColor(character.class);

  useEffect(() => {
    setStatus(character.status);
  }, [character.status, character.id]);

  const toggleStatus = () => {
    const previous = status;
    const next: HardcoreStatus = previous === "Alive" ? "Dead" : "Alive";
    setStatus(next);
    setError(null);

    startTransition(async () => {
      const result = await updateCharacterStatus(character.id, next);
      if (!result.ok) {
        setStatus(previous);
        setError(result.message);
        return;
      }
      router.refresh();
    });
  };

  return (
    <article
      className="relative overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/60 p-6 transition hover:border-amber-500/40 hover:shadow-[0_0_30px_rgba(245,158,11,0.1)]"
      style={{ boxShadow: `inset 3px 0 0 ${color}` }}
    >
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <p className="text-xs uppercase tracking-wider text-zinc-500">Character</p>
          <h2
            className="mt-1 font-[family-name:var(--font-display)] text-3xl"
            style={{ color }}
          >
            <Link href={`/characters/${character.id}`} className="hover:underline">
              {character.name}
            </Link>
          </h2>
          <div className="mt-3 flex flex-wrap gap-2 text-xs">
            <span
              className="rounded-md border px-2 py-1"
              style={{
                color,
                borderColor: `${color}55`,
                backgroundColor: `${color}14`,
              }}
            >
              {getClassLabel(character.class)}
            </span>
            <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2 py-1 text-zinc-300">
              {character.realm}
            </span>
            <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2 py-1 text-zinc-300">
              Level {character.level}
            </span>
            {character.race ? (
              <span className="rounded-md border border-zinc-700 bg-zinc-950 px-2 py-1 text-zinc-300">
                {character.race}
              </span>
            ) : null}
            <Link
              href={`/characters/${character.id}`}
              className="rounded-md border border-amber-500/30 bg-amber-500/10 px-2 py-1 text-amber-300 transition hover:border-amber-400/50"
            >
              View profile
            </Link>
          </div>
        </div>

        <button
          type="button"
          onClick={toggleStatus}
          disabled={pending}
          aria-pressed={status === "Dead"}
          className={cn(
            "inline-flex items-center gap-2 rounded-md border px-3 py-2 text-sm font-medium transition",
            status === "Alive"
              ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-300 hover:bg-emerald-500/20"
              : "border-rose-500/40 bg-rose-500/10 text-rose-300 hover:bg-rose-500/20",
            "disabled:cursor-not-allowed disabled:opacity-50",
          )}
        >
          {status === "Alive" ? (
            <Sparkles className="h-4 w-4" />
          ) : (
            <Skull className="h-4 w-4" />
          )}
          {status}
        </button>
      </div>

      {error ? <p className="mt-3 text-sm text-rose-300">{error}</p> : null}

      <div className="mt-6 grid grid-cols-2 gap-3 sm:grid-cols-3">
        <Stat label="Total points" value={formatPoints(character.total_points)} accent />
        <Stat label="Achievements" value={String(character.achievement_count)} />
        <Stat
          label="Last sync"
          value={
            character.last_synced_at
              ? new Date(character.last_synced_at).toLocaleString()
              : "Never"
          }
        />
      </div>
    </article>
  );
}

function Stat({
  label,
  value,
  accent,
}: {
  label: string;
  value: string;
  accent?: boolean;
}) {
  return (
    <div className="rounded-lg border border-zinc-800 bg-zinc-950/60 px-3 py-3">
      <div className="text-[11px] uppercase tracking-wider text-zinc-500">{label}</div>
      <div
        className={cn(
          "mt-1 truncate text-sm font-semibold",
          accent ? "text-amber-400" : "text-zinc-100",
        )}
      >
        {value}
      </div>
    </div>
  );
}
