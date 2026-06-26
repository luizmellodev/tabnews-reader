#!/usr/bin/env node
/**
 * Audits Big O challenge pools.
 * Run from repo root: node newtabnews/Scripts/audit-big-o.mjs
 */
import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const BIG_O_DIR = join(__dirname, "../newtabnews/Core/Views/RestGames/BigO");
const DAILY_PATH = join(BIG_O_DIR, "big_o_daily.json");
const FREE_PATH = join(BIG_O_DIR, "big_o_free.json");

const MIN_DAILY = 30;
const MIN_FREE = 40;
const VALID_DIFFICULTIES = new Set(["easy", "medium", "hard"]);
const MAX_SNIPPET_LINES = 12;
const ALLOWED_COMPLEXITY = /^O\((1|log n|n( log n|²|³)?|2\^n|n!)\)$/;

function isAllowedComplexity(value) {
  return ALLOWED_COMPLEXITY.test(value);
}

function validatePool(name, data, minCount) {
  const errors = [];
  const challenges = data.challenges ?? [];
  const ids = new Set();

  if (challenges.length < minCount) {
    errors.push(`${name}: too few challenges (${challenges.length} < ${minCount})`);
  }

  for (const c of challenges) {
    if (!c.id || typeof c.id !== "string") {
      errors.push(`${name}: challenge missing id`);
      continue;
    }
    if (ids.has(c.id)) {
      errors.push(`${name}: duplicate id "${c.id}"`);
    }
    ids.add(c.id);

    for (const field of ["title", "snippet", "answer", "explanation", "reference"]) {
      if (!c[field] || typeof c[field] !== "string" || !c[field].trim()) {
        errors.push(`${name}/${c.id}: missing or empty "${field}"`);
      }
    }

    if (!Array.isArray(c.options) || c.options.length !== 4) {
      errors.push(`${name}/${c.id}: options must be an array of exactly 4 items`);
    } else {
      if (!c.options.includes(c.answer)) {
        errors.push(`${name}/${c.id}: answer "${c.answer}" not in options`);
      }
      for (const option of c.options) {
        if (!isAllowedComplexity(option)) {
          errors.push(`${name}/${c.id}: non-standard option "${option}"`);
        }
      }
    }

    if (!isAllowedComplexity(c.answer)) {
      errors.push(`${name}/${c.id}: non-standard answer "${c.answer}"`);
    }

    const uniqueOptions = new Set(c.options);
    if (uniqueOptions.size !== 4) {
      errors.push(`${name}/${c.id}: options must be unique`);
    }

    if (c.difficulty && !VALID_DIFFICULTIES.has(c.difficulty)) {
      errors.push(`${name}/${c.id}: invalid difficulty "${c.difficulty}"`);
    }

    const lineCount = (c.snippet ?? "").split("\n").length;
    if (lineCount > MAX_SNIPPET_LINES) {
      errors.push(`${name}/${c.id}: snippet too long (${lineCount} lines, max ${MAX_SNIPPET_LINES})`);
    }
  }

  return { errors, ids };
}

const daily = JSON.parse(readFileSync(DAILY_PATH, "utf8"));
const free = JSON.parse(readFileSync(FREE_PATH, "utf8"));

const dailyResult = validatePool("daily", daily, MIN_DAILY);
const freeResult = validatePool("free", free, MIN_FREE);

const overlap = [...dailyResult.ids].filter((id) => freeResult.ids.has(id));
const errors = [
  ...dailyResult.errors,
  ...freeResult.errors,
  ...(overlap.length
    ? [`overlap between pools: ${overlap.join(", ")}`]
    : []),
];

if (errors.length) {
  console.error("Big O content audit FAILED:\n");
  errors.forEach((e) => console.error(`  - ${e}`));
  process.exit(1);
}

console.log("Big O content audit OK");
console.log(`  daily: ${daily.challenges.length} challenges`);
console.log(`  free:  ${free.challenges.length} challenges`);
console.log(`  pool overlap: 0`);
