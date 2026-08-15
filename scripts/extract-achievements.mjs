import fs from "fs";
import path from "path";
import { fileURLToPath } from "url";

const __dirname = path.dirname(fileURLToPath(import.meta.url));
const root = path.resolve(__dirname, "..");
const lua = fs.readFileSync(
  path.join(root, "ClassicGlory", "Data.lua"),
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
    hcOnly: /hcOnly\s*=\s*true/.test(body),
    criteria: parseCriteriaList(body),
  });
}

function unescapeLua(s) {
  return s
    .replace(/\\n/g, "\n")
    .replace(/\\"/g, '"')
    .replace(/\\\\/g, "\\");
}

function sliceBalanced(source, openBraceIndex) {
  let depth = 0;
  let inString = null;
  for (let i = openBraceIndex; i < source.length; i += 1) {
    const ch = source[i];
    const prev = source[i - 1];
    if (inString) {
      if (ch === inString && prev !== "\\") inString = null;
      continue;
    }
    if (ch === '"' || ch === "'") {
      inString = ch;
      continue;
    }
    if (ch === "{") depth += 1;
    if (ch === "}") {
      depth -= 1;
      if (depth === 0) return source.slice(openBraceIndex, i + 1);
    }
  }
  return source.slice(openBraceIndex);
}

function parseCriteriaList(body) {
  const marker = body.search(/criteria\s*=\s*\{/);
  if (marker < 0) return [];
  const eq = body.indexOf("{", marker);
  const table = sliceBalanced(body, eq);
  const criteria = [];
  const objRe = /\{([^{}]+)\}/g;
  let om;
  while ((om = objRe.exec(table))) {
    const inner = om[1];
    const type = (inner.match(/type\s*=\s*"([^"]+)"/) || [])[1];
    if (!type) continue;
    const value = Number((inner.match(/value\s*=\s*([\d.]+)/) || [])[1] || 1);
    const match = (inner.match(/match\s*=\s*"((?:\\.|[^"])*)"/) || [])[1];
    const thresholdRaw = inner.match(/threshold\s*=\s*([\d.]+)/);
    const standing = (inner.match(/standing\s*=\s*"([^"]+)"/) || [])[1];
    const crit = { type, value };
    if (match) crit.match = unescapeLua(match);
    if (thresholdRaw) crit.threshold = Number(thresholdRaw[1]);
    if (standing) crit.standing = standing;
    criteria.push(crit);
  }
  return criteria;
}

achievements.sort((a, b) => Number(a.id) - Number(b.id));

console.log(
  `Extracted ${achievements.length} achievements, ${categories.length} categories`,
);

// Generate TypeScript catalog
const lines = [];
lines.push(`import type { AchievementDefinition } from "./types";`);
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

const ruleLines = [];
ruleLines.push(`/** Criteria rules extracted from ClassicGlory/Data.lua. Do not edit by hand. */`);
ruleLines.push("");
ruleLines.push(`export type AchievementCriterionRule = {`);
ruleLines.push(`  type: string;`);
ruleLines.push(`  value: number;`);
ruleLines.push(`  match?: string;`);
ruleLines.push(`  threshold?: number;`);
ruleLines.push(`  standing?: string;`);
ruleLines.push(`};`);
ruleLines.push("");
ruleLines.push(`export type AchievementRule = {`);
ruleLines.push(`  hcOnly?: boolean;`);
ruleLines.push(`  criteria: AchievementCriterionRule[];`);
ruleLines.push(`};`);
ruleLines.push("");
ruleLines.push(`export const ACHIEVEMENT_RULES: Record<string, AchievementRule> = {`);
for (const a of achievements) {
  const rule = { criteria: a.criteria };
  if (a.hcOnly) rule.hcOnly = true;
  ruleLines.push(`  ${JSON.stringify(a.id)}: ${JSON.stringify(rule)},`);
}
ruleLines.push(`};`);
ruleLines.push("");

const rulesPath = path.join(root, "web", "src", "lib", "achievement-rules.ts");
fs.writeFileSync(rulesPath, ruleLines.join("\n"));
console.log(`Wrote ${rulesPath}`);

// Generate SQL seed fragment
function sqlEscape(s) {
  return String(s).replace(/'/g, "''");
}

const sqlRows = achievements.map((a) => {
  const icon = a.icon ? `'${sqlEscape(a.icon)}'` : "null";
  return `  ('${sqlEscape(a.id)}', '${sqlEscape(a.name)}', '${sqlEscape(a.description)}', '${sqlEscape(a.category)}', ${a.points}, ${icon})`;
});

const sql = `-- Seed Classic Glory catalog (${achievements.length} achievements)
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
