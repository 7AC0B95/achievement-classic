"use client";

import { useMemo, useState } from "react";
import { CharacterAchievementsPanel } from "@/components/character-achievements-panel";
import { CharacterCategoryBoard } from "@/components/character-category-board";
import { CharacterDeeds } from "@/components/character-deeds";
import { CharacterProfileHeader } from "@/components/character-profile-header";
import { CharacterTravelLog } from "@/components/character-travel-log";
import {
  buildCategoryProgress,
  buildProfileHighlights,
} from "@/lib/character-profile";
import type {
  AchievementCategory,
  CharacterProfileAchievement,
  CharacterRow,
  CharacterStatsRow,
} from "@/lib/types";

interface CharacterProfileProps {
  character: CharacterRow;
  stats: CharacterStatsRow | null;
  items: CharacterProfileAchievement[];
  compareHref?: string | null;
  compareLabel?: string | null;
}

export function CharacterProfile({
  character,
  stats,
  items,
  compareHref,
  compareLabel,
}: CharacterProfileProps) {
  const [categories, setCategories] = useState<AchievementCategory[]>([]);
  const categoryProgress = useMemo(() => buildCategoryProgress(items), [items]);
  const highlights = useMemo(
    () => buildProfileHighlights(items, categoryProgress),
    [items, categoryProgress],
  );
  const catalogUnlocked = items.filter((item) => item.unlocked).length;

  const selectBoardCategory = (category: AchievementCategory) => {
    setCategories((prev) =>
      prev.length === 1 && prev[0] === category ? [] : [category],
    );
    document
      .getElementById("achievement-ledger")
      ?.scrollIntoView({ behavior: "smooth", block: "start" });
  };

  return (
    <div className="space-y-8">
      <CharacterProfileHeader
        character={character}
        stats={stats}
        catalogUnlocked={catalogUnlocked}
        catalogTotal={items.length}
        compareHref={compareHref}
        compareLabel={compareLabel}
      />
      <CharacterCategoryBoard
        progress={categoryProgress}
        selected={categories}
        onSelect={selectBoardCategory}
      />
      <CharacterDeeds highlights={highlights} />
      <CharacterTravelLog stats={stats} />
      <CharacterAchievementsPanel
        items={items}
        categories={categories}
        onCategoriesChange={setCategories}
      />
    </div>
  );
}
