"use server";

import {
  ACTIVE_CHARACTER_COOKIE,
  activeCharacterCookieOptions,
  isCharacterId,
} from "@/lib/active-character";
import { fetchUserCharacters } from "@/lib/data";
import { cookies } from "next/headers";

export async function setActiveCharacter(characterId: string) {
  if (!isCharacterId(characterId)) {
    return { ok: false as const, message: "Invalid character." };
  }

  const characters = await fetchUserCharacters();
  if (!characters.some((character) => character.id === characterId)) {
    return { ok: false as const, message: "Character not found on this account." };
  }

  const cookieStore = await cookies();
  cookieStore.set(
    ACTIVE_CHARACTER_COOKIE,
    characterId,
    activeCharacterCookieOptions(),
  );

  return { ok: true as const };
}
