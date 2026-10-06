"""Summarize saved latency or context smoke observations without inference."""
import ast
import json
import math
import statistics
import sys
from pathlib import Path


def summarize(rows):
    result = {}
    if "stream" in rows[0]:
        for enabled in (False, True):
            selected = [row for row in rows if row["stream"] == enabled]
            metrics = {}
            for key in ("display_ms", "first_text_ms", "response_ms"):
                values = sorted(row[key] for row in selected if key in row)
                metrics[key] = {"n": len(values), "mean_ms": round(statistics.mean(values), 1),
                                "p90_ms": values[math.ceil(len(values) * 0.9) - 1]}
            result["stream" if enabled else "nonstream"] = metrics
    else:
        for enabled in (False, True):
            selected = [row for row in rows if row["context"] == enabled]
            correct = 0
            for row in selected:
                def parse(text):
                    source = row["signature"] + "\n" + row["prefix"] + text + row["suffix"]
                    return ast.dump(ast.parse(source), include_attributes=False)
                try:
                    correct += bool(row["text"]) and parse(row["text"]) == parse(row["expected"])
                except SyntaxError:
                    pass
            result["enriched" if enabled else "local_only"] = {
                "n": len(selected), "ast_matches": correct,
                "nonempty": sum(bool(row["text"]) for row in selected)}
    return result


for filename in sys.argv[1:]:
    path = Path(filename)
    result = summarize(json.loads(path.read_text()))
    destination = path.with_suffix(".summary.json")
    destination.write_text(json.dumps(result, indent=2) + "\n")
    print(destination, json.dumps(result))
