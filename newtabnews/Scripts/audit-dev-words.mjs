#!/usr/bin/env node
/**
 * Audits DevWordle word lists.
 * Run from repo root: node newtabnews/Scripts/audit-dev-words.mjs
 * Optional: --write strips practiceAnswers from dev_words.json (derived at runtime).
 */
import { readFileSync, writeFileSync } from "fs";
import { dirname, join } from "path";
import { fileURLToPath } from "url";

const __dirname = dirname(fileURLToPath(import.meta.url));
const WORDS_PATH = join(
  __dirname,
  "../newtabnews/Core/Views/RestGames/DevWordle/dev_words.json"
);
const BLOCKLIST_PATH = join(
  __dirname,
  "../newtabnews/Core/Views/RestGames/DevWordle/dev_word_blocklist.json"
);

const WORD_LENGTH = 5;
const MIN_ANSWERS = 150;
const MIN_EXTRAS = 150;
const MIN_PRACTICE = 150;

const blocklist = new Set(JSON.parse(readFileSync(BLOCKLIST_PATH, "utf8")));
const writeMode = process.argv.includes("--write");

function isValidWord(word) {
  return word.length === WORD_LENGTH && /^[A-Z]+$/.test(word);
}

function derivedPractice(answers, extras) {
  const answerSet = new Set(answers);
  return extras.filter((w) => !answerSet.has(w)).sort();
}

function validate(data) {
  const errors = [];
  const answers = data.answers ?? [];
  const extras = data.extraGuesses ?? [];
  const practice = derivedPractice(answers, extras);

  for (const [name, list] of [
    ["answers", answers],
    ["extraGuesses", extras],
  ]) {
    const seen = new Set();
    for (const word of list) {
      if (!isValidWord(word)) {
        errors.push(`${name}: invalid word "${word}" (must be 5 uppercase letters)`);
      }
      if (blocklist.has(word)) {
        errors.push(`${name}: blocklisted "${word}"`);
      }
      if (seen.has(word)) {
        errors.push(`${name}: duplicate "${word}"`);
      }
      seen.add(word);
    }
  }

  const answerSet = new Set(answers);
  const overlap = answers.filter((w) => practice.includes(w));
  if (overlap.length) {
    errors.push(`overlap answers/practice: ${overlap.join(", ")}`);
  }

  if (answers.length < MIN_ANSWERS) {
    errors.push(`answers too small: ${answers.length} < ${MIN_ANSWERS}`);
  }
  if (extras.length < MIN_EXTRAS) {
    errors.push(`extraGuesses too small: ${extras.length} < ${MIN_EXTRAS}`);
  }
  if (practice.length < MIN_PRACTICE) {
    errors.push(`practiceAnswers too small: ${practice.length} < ${MIN_PRACTICE}`);
  }

  return { errors, answers, extras, practice };
}

const raw = JSON.parse(readFileSync(WORDS_PATH, "utf8"));
const { errors, answers, extras, practice } = validate(raw);

if (writeMode) {
  const output = { answers, extraGuesses: extras };
  writeFileSync(WORDS_PATH, JSON.stringify(output, null, 2) + "\n");
  console.log("Wrote dev_words.json without practiceAnswers");
}

if (errors.length) {
  console.error("DevWordle word audit FAILED:\n");
  errors.forEach((e) => console.error(`  - ${e}`));
  process.exit(1);
}

console.log("DevWordle word audit OK");
console.log(`  answers:         ${answers.length}`);
console.log(`  extraGuesses:    ${extras.length}`);
console.log(`  practiceAnswers: ${practice.length} (derived)`);
console.log(`  blocklist:       ${blocklist.size} words`);
