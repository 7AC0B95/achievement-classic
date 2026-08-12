import { AuthPanel } from "@/components/auth-panel";
import { CharacterCard } from "@/components/character-card";
import { CharacterSelect } from "@/components/character-select";
import { FileSyncPanel } from "@/components/file-sync-panel";
import {
  ACTIVE_CHARACTER_COOKIE,
  resolveActiveCharacter,
} from "@/lib/active-character";
import { fetchUserCharacters } from "@/lib/data";
import { cookies } from "next/headers";

export default async function DashboardPage() {
  const characters = await fetchUserCharacters();
  const cookieStore = await cookies();
  const selected = resolveActiveCharacter(
    characters,
    cookieStore.get(ACTIVE_CHARACTER_COOKIE)?.value,
  );
  const others = characters.filter((character) => character.id !== selected?.id);

  return (
    <div className="mx-auto max-w-6xl space-y-6 px-4 py-10 sm:px-6">
      <div className="flex flex-wrap items-end justify-between gap-4">
        <div>
          <h1 className="font-[family-name:var(--font-display)] text-3xl text-zinc-50">
            Dashboard
          </h1>
          <p className="mt-2 text-zinc-400">
            Connect your addon SavedVariables file, sign in, and push character
            progress to the global boards.
          </p>
        </div>
        {characters.length > 0 ? (
          <CharacterSelect
            characters={characters}
            selectedId={selected?.id ?? null}
            persistActive
            label="Active character"
            className="w-full sm:w-72"
          />
        ) : null}
      </div>

      <AuthPanel />
      <FileSyncPanel />

      {selected ? (
        <CharacterCard character={selected} active />
      ) : (
        <section className="rounded-xl border border-dashed border-zinc-700 bg-zinc-900/30 px-6 py-12 text-center">
          <h2 className="font-[family-name:var(--font-display)] text-xl text-zinc-200">
            No synced character yet
          </h2>
          <p className="mx-auto mt-2 max-w-lg text-sm text-zinc-500">
            Install Laucob&apos;s Achievements, play until achievements unlock,
            then log out so SavedVariables flush. Sign in above and upload the
            account-wide file from the panel.
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
              {"\\SavedVariables\\LaucobsAchievements.lua"}
            </code>
            <p className="mt-2 text-xs text-zinc-600">
              Replace the highlighted part with your Battle.net account folder
              name. One file covers every character on that account.
            </p>
          </div>
        </section>
      )}

      {others.length > 0 ? (
        <section>
          <h2 className="mb-3 font-[family-name:var(--font-display)] text-xl text-zinc-50">
            Your characters
          </h2>
          <div className="grid gap-4 md:grid-cols-2">
            {others.map((character) => (
              <CharacterCard key={character.id} character={character} />
            ))}
          </div>
        </section>
      ) : null}
    </div>
  );
}
