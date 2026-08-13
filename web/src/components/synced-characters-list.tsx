"use client";

import Link from "next/link";
import { useRouter } from "next/navigation";
import { useEffect, useState, useTransition } from "react";
import { setActiveCharacter } from "@/actions/character";
import { updateCharacterStatus } from "@/actions/sync";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import type { CharacterRow, HardcoreStatus } from "@/lib/types";
import { cn, formatDateTime, formatPoints, formatRelativeTime } from "@/lib/utils";

export function SyncedCharactersList({
  characters,
  activeId,
}: {
  characters: CharacterRow[];
  activeId: string | null;
}) {
  const ordered = activeId
    ? [
        ...characters.filter((character) => character.id === activeId),
        ...characters.filter((character) => character.id !== activeId),
      ]
    : characters;

  return (
    <section>
      <div className="mb-3 flex flex-wrap items-end justify-between gap-2">
        <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50">
          Your characters
        </h2>
        <p className="text-sm text-zinc-500">
          {ordered.length} synced
        </p>
      </div>

      <div className="overflow-hidden rounded-xl border border-zinc-800 bg-zinc-900/50">
        <ul className="divide-y divide-zinc-800/80 md:hidden">
          {ordered.map((character) => (
            <MobileCharacterRow
              key={character.id}
              character={character}
              active={character.id === activeId}
            />
          ))}
        </ul>

        <div className="hidden overflow-x-auto md:block">
          <table className="min-w-full text-left text-sm">
            <thead className="border-b border-zinc-800 bg-zinc-950/80 text-xs uppercase tracking-wider text-zinc-500">
              <tr>
                <th className="px-4 py-3 font-medium">Character</th>
                <th className="px-4 py-3 font-medium">Class</th>
                <th className="px-4 py-3 font-medium">Realm</th>
                <th className="px-4 py-3 font-medium">Level</th>
                <th className="px-4 py-3 font-medium">Status</th>
                <th className="px-4 py-3 font-medium text-right">Achievements</th>
                <th className="px-4 py-3 font-medium text-right">Points</th>
                <th className="px-4 py-3 font-medium">Last sync</th>
                <th className="px-4 py-3 font-medium">
                  <span className="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody>
              {ordered.map((character) => (
                <DesktopCharacterRow
                  key={character.id}
                  character={character}
                  active={character.id === activeId}
                />
              ))}
            </tbody>
          </table>
        </div>
      </div>
    </section>
  );
}

function MobileCharacterRow({
  character,
  active,
}: {
  character: CharacterRow;
  active: boolean;
}) {
  const color = getClassColor(character.class);
  const actions = useCharacterActions(character);

  return (
    <li
      className={cn(
        "px-4 py-3",
        active && "bg-amber-500/5",
      )}
    >
      <div className="flex items-start justify-between gap-3">
        <div className="min-w-0">
          <div className="flex flex-wrap items-center gap-2">
            <Link
              href={`/characters/${character.id}`}
              className="truncate font-semibold underline-offset-2 hover:underline"
              style={{ color }}
            >
              {character.name}
            </Link>
            {active ? <ActiveBadge /> : null}
          </div>
          <p className="mt-0.5 text-xs text-zinc-400">
            {getClassLabel(character.class)} · {character.realm} · L
            {character.level}
            {character.race ? ` · ${character.race}` : ""}
          </p>
        </div>
        <div className="shrink-0 text-right">
          <div className="text-sm font-semibold text-amber-400">
            {formatPoints(character.total_points)}
          </div>
          <div className="text-[10px] uppercase tracking-wider text-zinc-600">
            pts
          </div>
        </div>
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-2">
        <StatusToggle
          status={actions.status}
          pending={actions.pending}
          onToggle={actions.toggleStatus}
        />
        <span className="text-xs text-zinc-500">
          {character.achievement_count} ach
        </span>
        <span
          className="text-xs text-zinc-500"
          title={lastSyncTitle(character.last_synced_at)}
        >
          {lastSyncLabel(character.last_synced_at)}
        </span>
        {active ? null : (
          <button
            type="button"
            onClick={actions.makeActive}
            disabled={actions.pending}
            className="rounded-md border border-zinc-700 px-2 py-0.5 text-xs text-zinc-300 transition hover:border-amber-500/40 hover:text-amber-200 disabled:opacity-50"
          >
            Set active
          </button>
        )}
      </div>
      {actions.error ? (
        <p className="mt-2 text-xs text-rose-300">{actions.error}</p>
      ) : null}
    </li>
  );
}

function DesktopCharacterRow({
  character,
  active,
}: {
  character: CharacterRow;
  active: boolean;
}) {
  const color = getClassColor(character.class);
  const actions = useCharacterActions(character);

  return (
    <tr
      className={cn(
        "border-b border-zinc-800/80 transition hover:bg-zinc-800/40",
        active && "bg-amber-500/5",
      )}
    >
      <td className="px-4 py-3">
        <div className="flex items-center gap-2">
          <Link
            href={`/characters/${character.id}`}
            className="font-semibold underline-offset-2 hover:underline"
            style={{ color }}
          >
            {character.name}
          </Link>
          {active ? <ActiveBadge /> : null}
        </div>
        {character.race ? (
          <p className="mt-0.5 text-xs text-zinc-500">{character.race}</p>
        ) : null}
      </td>
      <td className="px-4 py-3">
        <span
          className="rounded-md border px-2 py-0.5 text-xs"
          style={{
            color,
            borderColor: `${color}55`,
            backgroundColor: `${color}14`,
          }}
        >
          {getClassLabel(character.class)}
        </span>
      </td>
      <td className="px-4 py-3 text-zinc-400">{character.realm}</td>
      <td className="px-4 py-3 text-zinc-300">{character.level}</td>
      <td className="px-4 py-3">
        <StatusToggle
          status={actions.status}
          pending={actions.pending}
          onToggle={actions.toggleStatus}
        />
      </td>
      <td className="px-4 py-3 text-right text-zinc-300">
        {character.achievement_count}
      </td>
      <td className="px-4 py-3 text-right font-semibold text-amber-400">
        {formatPoints(character.total_points)}
      </td>
      <td
        className="px-4 py-3 text-zinc-400"
        title={lastSyncTitle(character.last_synced_at)}
      >
        {lastSyncLabel(character.last_synced_at)}
      </td>
      <td className="px-4 py-3 text-right">
        {active ? null : (
          <button
            type="button"
            onClick={actions.makeActive}
            disabled={actions.pending}
            className="rounded-md border border-zinc-700 px-2 py-1 text-xs text-zinc-300 transition hover:border-amber-500/40 hover:text-amber-200 disabled:opacity-50"
          >
            Set active
          </button>
        )}
        {actions.error ? (
          <p className="mt-1 text-xs text-rose-300">{actions.error}</p>
        ) : null}
      </td>
    </tr>
  );
}

function useCharacterActions(character: CharacterRow) {
  const router = useRouter();
  const [pending, startTransition] = useTransition();
  const [status, setStatus] = useState<HardcoreStatus>(character.status);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    setStatus(character.status);
  }, [character.status, character.id]);

  const makeActive = () => {
    startTransition(async () => {
      const result = await setActiveCharacter(character.id);
      if (!result.ok) {
        setError(result.message);
        return;
      }
      router.refresh();
    });
  };

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

  return { pending, status, error, makeActive, toggleStatus };
}

function StatusToggle({
  status,
  pending,
  onToggle,
}: {
  status: HardcoreStatus;
  pending: boolean;
  onToggle: () => void;
}) {
  return (
    <button
      type="button"
      onClick={onToggle}
      disabled={pending}
      aria-pressed={status === "Dead"}
      className={cn(
        "rounded-md px-2 py-0.5 text-xs font-medium transition disabled:opacity-50",
        status === "Alive"
          ? "bg-emerald-500/15 text-emerald-300 hover:bg-emerald-500/25"
          : "bg-rose-500/15 text-rose-300 hover:bg-rose-500/25",
      )}
    >
      {status}
    </button>
  );
}

function ActiveBadge() {
  return (
    <span className="rounded-md border border-amber-500/40 bg-amber-500/15 px-1.5 py-0.5 text-[10px] font-semibold uppercase tracking-wider text-amber-200">
      Active
    </span>
  );
}

function lastSyncLabel(lastSyncedAt: string | null) {
  if (!lastSyncedAt) return "Never";
  return formatRelativeTime(lastSyncedAt);
}

function lastSyncTitle(lastSyncedAt: string | null) {
  if (!lastSyncedAt) return undefined;
  return formatDateTime(lastSyncedAt);
}
