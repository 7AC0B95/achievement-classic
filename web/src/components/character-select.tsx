"use client";

import { setActiveCharacter } from "@/actions/character";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import { formatCharacterLabel } from "@/lib/active-character";
import type { CharacterRow } from "@/lib/types";
import { cn, formatPoints } from "@/lib/utils";
import { Check, ChevronDown } from "lucide-react";
import { usePathname, useRouter } from "next/navigation";
import { useEffect, useId, useRef, useState, useTransition } from "react";

interface CharacterSelectProps {
  characters: CharacterRow[];
  selectedId: string | null;
  label: string;
  allowEmpty?: boolean;
  emptyLabel?: string;
  persistActive?: boolean;
  urlParam?: "character" | "compare";
  compact?: boolean;
  align?: "start" | "end";
  className?: string;
}

export function CharacterSelect({
  characters,
  selectedId,
  label,
  allowEmpty = false,
  emptyLabel = "No comparison",
  persistActive = false,
  urlParam,
  compact = false,
  align = "start",
  className,
}: CharacterSelectProps) {
  const router = useRouter();
  const pathname = usePathname();
  const rootRef = useRef<HTMLDivElement>(null);
  const listId = useId();
  const [open, setOpen] = useState(false);
  const [pending, startTransition] = useTransition();

  const selected =
    characters.find((character) => character.id === selectedId) ?? null;

  useEffect(() => {
    if (!open) return;

    const onPointerDown = (event: PointerEvent) => {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    };
    const onKeyDown = (event: KeyboardEvent) => {
      if (event.key === "Escape") setOpen(false);
    };

    document.addEventListener("pointerdown", onPointerDown);
    document.addEventListener("keydown", onKeyDown);
    return () => {
      document.removeEventListener("pointerdown", onPointerDown);
      document.removeEventListener("keydown", onKeyDown);
    };
  }, [open]);

  const applySelection = (id: string | null) => {
    setOpen(false);
    if (id === selectedId || (id === null && !selectedId)) return;

    startTransition(async () => {
      if (persistActive && id) {
        const result = await setActiveCharacter(id);
        if (!result.ok) return;
      }

      const onAchievements = pathname.startsWith("/achievements");
      const shouldWriteUrl =
        Boolean(urlParam) || (persistActive && onAchievements);

      if (shouldWriteUrl) {
        const url = new URL(window.location.href);
        const param = urlParam ?? "character";
        if (!id) url.searchParams.delete(param);
        else url.searchParams.set(param, id);
        if (param === "character" && id && url.searchParams.get("compare") === id) {
          url.searchParams.delete("compare");
        }
        const query = url.searchParams.toString();
        router.replace(`${url.pathname}${query ? `?${query}` : ""}`);
        return;
      }

      router.refresh();
    });
  };

  return (
    <div ref={rootRef} className={cn("relative", open && "z-50", className)}>
      {compact ? null : (
        <span className="mb-1.5 block text-xs uppercase tracking-wider text-zinc-500">
          {label}
        </span>
      )}

      <button
        type="button"
        disabled={pending || (characters.length === 0 && !allowEmpty)}
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        aria-label={label}
        onClick={() => setOpen((value) => !value)}
        className={cn(
          "flex w-full items-center gap-2 rounded-md border border-zinc-700 bg-zinc-950 text-left text-sm text-zinc-100 outline-none transition",
          "hover:border-zinc-500 focus-visible:border-amber-500/50",
          "disabled:cursor-not-allowed disabled:opacity-60",
          compact ? "px-2.5 py-2" : "px-3 py-2.5",
          open && "border-amber-500/40",
        )}
      >
        <CharacterSwatch character={selected} />
        <span className="min-w-0 flex-1 truncate">
          {selected ? formatCharacterLabel(selected) : emptyLabel}
        </span>
        <ChevronDown
          className={cn(
            "h-4 w-4 shrink-0 text-zinc-500 transition",
            open && "rotate-180",
          )}
        />
      </button>

      {open ? (
        <ul
          id={listId}
          role="listbox"
          aria-label={label}
          className={cn(
            "absolute z-50 mt-1 max-h-80 min-w-full overflow-y-auto rounded-md border border-zinc-700 bg-zinc-950 py-1 shadow-xl shadow-black/40",
            align === "end" ? "right-0" : "left-0",
            compact && "min-w-[18rem]",
          )}
        >
          {allowEmpty ? (
            <CharacterOption
              selected={!selectedId}
              label={emptyLabel}
              onSelect={() => applySelection(null)}
            />
          ) : null}
          {characters.map((character) => (
            <CharacterOption
              key={character.id}
              character={character}
              selected={character.id === selectedId}
              onSelect={() => applySelection(character.id)}
            />
          ))}
        </ul>
      ) : null}
    </div>
  );
}

function CharacterSwatch({ character }: { character: CharacterRow | null }) {
  const color = character ? getClassColor(character.class) : "#3f3f46";
  return (
    <span
      className="h-2.5 w-2.5 shrink-0 rounded-full"
      style={{ backgroundColor: color }}
      aria-hidden
    />
  );
}

function CharacterOption({
  character,
  selected,
  label,
  onSelect,
}: {
  character?: CharacterRow;
  selected: boolean;
  label?: string;
  onSelect: () => void;
}) {
  const color = character ? getClassColor(character.class) : undefined;

  return (
    <li role="option" aria-selected={selected}>
      <button
        type="button"
        onClick={onSelect}
        className={cn(
          "flex w-full items-center gap-2.5 px-3 py-2 text-left text-sm transition",
          selected ? "bg-zinc-800/80" : "hover:bg-zinc-900",
        )}
      >
        {character ? (
          <span
            className="h-2.5 w-2.5 shrink-0 rounded-full"
            style={{ backgroundColor: color }}
            aria-hidden
          />
        ) : (
          <span className="h-2.5 w-2.5 shrink-0 rounded-full bg-zinc-700" aria-hidden />
        )}
        <span className="min-w-0 flex-1">
          {character ? (
            <>
              <span className="flex items-center gap-2">
                <span className="truncate font-medium text-zinc-100">
                  {character.name}
                </span>
                <span
                  className={cn(
                    "rounded px-1.5 py-0.5 text-[10px] font-medium",
                    character.status === "Alive"
                      ? "bg-emerald-500/15 text-emerald-300"
                      : "bg-rose-500/15 text-rose-300",
                  )}
                >
                  {character.status}
                </span>
              </span>
              <span className="mt-0.5 block truncate text-xs text-zinc-500">
                {character.realm} · {getClassLabel(character.class)} · L
                {character.level} · {formatPoints(character.total_points)} pts
              </span>
            </>
          ) : (
            <span className="text-zinc-400">{label}</span>
          )}
        </span>
        {selected ? <Check className="h-4 w-4 shrink-0 text-amber-400" /> : null}
      </button>
    </li>
  );
}
