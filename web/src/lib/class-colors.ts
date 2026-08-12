import type { WowClass } from "@/lib/types";

export const CLASS_COLORS: Record<string, string> = {
  WARRIOR: "#C79C6E",
  PALADIN: "#F58CBA",
  HUNTER: "#ABD473",
  ROGUE: "#FFF569",
  PRIEST: "#FFFFFF",
  SHAMAN: "#0070DE",
  MAGE: "#69CCF0",
  WARLOCK: "#9482C9",
  DRUID: "#FF7D0A",
};

export const CLASS_LABELS: Record<string, string> = {
  WARRIOR: "Warrior",
  PALADIN: "Paladin",
  HUNTER: "Hunter",
  ROGUE: "Rogue",
  PRIEST: "Priest",
  SHAMAN: "Shaman",
  MAGE: "Mage",
  WARLOCK: "Warlock",
  DRUID: "Druid",
  UNKNOWN: "Unknown",
};

export function getClassColor(classToken: string): string {
  return CLASS_COLORS[classToken.toUpperCase()] ?? "#f59e0b";
}

export function getClassLabel(classToken: string): string {
  return CLASS_LABELS[classToken.toUpperCase()] ?? classToken;
}

export const WOW_CLASSES = (
  Object.keys(CLASS_LABELS) as Array<keyof typeof CLASS_LABELS>
).filter((token): token is WowClass => token !== "UNKNOWN");
