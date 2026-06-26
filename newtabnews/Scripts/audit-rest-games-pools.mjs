#!/usr/bin/env node
/**
 * Verifies Big O / AlgoSpot pool overlap targets.
 * Run: node newtabnews/Scripts/audit-rest-games-pools.mjs
 */
import { readFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const BASE = join(__dirname, "../newtabnews/Core/Views/RestGames");

const TARGET_TOTAL = 100;
const TARGET_SHARED = 50;

function norm(snippet) {
  return snippet.replace(/function \w+/, "function f").trim();
}

function load(game, file) {
  return JSON.parse(readFileSync(join(BASE, game, file), "utf8")).challenges;
}

function analyze(game, dailyFile, freeFile) {
  const all = [...load(game, dailyFile), ...load(game, freeFile)];
  const daily = load(game, dailyFile);
  const free = load(game, freeFile);
  const ids = new Set(all.map((c) => c.id));
  const overlap = [...daily.map((c) => c.id)].filter((id) => free.some((f) => f.id === id));

  return { all, ids, daily: daily.length, free: free.length, overlap };
}

const bigO = analyze("BigO", "big_o_daily.json", "big_o_free.json");
const algo = analyze("AlgoSpot", "algo_spot_daily.json", "algo_spot_free.json");

const bigSnippets = new Map(bigO.all.map((c) => [norm(c.snippet), c.id]));
const algoSnippets = new Map(algo.all.map((c) => [norm(c.snippet), c.id]));

const shared = [...bigSnippets.keys()].filter((s) => algoSnippets.has(s));
const bigOnly = bigO.all.filter((c) => !algoSnippets.has(norm(c.snippet)));
const algoOnly = algo.all.filter((c) => !bigSnippets.has(norm(c.snippet)));

const errors = [];

if (bigO.all.length !== TARGET_TOTAL) {
  errors.push(`Big O total: ${bigO.all.length} (expected ${TARGET_TOTAL})`);
}
if (algo.all.length !== TARGET_TOTAL) {
  errors.push(`AlgoSpot total: ${algo.all.length} (expected ${TARGET_TOTAL})`);
}
if (bigO.overlap.length) {
  errors.push(`Big O daily/free overlap: ${bigO.overlap.join(", ")}`);
}
if (algo.overlap.length) {
  errors.push(`AlgoSpot daily/free overlap: ${algo.overlap.join(", ")}`);
}
if (shared.length !== TARGET_SHARED) {
  errors.push(`Shared snippets: ${shared.length} (expected ${TARGET_SHARED})`);
}
if (bigOnly.length !== TARGET_SHARED) {
  errors.push(`Big O exclusive snippets: ${bigOnly.length} (expected ${TARGET_SHARED})`);
}
if (algoOnly.length !== TARGET_SHARED) {
  errors.push(`AlgoSpot exclusive snippets: ${algoOnly.length} (expected ${TARGET_SHARED})`);
}

if (errors.length) {
  console.error("Rest games pool audit FAILED:\n");
  errors.forEach((e) => console.error(`  - ${e}`));
  process.exit(1);
}

console.log("Rest games pool audit OK");
console.log(`  Big O:     ${bigO.daily} daily + ${bigO.free} free = ${bigO.all.length}`);
console.log(`  AlgoSpot:  ${algo.daily} daily + ${algo.free} free = ${algo.all.length}`);
console.log(`  Shared snippets:        ${shared.length}`);
console.log(`  Big O exclusive:        ${bigOnly.length}`);
console.log(`  AlgoSpot exclusive:   ${algoOnly.length}`);
