export const FACTION_COLORS: Record<string, string> = {
  Alliance: "#3b82f6",
  Horde: "#ef4444",
  Unknown: "#a1a1aa",
};

const RACE_LABELS: Record<string, string> = {
  scourge: "Undead",
};

export function getRaceLabel(race: string): string {
  const key = race.trim().toLowerCase();
  return RACE_LABELS[key] ?? race;
}

export function getFactionColor(faction: string): string {
  return FACTION_COLORS[faction] ?? FACTION_COLORS.Unknown;
}
