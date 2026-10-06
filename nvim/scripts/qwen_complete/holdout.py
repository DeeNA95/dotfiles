#!/usr/bin/env python3
"""Fresh fixtures frozen before requests; score the actual Lua cleanup function."""
import ast
import json
import os
import statistics
import subprocess
from pathlib import Path
from benchmark import request

CASES = [
    ("py-min", "python", "def smaller(a, b):\n    return min(", ")\n", "a, b"),
    ("py-nested-len", "python", "def count_as_string(items):\n    return str(", ")\n", "len(items)"),
    ("py-upper", "python", "def uppercase(text):\n    return text.", "()\n", "upper"),
    ("py-empty", "python", "def is_empty(items):\n    return len(items) == ", "\n", "0"),
    ("py-reverse", "python", "def reverse(items):\n    return items[", "]\n", "::-1"),
    ("py-join", "python", 'def csv(items):\n    return ",".join(', ")\n", "items"),
    ("lua-sort", "lua", "local values = {3, 1, 2}\ntable.", "(values)\n", "sort"),
    ("lua-lower", "lua", "local function lowercase(text)\n  return string.", "(text)\nend\n", "lower"),
    ("js-filter", "javascript", "const positives = numbers.filter(n => ", ");\n", "n > 0"),
    ("js-json", "javascript", "const data = JSON.", "(text);\n", "parse"),
    ("rs-empty", "rust", "fn empty(items: &[u8]) -> bool {\n    items.", "()\n}\n", "is_empty"),
    ("rs-abs", "rust", "fn magnitude(value: i32) -> i32 {\n    value.", "()\n}\n", "abs"),
]
ROOT = Path(__file__).resolve().parents[3]
OUTPUT = Path(__file__).parent / "results" / "2026-10-03.holdout.jsonl"

def main():
    rows = []
    with OUTPUT.open("w") as output:
        for index, case in enumerate(CASES):
            for variant in (("fim", "chat") if index % 2 == 0 else ("chat", "fim")):
                row = request(case, variant)
                row.update(prefix=case[2], suffix=case[3], expected=case[4])
                rows.append(row)
                output.write(json.dumps(row) + "\n")
                output.flush()
                print(f"{case[0]} {variant}: {row['raw']!r}", flush=True)
    # Cleanup code is taken directly from the installed plugin module, not a copy.
    fixture_path = Path("/tmp/qwen-holdout-input.json")
    fixture_path.write_text(json.dumps(rows))
    code = '''vim.opt.rtp:prepend(vim.env.QWEN_REPO .. "/nvim")
local qwen = require("qwen_complete")
local rows = vim.json.decode(table.concat(vim.fn.readfile("/tmp/qwen-holdout-input.json"), "\\n"))
local cleaned = {}
for _, row in ipairs(rows) do cleaned[#cleaned + 1] = qwen.clean(row.raw, row.suffix) end
vim.fn.writefile({vim.json.encode(cleaned)}, "/tmp/qwen-holdout-cleaned.json")
'''
    script_path = Path("/tmp/qwen-holdout-clean.lua")
    script_path.write_text(code)
    subprocess.run(["nvim", "--headless", "-u", "NONE", "-i", "NONE", "-l", str(script_path)], check=True, env={**os.environ, "QWEN_REPO": str(ROOT)})
    cleaned = json.loads(Path("/tmp/qwen-holdout-cleaned.json").read_text())
    for row, text in zip(rows, cleaned):
        row["cleaned"] = text
        if row["language"] == "python":
            try:
                row["match"] = ast.dump(ast.parse(row["prefix"] + text + row["suffix"])) == ast.dump(ast.parse(row["prefix"] + row["expected"] + row["suffix"]))
            except SyntaxError:
                row["match"] = False
        else:
            row["match"] = text.strip() == row["expected"]
    OUTPUT.write_text("".join(json.dumps(row) + "\n" for row in rows))
    summary = {variant: {"matches": sum(row["match"] for row in rows if row["variant"] == variant), "n": len(CASES), "mean_ms": round(statistics.mean(row["elapsed_ms"] for row in rows if row["variant"] == variant), 2)} for variant in ("fim", "chat")}
    OUTPUT.with_suffix(".summary.json").write_text(json.dumps(summary, indent=2) + "\n")
    print(json.dumps(summary, indent=2))

if __name__ == "__main__":
    main()
