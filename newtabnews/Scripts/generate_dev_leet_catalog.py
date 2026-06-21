#!/usr/bin/env python3
"""Generate dev_leet_problems.json from leetcode-problems-master."""

from __future__ import annotations

import json
import os
import re
import sys
from pathlib import Path

DEFAULT_SOURCE = Path.home() / "Downloads" / "leetcode-problems-master" / "merged_problems.json"
DEFAULT_OUTPUT = (
    Path(__file__).resolve().parents[1]
    / "newtabnews"
    / "Core"
    / "Views"
    / "RestGames"
    / "DevLeet"
    / "dev_leet_problems.json"
)


def clean_description(text: str) -> str:
    text = text.replace("\r\n", "\n").replace("\r", "\n")
    text = re.split(r"\nExample 1:", text)[0]
    text = re.split(r"\nConstraints:", text)[0]
    return re.sub(r"\n{3,}", "\n\n", text).strip()


def parse_example(text: str) -> dict | None:
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


def generate(source: Path, output: Path) -> None:
    with source.open(encoding="utf-8") as handle:
        questions = json.load(handle)["questions"]

    problems = []
    for question in questions:
        slug = question.get("problem_slug")
        frontend_id = question.get("frontend_id")
        if not slug or not frontend_id:
            continue

        examples = []
        for example in question.get("examples") or []:
            parsed = parse_example(example.get("example_text", ""))
            if parsed:
                examples.append(parsed)

        problems.append(
            {
                "id": slug,
                "title": question["title"],
                "difficulty": question["difficulty"],
                "leetcodeNumber": int(frontend_id),
                "topics": question.get("topics") or [],
                "description": clean_description(question.get("description", "")),
                "examples": examples,
                "constraints": question.get("constraints") or [],
            }
        )

    problems.sort(key=lambda item: item["leetcodeNumber"])

    output.parent.mkdir(parents=True, exist_ok=True)
    with output.open("w", encoding="utf-8") as handle:
        json.dump({"problems": problems}, handle, ensure_ascii=False, indent=2)

    size_mb = os.path.getsize(output) / 1024 / 1024
    print(f"Wrote {len(problems)} problems to {output} ({size_mb:.2f} MB)")


if __name__ == "__main__":
    source_path = Path(sys.argv[1]) if len(sys.argv) > 1 else DEFAULT_SOURCE
    output_path = Path(sys.argv[2]) if len(sys.argv) > 2 else DEFAULT_OUTPUT

    if not source_path.exists():
        print(f"Source not found: {source_path}", file=sys.stderr)
        sys.exit(1)

    generate(source_path, output_path)
