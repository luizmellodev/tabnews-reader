#!/usr/bin/env python3
"""Generate dev_leet_problems.json from a LeetCode dataset."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

DEV_LEET_DIR = (
    Path(__file__).resolve().parents[1]
    / "newtabnews"
    / "Core"
    / "Views"
    / "RestGames"
    / "DevLeet"
)
DEFAULT_JSONL = Path.home() / "Downloads" / "leetcode-train.jsonl"
DEFAULT_MERGED = Path.home() / "Downloads" / "leetcode-problems-master" / "merged_problems.json"
DEFAULT_OUTPUT = DEV_LEET_DIR / "dev_leet_problems.json"
DEFAULT_OVERRIDES = DEV_LEET_DIR / "dev_leet_description_overrides.json"


def normalize_difficulty(value: object) -> str:
    if value in ("Easy", "Medium", "Hard"):
        return value
    return "Medium"


def strip_markdown(text: str) -> str:
    text = re.sub(r"\*\*(.+?)\*\*", r"\1", text)
    text = re.sub(r"_([^_]+)_", r"\1", text)
    text = re.sub(r"`([^`]+)`", r"\1", text)
    text = text.replace("\\[", "[").replace("\\]", "]")
    return text


def clean_description(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.split(r"\*\*Example 1:\*\*", text)[0]
    text = re.split(r"\nExample 1:", text)[0]
    text = re.split(r"\nConstraints:", text)[0]
    text = re.sub(r"(?m)^Example \d+:\s*$", "", text)
    text = re.sub(r"(?m)^Constraints:\s*$", "", text)
    text = strip_markdown(text)
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def parse_markdown_content(content: str) -> tuple[str, list[dict], list[str]]:
    description = clean_description(content)

    examples: list[dict] = []
    example_blocks = re.split(r"\*\*Example \d+:\*\*", content)[1:]
    for block in example_blocks:
        block = re.split(r"\*\*Constraints:\*\*", block)[0]
        block = re.split(r"\*\*Follow-up:\*\*", block)[0]
        input_match = re.search(r"\*\*Input:\*\*\s*(.+?)(?:\n|$)", block)
        output_match = re.search(r"\*\*Output:\*\*\s*(.+?)(?:\n|$)", block)
        explanation_match = re.search(r"\*\*Explanation:\*\*\s*(.+?)(?:\n\n|\Z)", block, re.S)
        if not input_match or not output_match:
            continue

        explanation = explanation_match.group(1).strip() if explanation_match else None
        if explanation:
            explanation = strip_markdown(explanation.split("\n")[0].strip())

        examples.append(
            {
                "input": strip_markdown(input_match.group(1).strip()),
                "output": strip_markdown(output_match.group(1).strip()),
                "explanation": explanation,
            }
        )

    constraints: list[str] = []
    constraints_match = re.search(
        r"\*\*Constraints:\*\*\s*(.+?)(?:\n\n\*\*Follow-up|\Z)", content, re.S
    )
    if constraints_match:
        for line in constraints_match.group(1).split("\n"):
            line = line.strip()
            if not line.startswith("*"):
                continue
            constraint = strip_markdown(line.lstrip("* ").strip())
            constraint = constraint.rstrip("*").strip()
            if constraint:
                constraints.append(constraint)

    return description, examples, constraints


def parse_plain_example(text: str) -> dict | None:
    text = text.replace("\r\n", "\n").replace("\r", "\n").strip()
    input_match = re.search(r"^Input:\s*(.*)$", text, re.M)
    output_match = re.search(r"^Output:\s*(.*)$", text, re.M)
    explanation_match = re.search(r"^Explanation:\s*(.*)$", text, re.M | re.S)
    if not input_match or not output_match:
        return None

    explanation = explanation_match.group(1).strip() if explanation_match else None
    if explanation:
        explanation = explanation.split("\n")[0].strip()

    return {
        "input": input_match.group(1).strip(),
        "output": output_match.group(1).strip(),
        "explanation": explanation,
    }


def extract_code(raw: str) -> str:
    if not raw:
        return ""
    match = re.search(r"```(?:\w+\n)?(.*?)```", raw, re.S)
    if match:
        return match.group(1).strip()
    return raw.strip()


def parse_solutions(row: dict) -> dict[str, str]:
    solutions: dict[str, str] = {}
    for key, source_key in (
        ("python", "python"),
        ("java", "java"),
        ("javascript", "javascript"),
        ("cpp", "c++"),
    ):
        code = extract_code(row.get(source_key, ""))
        if code:
            solutions[key] = code
    return solutions


def load_overrides(path: Path) -> dict[str, str]:
    if not path.exists():
        return {}
    with path.open(encoding="utf-8") as handle:
        return json.load(handle)


def generate_from_jsonl(source: Path, output: Path, overrides_path: Path) -> None:
    overrides = load_overrides(overrides_path)
    problems = []
    skipped = []

    with source.open(encoding="utf-8") as handle:
        for line in handle:
            row = json.loads(line)
            slug = row.get("slug")
            frontend_id = row.get("id")
            if not slug or frontend_id is None:
                continue

            description, examples, constraints = parse_markdown_content(row.get("content", ""))
            if not description:
                description = overrides.get(slug, "")

            if not description:
                skipped.append(f"{frontend_id} {slug} (no description)")
                continue

            problems.append(
                {
                    "id": slug,
                    "title": row["title"],
                    "difficulty": normalize_difficulty(row["difficulty"]),
                    "leetcodeNumber": int(frontend_id),
                    "topics": [],
                    "description": description,
                    "examples": examples,
                    "constraints": constraints,
                    "solutions": parse_solutions(row),
                }
            )

    problems.sort(key=lambda item: item["leetcodeNumber"])
    write_catalog(output, problems, skipped)


def generate_from_merged(source: Path, output: Path, overrides_path: Path) -> None:
    overrides = load_overrides(overrides_path)
    with source.open(encoding="utf-8") as handle:
        questions = json.load(handle)["questions"]

    problems = []
    skipped = []

    for question in questions:
        slug = question.get("problem_slug")
        frontend_id = question.get("frontend_id")
        if not slug or not frontend_id:
            continue

        examples = []
        for example in question.get("examples") or []:
            parsed = parse_plain_example(example.get("example_text", ""))
            if parsed:
                examples.append(parsed)

        description = clean_description(question.get("description", ""))
        if not description:
            description = overrides.get(slug, "")

        if not description:
            skipped.append(f"{frontend_id} {slug} (no description)")
            continue

        problems.append(
            {
                "id": slug,
                "title": question["title"],
                "difficulty": normalize_difficulty(question["difficulty"]),
                "leetcodeNumber": int(frontend_id),
                "topics": question.get("topics") or [],
                "description": description,
                "examples": examples,
                "constraints": question.get("constraints") or [],
            }
        )

    problems.sort(key=lambda item: item["leetcodeNumber"])
    write_catalog(output, problems, skipped)


def write_catalog(output: Path, problems: list[dict], skipped: list[str]) -> None:
    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        json.dump({"problems": problems}, handle, ensure_ascii=False, indent=2)

    size_mb = os.path.getsize(output) / 1024 / 1024
    print(f"Wrote {len(problems)} problems to {output} ({size_mb:.2f} MB)")
    if skipped:
        print(f"Skipped {len(skipped)} problems without description:")
        for item in skipped[:10]:
            print(f"  - {item}")
        if len(skipped) > 10:
            print(f"  ... and {len(skipped) - 10} more")


def resolve_source(explicit: Path | None) -> Path:
    if explicit:
        return explicit
    if DEFAULT_JSONL.exists():
        return DEFAULT_JSONL
    return DEFAULT_MERGED


def generate(source: Path, output: Path, overrides_path: Path) -> None:
    if source.suffix == ".jsonl":
        print(f"Using JSONL source: {source}")
        generate_from_jsonl(source, output, overrides_path)
        return

    print(f"Using merged JSON source: {source}")
    generate_from_merged(source, output, overrides_path)


if __name__ == "__main__":
    source_path = Path(sys.argv[1]) if len(sys.argv) > 1 else resolve_source(None)
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT
    overrides_path = Path(sys.argv[3]) if len(sys.argv) > 3 else DEFAULT_OVERRIDES

    if not source_path.exists():
        print(f"Source not found: {source_path}", file=sys.stderr)
        sys.exit(1)

    generate(source_path, output_path, overrides_path)
