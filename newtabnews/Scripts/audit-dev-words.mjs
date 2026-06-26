#!/usr/bin/env node
/**
 * Audits DevWordle word lists.
 * Run from repo root: node newtabnews/Scripts/audit-dev-words.mjs
 *
 * Lists:
 *   answers         — daily targets (programming only)
 *   practiceAnswers — free mode targets (programming only, disjoint from answers)
 *   extraGuesses    — valid guesses (dev + non-dev; blocklist not applied)
 */
import { readFileSync } from "fs";
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

function isValidWord(word) {
  return word.length === WORD_LENGTH && /^[A-Z]+$/.test(word);
}

function validateList(name, list, { applyBlocklist }) {
  const errors = [];
  const seen = new Set();
  for (const word of list) {
    if (!isValidWord(word)) {
      errors.push(`${name}: invalid word "${word}" (must be 5 uppercase letters)`);
    }
    if (applyBlocklist && blocklist.has(word)) {
      errors.push(`${name}: blocklisted "${word}"`);
    }
    if (seen.has(word)) {
      errors.push(`${name}: duplicate "${word}"`);
    }
    seen.add(word);
  }
  return errors;
}

function validate(data) {
  const errors = [];
  const answers = data.answers ?? [];
  const extras = data.extraGuesses ?? [];
  const practice = data.practiceAnswers ?? [];

  errors.push(...validateList("answers", answers, { applyBlocklist: true }));
  errors.push(...validateList("practiceAnswers", practice, { applyBlocklist: true }));
  errors.push(...validateList("extraGuesses", extras, { applyBlocklist: false }));

  const answerSet = new Set(answers);
  const overlap = practice.filter((w) => answerSet.has(w));
  if (overlap.length) {
    errors.push(`overlap answers/practice: ${overlap.join(", ")}`);
  }

  if (!data.practiceAnswers) {
    errors.push("practiceAnswers is required in dev_words.json");
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

const data = JSON.parse(readFileSync(WORDS_PATH, "utf8"));
const { errors, answers, extras, practice } = validate(data);

if (errors.length) {
  console.error("DevWordle word audit FAILED:\n");
  errors.forEach((e) => console.error(`  - ${e}`));
  process.exit(1);
}

console.log("DevWordle word audit OK");
console.log(`  answers:         ${answers.length} (daily, programming)`);
console.log(`  practiceAnswers: ${practice.length} (free, programming)`);
console.log(`  extraGuesses:    ${extras.length} (valid guesses, any theme)`);
console.log(`  blocklist:       ${blocklist.size} words (answers + free only)`);
