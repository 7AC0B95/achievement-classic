"use client";

import {
  AlertTriangle,
  CheckCircle2,
  ChevronDown,
  Loader2,
  Upload,
} from "lucide-react";
import { useRouter } from "next/navigation";
import { useEffect, useMemo, useRef, useState } from "react";
import { useWowSync } from "@/hooks/use-wow-sync";
import { getAchievementById } from "@/lib/achievements";
import {
  ADDON_SAVED_VARIABLES_FILE,
  FILE_SYNC_LIST_COLLAPSED_COOKIE,
} from "@/lib/addon";
import { getClassColor, getClassLabel } from "@/lib/class-colors";
import type { ParsedCharacterBundle } from "@/lib/types";
import { cn, formatDateTime, formatPoints } from "@/lib/utils";

const EMPTY_CHARACTERS: ParsedCharacterBundle[] = [];
const COOKIE_MAX_AGE = 60 * 60 * 24 * 365;

function persistListOpen(open: boolean) {
  try {
    const collapsed = open ? "0" : "1";
    const secure = window.location.protocol === "https:" ? "; Secure" : "";
    document.cookie = `${FILE_SYNC_LIST_COLLAPSED_COOKIE}=${collapsed}; Path=/; Max-Age=${COOKIE_MAX_AGE}; SameSite=Lax${secure}`;
  } catch {
    // Private mode / blocked cookies
  }
}

export function FileSyncPanel({
  defaultOpen = true,
}: {
  defaultOpen?: boolean;
}) {
  const router = useRouter();
  const sync = useWowSync();
  const inputRef = useRef<HTMLInputElement>(null);
  const [selectedKeys, setSelectedKeys] = useState<string[]>([]);
  const [listOpen, setListOpen] = useState(defaultOpen);

  const toggleList = () => {
    const next = !listOpen;
    setListOpen(next);
    persistListOpen(next);
  };

  const busy =
    sync.status === "connecting" ||
    sync.status === "reading" ||
    sync.status === "syncing";

  const characters = sync.parsed?.characters ?? EMPTY_CHARACTERS;

  useEffect(() => {
    setSelectedKeys((prev) => {
      if (characters.length === 0) {
        return prev.length === 0 ? prev : [];
      }
      const valid = prev.filter((k) => characters.some((c) => c.key === k));
      if (valid.length === 0) return characters.map((c) => c.key);
      if (valid.length === prev.length && valid.every((k, i) => k === prev[i])) {
        return prev;
      }
      return valid;
    });
  }, [characters]);

  const selectedBundles = useMemo(
    () => characters.filter((c) => selectedKeys.includes(c.key)),
    [characters, selectedKeys],
  );

  const onUploadChange = async (fileList: FileList | null) => {
    const file = fileList?.[0];
    if (!file) return;
    await sync.uploadAndParse(file);
    if (inputRef.current) inputRef.current.value = "";
  };

  const onSyncSelected = async () => {
    const result = await sync.syncCharacters(selectedBundles);
    if (result.ok) router.refresh();
  };

  const toggleKey = (key: string) => {
    setSelectedKeys((prev) =>
      prev.includes(key) ? prev.filter((k) => k !== key) : [...prev, key],
    );
  };

  return (
    <section className="rounded-xl border border-zinc-800 bg-zinc-900/60 p-4 sm:p-6">
      <div className="flex flex-wrap items-start justify-between gap-4">
        <div>
          <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-50">
            File connection
          </h2>
          <p className="mt-1 max-w-xl text-sm text-zinc-400">
            After playing with the in-game addon, sync progress by uploading{" "}
            <code className="rounded bg-zinc-950 px-1.5 py-0.5 text-amber-300">
              {ADDON_SAVED_VARIABLES_FILE}
            </code>
            .
            <br />
            Find it in your Classic Era install at{" "}
            <code className="rounded bg-zinc-950 px-1.5 py-0.5 text-zinc-300">
              {"_classic_era_\\WTF\\Account\\<Account>\\SavedVariables\\"}
            </code>
            .
            <br />
            Log out first so the account-wide file includes every character.
          </p>
        </div>

        <StatusPill status={sync.status} fileName={sync.fileName} />
      </div>

      <div className="mt-4 flex items-start gap-2 rounded-lg border border-amber-500/25 bg-amber-500/10 px-3 py-3 text-sm text-amber-100/90">
        <AlertTriangle className="mt-0.5 h-4 w-4 shrink-0 text-amber-400" />
        <p>
          After you play more, upload the same{" "}
          <code className="text-amber-200">.lua</code> again and sync selected
          characters to push fresh unlocks.
        </p>
      </div>

      <input
        ref={inputRef}
        type="file"
        accept=".lua,text/plain"
        className="hidden"
        onChange={(e) => void onUploadChange(e.target.files)}
      />

      <div className="mt-5 flex flex-col gap-3 sm:flex-row sm:flex-wrap">
        <button
          type="button"
          onClick={() => inputRef.current?.click()}
          disabled={busy}
          className="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-md bg-amber-500 px-4 py-2.5 text-sm font-semibold text-zinc-950 transition hover:bg-amber-400 disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
        >
          {busy && sync.status === "reading" ? (
            <Loader2 className="h-4 w-4 animate-spin" />
          ) : (
            <Upload className="h-4 w-4" />
          )}
          Upload .lua
        </button>

        {characters.length > 0 ? (
          <button
            type="button"
            onClick={() => void onSyncSelected()}
            disabled={busy || selectedBundles.length === 0}
            className="inline-flex min-h-11 w-full items-center justify-center gap-2 rounded-md border border-amber-500/50 bg-amber-500/10 px-4 py-2.5 text-sm font-semibold text-amber-200 transition hover:bg-amber-500/20 disabled:cursor-not-allowed disabled:opacity-50 sm:w-auto"
          >
            {busy && sync.status === "syncing" ? (
              <Loader2 className="h-4 w-4 animate-spin" />
            ) : (
              <CheckCircle2 className="h-4 w-4" />
            )}
            Sync selected ({selectedBundles.length})
          </button>
        ) : null}
      </div>

      {sync.error ? (
        <p className="mt-4 text-sm text-rose-300">{sync.error}</p>
      ) : null}
      {sync.syncMessage ? (
        <p className="mt-4 text-sm text-emerald-300">{sync.syncMessage}</p>
      ) : null}

      {characters.length > 0 ? (
        <div className="mt-5 space-y-3">
          <div className="flex flex-wrap items-center justify-between gap-2">
            <button
              type="button"
              aria-expanded={listOpen}
              aria-controls="characters-in-file-list"
              onClick={toggleList}
              className="flex items-center gap-1.5 text-xs uppercase tracking-wider text-zinc-500 transition hover:text-zinc-300"
            >
              <ChevronDown
                className={cn(
                  "h-3.5 w-3.5 transition",
                  listOpen && "rotate-180",
                )}
              />
              Characters in file ({characters.length})
            </button>
            <div className="flex gap-2 text-xs">
              <button
                type="button"
                className="text-amber-300 hover:underline"
                onClick={() => setSelectedKeys(characters.map((c) => c.key))}
              >
                Select all
              </button>
              <button
                type="button"
                className="text-zinc-400 hover:underline"
                onClick={() => setSelectedKeys([])}
              >
                Clear
              </button>
            </div>
          </div>

          {listOpen ? (
            <ul id="characters-in-file-list" className="space-y-2">
              {characters.map((bundle) => {
                const pts = bundle.completed.reduce((sum, entry) => {
                  const catalog = getAchievementById(entry.id)?.points ?? 0;
                  return sum + (entry.points ?? catalog);
                }, 0);
                const checked = selectedKeys.includes(bundle.key);
                return (
                  <li key={bundle.key}>
                    <label
                      className={cn(
                        "flex cursor-pointer items-start gap-3 rounded-lg border px-3 py-3 transition",
                        checked
                          ? "border-amber-500/40 bg-amber-500/5"
                          : "border-zinc-800 bg-zinc-950/70 hover:border-zinc-700",
                      )}
                    >
                      <input
                        type="checkbox"
                        className="mt-1"
                        checked={checked}
                        onChange={() => toggleKey(bundle.key)}
                      />
                      <div className="min-w-0 flex-1">
                        <p className="text-sm">
                          <span
                            className="font-semibold"
                            style={{
                              color: getClassColor(bundle.character.class),
                            }}
                          >
                            {bundle.character.name}
                          </span>
                          <span className="mt-0.5 block text-zinc-500 sm:mt-0 sm:inline">
                            <span className="hidden sm:inline"> · </span>
                            {getClassLabel(bundle.character.class)} ·{" "}
                            {bundle.character.realm} · L{bundle.character.level} ·{" "}
                            {bundle.character.status}
                          </span>
                        </p>
                        <p className="mt-1 text-sm text-zinc-400">
                          {bundle.completed.length} achievements ·{" "}
                          <span className="text-amber-400">
                            {formatPoints(pts)} pts
                          </span>
                        </p>
                        {!bundle.character.lastUpdated ||
                        bundle.character.class === "UNKNOWN" ? (
                          <p className="mt-1 text-xs text-amber-300/80">
                            Log into this character once so the addon can save
                            class, race, and level.
                          </p>
                        ) : null}
                      </div>
                    </label>
                  </li>
                );
              })}
            </ul>
          ) : null}
        </div>
      ) : null}

      {sync.lastSyncedAt ? (
        <p className="mt-3 text-xs text-zinc-500">
          Last synced {formatDateTime(sync.lastSyncedAt)}
        </p>
      ) : null}
    </section>
  );
}

function StatusPill({
  status,
  fileName,
}: {
  status: string;
  fileName: string | null;
}) {
  const connected = Boolean(fileName) && status !== "error";
  return (
    <div
      className={cn(
        "inline-flex items-center gap-2 rounded-full border px-3 py-1.5 text-xs font-medium",
        connected
          ? "border-emerald-500/40 bg-emerald-500/10 text-emerald-300"
          : status === "error"
            ? "border-rose-500/40 bg-rose-500/10 text-rose-300"
            : "border-zinc-700 bg-zinc-950 text-zinc-400",
      )}
    >
      {connected ? (
        <CheckCircle2 className="h-3.5 w-3.5" />
      ) : (
        <span className="h-2 w-2 rounded-full bg-zinc-500" />
      )}
      {fileName ? `${fileName} · uploaded` : "Not connected"}
    </div>
  );
}
