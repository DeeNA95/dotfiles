#!/usr/bin/env python3
"""Rescore saved outputs without inference; count valid alternatives explicitly."""
import argparse
import ast
import json
import math
import statistics
from pathlib import Path
from benchmark import CASES, STOP

EXPECTED = {case[0]: {case[4]} for case in CASES if case[0] != "py-default"}
EXPECTED["py-square"].add("x ** 2")

def bounded(raw):
    for marker in STOP:
        raw = raw.split(marker, 1)[0]
    return raw

def normalize(raw, suffix):
    text = bounded(raw)
    # Midline completion must not introduce a new line before the existing suffix.
    if suffix and not suffix.startswith("\n"):
        text = text.rstrip("\r\n")
    # Demonstration only: trim duplicated closing punctuation, never identifiers.
    for n in range(min(len(text), len(suffix)), 0, -1):
        overlap = suffix[:n]
        if text.endswith(overlap) and all(char in "()[]{};\r\n" for char in overlap):
            text = text[:-n]
            break
    return text

def describe(values):
    values = sorted(values)
    return {"n": len(values), "mean_ms": round(statistics.mean(values), 2), "p90_ms": values[math.ceil(.9*len(values))-1]}

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("results", type=Path)
    args = parser.parse_args()
    rows = [json.loads(line) for line in args.results.read_text().splitlines()]
    cases = {case[0]: case for case in CASES}
    summary = {}
    for variant, strategy in (("fim", "current"), ("fim", "boundary"), ("chat", "current"), ("chat", "normalized")):
        selected = [row for row in rows if row["variant"] == variant and row["case"] in EXPECTED]
        accepted = []
        for row in selected:
            text = row["scores"]["current"]["text"] if strategy == "current" else bounded(row["raw"]) if strategy == "boundary" else normalize(row["raw"], cases[row["case"]][3])
            case = cases[row["case"]]
            if case[1] == "python":
                try:
                    actual = ast.dump(ast.parse(case[2] + text + case[3]))
                    matches = any(actual == ast.dump(ast.parse(case[2] + expected + case[3])) for expected in EXPECTED[row["case"]])
                except SyntaxError:
                    matches = False
            else:
                matches = text.strip() in EXPECTED[row["case"]]
            if matches:
                accepted.append(f"{row['case']}:{row['repeat']}")
        summary[f"{variant}-{strategy}"] = {"scored": len(selected), "matches": len(accepted), "matching_cases": accepted}
    summary["timing"] = {variant: {
        "nonstream_total": describe([row["elapsed_ms"] for row in rows if row["variant"] == variant and not row["stream"]]),
        "stream_total": describe([row["elapsed_ms"] for row in rows if row["variant"] == variant and row["stream"]]),
        "stream_first_text": describe([row["first_text_ms"] for row in rows if row["variant"] == variant and row["stream"] and row["first_text_ms"] is not None]),
    } for variant in ("fim", "chat")}
    summary["limitations"] = ["12 short smoke fixtures, 2 observations per endpoint, not a repository-scale quality benchmark", "py-default excluded from quality: fixture does not constrain the key/default", "Python reconstructed AST must match reference; other languages use trimmed expected text", "x*x and x**2 accepted for py-square", "streamed and nonstreamed results scored separately for timing", "suffix normalization is post hoc and requires held-out validation before adoption"]
    args.results.with_suffix(".scored.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))

if __name__ == "__main__":
    main()
