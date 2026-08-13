import type { CharacterRow } from "@/lib/types";

export const ACTIVE_CHARACTER_COOKIE = "classic_glory_active_character";

const UUID_RE =
  /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isCharacterId(value: string | null | undefined): value is string {
  return Boolean(value && UUID_RE.test(value));
}

export function activeCharacterCookieOptions() {
  return {
    path: "/",
    maxAge: 60 * 60 * 24 * 365,
    sameSite: "lax" as const,
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
  };
}

export function formatCharacterLabel(character: {
  name: string;
  realm: string;
}) {
  return `${character.name}-${character.realm}`;
}

export function resolveActiveCharacter(
  characters: CharacterRow[],
  preferredId: string | null | undefined,
): CharacterRow | null {
  if (characters.length === 0) return null;
  if (preferredId) {
    const match = characters.find((character) => character.id === preferredId);
    if (match) return match;
  }
  return characters[0];
}
