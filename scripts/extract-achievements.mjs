import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const lua = fs.readFileSync(
  path.join(root, "LaucobsAchievements", "Data.lua"),
  "utf8",
);

const categories = [];
const catRe =
  /\{\s*id\s*=\s*"([^"]+)",\s*name\s*=\s*"([^"]+)",\s*order\s*=\s*(\d+)\s*\}/g;
let m;
while ((m = catRe.exec(lua))) {
  categories.push({ id: m[1], name: m[2], order: Number(m[3]) });
}

const achievements = [];
const blockRe = /\[(\d+)\]\s*=\s*\{([\s\S]*?)\n\s*\},/g;
while ((m = blockRe.exec(lua))) {
  const id = m[1];
  const body = m[2];
  if (!/id\s*=\s*\d+/.test(body)) continue;
  const title = (body.match(/title\s*=\s*"((?:\\.|[^"])*)"/) || [])[1];
  const description =
    (body.match(/description\s*=\s*"((?:\\.|[^"])*)"/) || [])[1] || "";
  const icon = (body.match(/icon\s*=\s*"((?:\\.|[^"])*)"/) || [])[1] || null;
  const points = Number((body.match(/points\s*=\s*(\d+)/) || [])[1] || 0);
  const category = (body.match(/category\s*=\s*"((?:\\.|[^"])*)"/) || [])[1];
  if (!title || !category) continue;
  achievements.push({
    id: String(id),
    name: unescapeLua(title),
    description: unescapeLua(description),
    category,
    points,
    icon,
  });
}

function unescapeLua(s) {
  return s
    .replace(/\\n/g, "\n")
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\");
}

achievements.sort((a, b) => Number(a.id) - Number(b.id));

console.log(
  `Extracted ${achievements.length} achievements, ${categories.length} categories`,
);

// Generate TypeScript catalog
const dungeonIds = achievements
  .filter((a) => a.category === "Dungeons")
  .map((a) => a.id);

const lines = [];
lines.push(`import type { AchievementDefinition } from "@/lib/types";`);
lines.push("");
lines.push(`/** Canonical catalog mirrored by the Lua addon + Supabase seed. */`);
lines.push(`export const ACHIEVEMENT_CATALOG: AchievementDefinition[] = [`);
for (const a of achievements) {
  lines.push(`  {`);
  lines.push(`    id: ${JSON.stringify(a.id)},`);
  lines.push(`    name: ${JSON.stringify(a.name)},`);
  lines.push(`    description: ${JSON.stringify(a.description)},`);
  lines.push(`    category: ${JSON.stringify(a.category)},`);
  lines.push(`    points: ${a.points},`);
  if (a.icon) lines.push(`    icon: ${JSON.stringify(a.icon)},`);
  lines.push(`  },`);
}
lines.push(`];`);
lines.push("");
lines.push(`/** Used for leaderboard "dungeon clears" sort (Dungeons category). */`);
lines.push(`export const BOSS_ACHIEVEMENT_IDS = [`);
for (const id of dungeonIds) {
  lines.push(`  ${JSON.stringify(id)},`);
}
lines.push(`] as const;`);
lines.push("");
lines.push(`const byId = new Map(ACHIEVEMENT_CATALOG.map((a) => [a.id, a]));`);
lines.push("");
lines.push(
  `export function getAchievementById(id: string): AchievementDefinition | undefined {`,
);
lines.push(`  return byId.get(id);`);
lines.push(`}`);
lines.push("");

const tsPath = path.join(root, "web", "src", "lib", "achievements.ts");
fs.writeFileSync(tsPath, lines.join("\n"));
console.log(`Wrote ${tsPath}`);

// Generate SQL seed fragment
function sqlEscape(s) {
  return String(s).replace(/'/g, "''");
}

const sqlRows = achievements.map((a) => {
  const icon = a.icon ? `'${sqlEscape(a.icon)}'` : "null";
  return `  ('${sqlEscape(a.id)}', '${sqlEscape(a.name)}', '${sqlEscape(a.description)}', '${sqlEscape(a.category)}', ${a.points}, ${icon})`;
});

const sql = `-- Seed Laucobs Achievements catalog (${achievements.length} achievements)
insert into public.achievements (id, name, description, category, points, icon)
values
${sqlRows.join(",\n")}
on conflict (id) do update set
  name = excluded.name,
  description = excluded.description,
  category = excluded.category,
  points = excluded.points,
  icon = excluded.icon;
`;

const sqlPath = path.join(root, "scripts", "seed-achievements.sql");
fs.mkdirSync(path.dirname(sqlPath), { recursive: true });
fs.writeFileSync(sqlPath, sql);
console.log(`Wrote ${sqlPath}`);
console.log(
  "Note: for a fresh Supabase project, merge this seed into supabase/migrations if the catalog changed.",
);
