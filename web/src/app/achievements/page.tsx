import { AchievementsCatalog } from "@/components/achievements-catalog";
import {
  ACTIVE_CHARACTER_COOKIE,
  isCharacterId,
  resolveActiveCharacter,
} from "@/lib/active-character";
import {
  fetchAchievements,
  fetchCharacterById,
  fetchUnlockedIdsForCharacters,
  fetchUserCharacters,
} from "@/lib/data";
import { cookies } from "next/headers";

interface AchievementsPageProps {
  searchParams: Promise<{
    character?: string;
    compare?: string;
  }>;
}

export default async function AchievementsPage({
  searchParams,
}: AchievementsPageProps) {
  const params = await searchParams;
  const cookieStore = await cookies();
  const compareHint =
    isCharacterId(params.compare) && params.compare !== params.character
      ? params.compare
      : null;

  const [achievements, characters, compareLookup] = await Promise.all([
    fetchAchievements(),
    fetchUserCharacters(),
    compareHint ? fetchCharacterById(compareHint) : Promise.resolve(null),
  ]);

  const selected = resolveActiveCharacter(
    characters,
    params.character ?? cookieStore.get(ACTIVE_CHARACTER_COOKIE)?.value,
  );

  const compareId =
    isCharacterId(params.compare) && params.compare !== selected?.id
      ? params.compare
      : null;
  const compareFromRoster = compareId
    ? (characters.find((character) => character.id === compareId) ?? null)
    : null;
  const compareCharacter =
    compareFromRoster ??
    (compareLookup && compareLookup.id === compareId ? compareLookup : null);

  const unlockedByCharacter = await fetchUnlockedIdsForCharacters(
    [selected?.id, compareCharacter?.id].filter((id): id is string => Boolean(id)),
  );
  const unlocked = selected
    ? (unlockedByCharacter.get(selected.id) ?? new Set<string>())
    : new Set<string>();
  const compareUnlocked = compareCharacter
    ? (unlockedByCharacter.get(compareCharacter.id) ?? new Set<string>())
    : null;

  const catalog = achievements.map((achievement) => ({
    ...achievement,
    unlocked: unlocked.has(achievement.id),
    compareUnlocked: compareUnlocked?.has(achievement.id),
  }));

  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <AchievementsCatalog
        achievements={catalog}
        characters={characters}
        selected={selected}
        compareCharacter={compareCharacter}
      />
    </div>
  );
}
