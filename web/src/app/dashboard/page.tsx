import { AddonDownloadCard } from "@/components/addon-download-card";
import { AuthPanel } from "@/components/auth-panel";
import { FileSyncPanel } from "@/components/file-sync-panel";
import { SyncedCharactersList } from "@/components/synced-characters-list";
import {
  ACTIVE_CHARACTER_COOKIE,
  resolveActiveCharacter,
} from "@/lib/active-character";
import { ADDON_DOWNLOAD_COLLAPSED_COOKIE, ADDON_SAVED_VARIABLES_FILE } from "@/lib/addon";
import { fetchUserCharacters, getCurrentUser } from "@/lib/data";
import { cookies } from "next/headers";

export default async function DashboardPage() {
  const [characters, cookieStore, user] = await Promise.all([
    fetchUserCharacters(),
    cookies(),
    getCurrentUser(),
  ]);
  const selected = resolveActiveCharacter(
    characters,
    cookieStore.get(ACTIVE_CHARACTER_COOKIE)?.value,
  );
  const addonDownloadOpen = user
    ? false
    : cookieStore.get(ADDON_DOWNLOAD_COLLAPSED_COOKIE)?.value !== "1";

  return (
    <div className="mx-auto max-w-6xl space-y-6 px-4 py-6 sm:px-6 sm:py-10">
      <div className="min-w-0">
        <h1 className="font-[family-name:var(--font-display)] text-2xl text-zinc-50 sm:text-3xl">
          Dashboard
        </h1>
        <p className="mt-2 text-zinc-400">
          Install the in-game addon, sign in, upload your SavedVariables file,
          and push character progress to the global boards.
        </p>
      </div>

      <AddonDownloadCard defaultOpen={addonDownloadOpen} />
      <AuthPanel />
      <FileSyncPanel />

      {characters.length > 0 ? (
        <SyncedCharactersList
          characters={characters}
          activeId={selected?.id ?? null}
        />
      ) : (
        <section className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-12 text-center">
          <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-200">
            No synced character yet
          </h2>
          <p className="mx-auto mt-2 max-w-lg text-sm text-zinc-500">
            Download the addon above, play until achievements unlock, then log
            out so SavedVariables flush. Sign in and upload the account-wide
            file from the panel.
          </p>
          <div className="mx-auto mt-5 max-w-xl text-left">
            <p className="text-xs uppercase tracking-wider text-zinc-600">
              File location
            </p>
            <code className="mt-2 block break-all rounded-lg border border-zinc-800 bg-zinc-950/80 px-3 py-3 text-xs leading-relaxed text-zinc-400">
              {"World of Warcraft\\_classic_era_\\WTF\\Account\\"}
              <span className="rounded bg-amber-500/15 px-1 font-semibold text-amber-300">
                {"<Account>"}
              </span>
              {`\\SavedVariables\\${ADDON_SAVED_VARIABLES_FILE}`}
            </code>
            <p className="mt-2 text-xs text-zinc-600">
              Replace the highlighted part with your Battle.net account folder
              name. One file covers every character on that account.
            </p>
          </div>
        </section>
      )}
    </div>
  );
}
