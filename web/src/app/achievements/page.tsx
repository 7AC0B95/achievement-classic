import { AchievementsCatalog } from "@/components/achievements-catalog";
import {
  fetchAchievements,
  fetchUnlockedIdsForCharacter,
  fetchUserCharacters,
} from "@/lib/data";

export default async function AchievementsPage() {
  const [achievements, characters] = await Promise.all([
    fetchAchievements(),
    fetchUserCharacters(),
  ]);
  const selected = characters[0] ?? null;
  const unlocked = await fetchUnlockedIdsForCharacter(selected?.id ?? null);

  const catalog = achievements.map((achievement) => ({
    ...achievement,
    unlocked: unlocked.has(achievement.id),
  }));

  const characterLabel = selected
    ? `${selected.name}-${selected.realm}`
    : null;

  return (
    <div className="mx-auto max-w-6xl px-4 py-10 sm:px-6">
      <AchievementsCatalog
        achievements={catalog}
        characterLabel={characterLabel}
      />
    </div>
  );
}
