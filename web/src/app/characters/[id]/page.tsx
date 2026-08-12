import Link from "next/link";
import { cookies } from "next/headers";
import { notFound } from "next/navigation";
import { ArrowLeft } from "lucide-react";
import { CharacterProfile } from "@/components/character-profile";
import {
  ACTIVE_CHARACTER_COOKIE,
  resolveActiveCharacter,
} from "@/lib/active-character";
import { joinCatalogWithUnlocks } from "@/lib/character-profile";
import {
  fetchAchievements,
  fetchCharacterAchievements,
  fetchCharacterById,
  fetchCharacterStats,
  fetchUserCharacters,
} from "@/lib/data";

interface CharacterProfilePageProps {
  params: Promise<{ id: string }>;
}

export async function generateMetadata({ params }: CharacterProfilePageProps) {
  const { id } = await params;
  const character = await fetchCharacterById(id);
  if (!character) {
    return { title: "Character not found | Laucob's Achievements" };
  }
  return {
    title: `${character.name}-${character.realm} | Laucob's Achievements`,
    description: `Character profile for ${character.name} on ${character.realm}`,
  };
}

export default async function CharacterProfilePage({
  params,
}: CharacterProfilePageProps) {
  const { id } = await params;
  const character = await fetchCharacterById(id);
  if (!character) notFound();

  const [unlocks, stats, mine, catalog] = await Promise.all([
    fetchCharacterAchievements(character.id),
    fetchCharacterStats(character.id),
    fetchUserCharacters(),
    fetchAchievements(),
  ]);
  const cookieStore = await cookies();
  const active = resolveActiveCharacter(
    mine,
    cookieStore.get(ACTIVE_CHARACTER_COOKIE)?.value,
  );
  const canCompare = Boolean(active && active.id !== character.id);
  const items = joinCatalogWithUnlocks(catalog, unlocks);

  return (
    <div className="mx-auto max-w-6xl space-y-8 px-4 py-10 sm:px-6">
      <Link
        href="/leaderboard"
        className="inline-flex items-center gap-2 text-sm text-zinc-400 transition hover:text-amber-300"
      >
        <ArrowLeft className="h-4 w-4" />
        Back to leaderboard
      </Link>

      <CharacterProfile
        character={character}
        stats={stats}
        items={items}
        compareHref={
          canCompare && active
            ? `/achievements?character=${active.id}&compare=${character.id}`
            : null
        }
        compareLabel={active && canCompare ? active.name : null}
      />
    </div>
  );
}
