#!/usr/bin/env python3
"""Small matched completion smoke benchmark; no changes to models or editor config."""
import argparse
import ast
import json
import re
import time
import urllib.request
from pathlib import Path

MODEL = "Qwen3.6-35B-A3B-ffn4-attn16"
STOP = ["<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>", "<|fim_pad|>", "<|endoftext|>", "<|im_end|>"]
# Expected text is used only for scoring, never included in the request.
CASES = [
    ("py-add", "python", "def add(a, b):\n    return ", "\n", "a + b"),
    ("py-square", "python", "def square(x):\n    return ", "\n", "x * x"),
    ("py-len", "python", "def count(items):\n    return len(", ")\n", "items"),
    ("py-json", "python", "import json\n\ndef decode(text):\n    return json.", "(text)\n", "loads"),
    ("py-filter", "python", "def positives(numbers):\n    return [n for n in numbers if ", "]\n", "n > 0"),
    ("py-default", "python", "def display_name(user):\n    return user.get(", ")\n", '"name", "Anonymous"'),
    ("lua-insert", "lua", "local items = {}\nlocal function add(value)\n  table.", "(items, value)\nend\n", "insert"),
    ("lua-clamp", "lua", "local function clamp(value, low, high)\n  return math.min(high, math.max(low, ", "))\nend\n", "value"),
    ("lua-concat", "lua", 'local lines = {"one", "two"}\nlocal text = table.', '(lines, "\\n")\n', "concat"),
    ("lua-guard", "lua", "local function size(items)\n  if items == nil then\n    return ", "\n  end\n  return #items\nend\n", "0"),
    ("js-map", "javascript", "const doubled = numbers.map(n => ", ");\n", "n * 2"),
    ("rs-len", "rust", "fn count(items: &[i32]) -> usize {\n    items.", "()\n}\n", "len"),
]

def request(case, variant, stream=False):
    name, lang, prefix, suffix, expected = case
    payload = dict(model=MODEL, max_tokens=32, temperature=0.2, stream=stream)
    if variant == "fim":
        payload.update(prompt=f"<|fim_prefix|>{prefix}<|fim_suffix|>{suffix}<|fim_middle|>", stop=STOP)
        endpoint = "completions"
    else:
        payload.update(messages=[
            {"role": "system", "content": "Complete the code at the cursor. Output only the missing code, without explanation, Markdown, or repeating the prefix or suffix."},
            {"role": "user", "content": f"Language: {lang}\nPREFIX:\n{prefix}\nSUFFIX:\n{suffix}"},
        ], chat_template_kwargs={"enable_thinking": False})
        endpoint = "chat/completions"
    req = urllib.request.Request(f"http://127.0.0.1:42069/v1/{endpoint}", data=json.dumps(payload).encode(), headers={"Content-Type": "application/json"})
    start = time.perf_counter()
    first = None
    raw = ""
    usage = None
    with urllib.request.urlopen(req, timeout=30) as response:
        if stream:
            for line in response:
                if not line.startswith(b"data: ") or line.strip() == b"data: [DONE]":
                    continue
                item = json.loads(line[6:])
                if item.get("usage"):
                    usage = item["usage"]
                choices = item.get("choices", [])
                if not choices:
                    continue
                chunk = choices[0].get("text", "") if variant == "fim" else choices[0].get("delta", {}).get("content", "")
                if chunk and first is None:
                    first = time.perf_counter() - start
                raw += chunk
        else:
            item = json.load(response)
            raw = item["choices"][0]["text"] if variant == "fim" else item["choices"][0]["message"].get("content", "")
            usage = item.get("usage")
    elapsed = time.perf_counter() - start
    # Current plugin erases marker strings, leaving any generated text after them.
    current = re.sub(r"<\|.*?\|>", "", raw)
    # Candidate postprocessing only: terminate at the first protocol boundary.
    bounded = raw
    for stop in STOP:
        bounded = bounded.split(stop, 1)[0]
    scores = {}
    for label, text in (("current", current), ("bounded", bounded)):
        try:
            ast.parse(prefix + text + suffix) if lang == "python" else None
            syntax = True if lang == "python" else None
        except SyntaxError:
            syntax = False
        scores[label] = {"exact": text.strip() == expected, "python_syntax": syntax, "text": text}
    return dict(case=name, language=lang, variant=variant, stream=stream, elapsed_ms=round(elapsed*1000, 2), first_text_ms=round(first*1000, 2) if first is not None else None, raw=raw, usage=usage, scores=scores)

def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--output", type=Path, required=True)
    args = parser.parse_args()
    rows = []
    # Discard warmups from scoring and timing. Requests remain sequential.
    for variant in ("fim", "chat"):
        request(CASES[0], variant)
    args.output.parent.mkdir(parents=True, exist_ok=True)
    with args.output.open("w") as output:
        for repeat in range(2):
            for index, case in enumerate(CASES):
                variants = ("fim", "chat") if (repeat + index) % 2 == 0 else ("chat", "fim")
                for variant in variants:
                    row = request(case, variant, stream=repeat == 1)
                    row["repeat"] = repeat
                    rows.append(row)
                    output.write(json.dumps(row) + "\n")
                    output.flush()
                    print(f"{repeat} {case[0]} {variant}: {row['elapsed_ms']} ms {row['raw']!r}", flush=True)
    print(f"Saved {len(rows)} observations to {args.output}. Use score.py for insertion-aware scoring.")

if __name__ == "__main__":
    main()
