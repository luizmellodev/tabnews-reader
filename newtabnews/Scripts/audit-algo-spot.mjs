#!/usr/bin/env node
/**
 * Audits AlgoSpot challenge pools.
 * Run from repo root: node newtabnews/Scripts/audit-algo-spot.mjs
 */
import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const ALGO_SPOT_DIR = join(__dirname, "../newtabnews/Core/Views/RestGames/AlgoSpot");
const DAILY_PATH = join(ALGO_SPOT_DIR, "algo_spot_daily.json");
const FREE_PATH = join(ALGO_SPOT_DIR, "algo_spot_free.json");

const MIN_DAILY = 30;
const MIN_FREE = 40;
const VALID_DIFFICULTIES = new Set(["easy", "medium", "hard"]);
const MAX_SNIPPET_LINES = 12;
const FUNCTION_LINE = /^function\s+\w+\s*\(/;

function stripFunctionDeclaration(snippet) {
  const lines = snippet.split("\n");
  if (lines[0] && FUNCTION_LINE.test(lines[0])) {
    return lines.slice(1).join("\n");
  }
  return snippet;
}

function containsSpoiler(snippet, answer) {
  const body = stripFunctionDeclaration(snippet).toLowerCase();
  const normalizedAnswer = answer.toLowerCase();
  if (body.includes(normalizedAnswer)) {
    return `answer "${answer}" appears in snippet body`;
  }
  return null;
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

    for (const field of ["title", "snippet", "answer", "whatItIs", "explanation", "reference"]) {
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
    }

    const uniqueOptions = new Set(c.options);
    if (uniqueOptions.size !== 4) {
      errors.push(`${name}/${c.id}: options must be unique`);
    }

    if (c.difficulty && !VALID_DIFFICULTIES.has(c.difficulty)) {
      errors.push(`${name}/${c.id}: invalid difficulty "${c.difficulty}"`);
    }

    const displaySnippet = stripFunctionDeclaration(c.snippet ?? "");
    const lineCount = displaySnippet.split("\n").length;
    if (lineCount > MAX_SNIPPET_LINES) {
      errors.push(`${name}/${c.id}: display snippet too long (${lineCount} lines, max ${MAX_SNIPPET_LINES})`);
    }

    const spoiler = containsSpoiler(c.snippet ?? "", c.answer ?? "");
    if (spoiler) {
      errors.push(`${name}/${c.id}: spoiler — ${spoiler}`);
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
  ...(overlap.length ? [`overlap between pools: ${overlap.join(", ")}`] : []),
];

if (errors.length) {
  console.error("AlgoSpot content audit FAILED:\n");
  errors.forEach((e) => console.error(`  - ${e}`));
  process.exit(1);
}

console.log("AlgoSpot content audit OK");
console.log(`  daily: ${daily.challenges.length} challenges`);
console.log(`  free:  ${free.challenges.length} challenges`);
console.log(`  pool overlap: 0`);
