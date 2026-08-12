import {
  Bug,
  Coffee,
  Crown,
  Flame,
  Globe,
  HeartCrack,
  HeartPulse,
  Home,
  Landmark,
  Map,
  Medal,
  Mountain,
  Scroll,
  Shirt,
  Signpost,
  Skull,
  Star,
  Sword,
  Swords,
  Trees,
  Trophy,
  type LucideIcon,
} from "lucide-react";

export const ACHIEVEMENT_ICONS: Record<string, LucideIcon> = {
  shirt: Shirt,
  star: Star,
  medal: Medal,
  crown: Crown,
  "heart-pulse": HeartPulse,
  "heart-crack": HeartCrack,
  sword: Sword,
  swords: Swords,
  map: Map,
  scroll: Scroll,
  skull: Skull,
  coffee: Coffee,
  flame: Flame,
  bug: Bug,
  globe: Globe,
  landmark: Landmark,
  trees: Trees,
  mountain: Mountain,
  home: Home,
  signpost: Signpost,
};

export function getAchievementIcon(icon?: string | null): LucideIcon {
  if (icon && ACHIEVEMENT_ICONS[icon]) return ACHIEVEMENT_ICONS[icon];
  return Trophy;
}
