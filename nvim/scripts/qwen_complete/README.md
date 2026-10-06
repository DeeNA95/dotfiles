# Qwen completion assessment — 2026-10-03

The plugin was subsequently updated. See [OPTIMIZATIONS.md](OPTIMIZATIONS.md) for the current streaming, reuse, context and debounce changes, and [UPDATE.md](UPDATE.md) for the initial correctness fixes and shortcuts. The findings and recorded results below describe the original implementation.

**Verdict: demonstrable improvements are available with the existing model.** Fix output boundaries and editor correctness first. Thinking-disabled chat is a promising alternative, but the cleanup prototype needs a held-out evaluation before becoming the default. The active completion plugin was inspected without editing it. This directory contains the benchmark, editor reproductions, and recorded evidence.

## Live comparison

Actual endpoint: `127.0.0.1:42069`, model `Qwen3.6-35B-A3B-ffn4-attn16`. The running engine uses DFlash. Both variants use temperature 0.2 and max_tokens 32. We sent 48 sequential measured requests: 12 fixtures × two endpoints × two observations. One observation per fixture was nonstreaming; the second was streaming. Two warmups were discarded. Endpoint order alternated to reduce order effects. Model weights, server settings, and services were not changed.

The fixtures cover Python, Lua, JavaScript, and Rust. One underspecified fixture (`py-default`) is retained as diagnostic evidence but excluded from quality scoring: no context specifies which dictionary key or fallback to choose. That leaves 11 scored fixtures × two observations = 22 results per variant. For Python, inserting the completion must produce the same AST as the reference (both `x * x` and `x ** 2` accepted). Other languages use trimmed expected-text matching; this is not an executable cross-language correctness suite. Raw response `scores.exact` fields are preliminary literal comparisons; `2026-10-03.scored.json` contains the authoritative insertion-aware scoring.

| Variant | Fixture matches | What changed |
| --- | ---: | --- |
| Current FIM output cleanup | 4/22 | Existing behavior: erase special marker strings |
| FIM with boundary truncation | 17/22 | Stop at first marker; exact same recorded responses |
| Thinking-disabled chat, no new cleanup | 17/22 | Same model, explicit completion instruction, `enable_thinking=false` |
| Chat with normalization prototype | 22/22 | Truncate markers, remove terminal newline for midline insertions, remove duplicated punctuation from suffix |

The normalized result is **post hoc**, developed after inspecting this sample. It is evidence that the observed defects are fixable, not evidence of perfect general completion quality. Both observations share fixtures and are not independent problem samples. Short synthetic fixtures cannot establish quality on real repositories or longer prompts. No seed was set, and streaming is confounded with observation order. A held-out workload should randomize stream/nonstream order and repeat timings.

| Timing (12 requests in each group) | FIM mean / p90 | Chat mean / p90 |
| --- | ---: | ---: |
| Nonstream full response | 516 / 765 ms | 314 / 344 ms |
| Stream full response | 665 / 872 ms | 414 / 432 ms |
| Stream first nonempty text | 183 / 195 ms | 268 / 276 ms |

Chat nonstream full response was about 39% faster here, largely because it stopped after the short insertion instead of generating more code. FIM emitted the first streamed text earlier. These measurements exclude Neovim rendering and the plugin's 250 ms debounce. Thus the current nonstream path's indicative wait after a typing pause is about 766 ms mean and 1015 ms p90 on these short fixtures. A streaming FIM prototype could display initial text sooner, but would need to buffer incomplete protocol tokens and discard everything at/after a stop boundary.

## Why the current path fails

The live response to `def add(a, b):\n    return ` with newline suffix was:

```text
a + b<|fim_prefix|>def sub(a, b):
    return <|fim_middle|>a - b
```

The plugin's `text:gsub("<|.-|>", "")` keeps the unrelated function after removing its boundary markers. Truncating at the first marker keeps only `a + b`. Boundary truncation repaired 13 of 22 scored observations without another inference call.

Qwen's published [tokenizer configuration](https://huggingface.co/Qwen/Qwen3.6-35B-A3B/blob/main/tokenizer_config.json) includes the FIM tokens. The installed oMLX source explains the ignored request stops: `server.py` passes `request.stop` to `engine.generate`; `engine/dflash.py` accepts `stop` but its native DFlash event generation only uses tokenizer-derived stop IDs. The supplied string list is forwarded on fallback paths, but not into the native DFlash path. Runtime responses confirm that the requested FIM boundaries are emitted rather than stopping generation. This assessment does not patch oMLX.

## Editor correctness reproduced in Neovim 0.11.6

`reproduce.lua` loads the actual plugin under `-u NONE`. It uses real buffers, mappings and extmarks, with mocked process callbacks to exercise cancellation races without relying on timing luck.

| Finding | Reproduction and source |
| --- | --- |
| Tab acceptance fails | Feeding mapped Tab with visible suggestion raises `E565: Not allowed to change text or change window`. The expression mapping at plugin line 310 calls `nvim_buf_set_text` at line 224 under textlock. Use an expression mapping that returns a deferred command/key sequence, or integrate acceptance through Blink. |
| Cancelled reply can appear after edits | Change `abc` to `xyz`, keep cursor at the same byte position, trigger `TextChangedI` to cancel the request, then deliver its late callback. `STALE` still renders. Lines 183–185 only check cursor/buffer, without request generation or changedtick. |
| Old callback loses cancellation handle for new request | Start A then B, deliver A's callback after B starts, then leave insert mode. B is not killed because line 157 unconditionally clears `active_proc`. Track identity and clear only the matching request. |
| Multiline word acceptance drops suggestion | Suggest `\n  nextword tail`, accept a word, and buffer is unchanged while ghost text disappears. Lines 252–265 clear state before falling back to whole-suggestion acceptance. Use one shared insertion routine for both single/multiline fragments. |
| Acceptance does not revalidate position | Render suggestion, move cursor without delivering a cursor event, call public `accept`: insertion succeeds at the old position. Validate current buffer, changedtick, mode and cursor immediately before editing. |
| Context comments do not describe actual bounds | At byte 10,000 in a 20,000-byte line, prompt is 20,042 bytes, despite comments claiming roughly 2500 prefix and 1000 suffix characters. The code limits line counts only. Enforce byte/token budgets without splitting UTF-8. |

Other source-backed issues: Qwen installs Tab while Blink uses `super-tab` and Supermaven also maps Tab. The effective mapping depends on load order, so acceptance should have one owner. Qwen ignores `buftype`, `modifiable`, popup visibility and large-file budgets. There is no HTTP/connect timeout or status/error feedback; errors are silently dropped. Temporary JSON files are unnecessary: `vim.system` can send JSON through stdin. There is no request/display timing instrumentation, making the header's `~300ms latency` claim unverified.

## Recommended bounded work

1. **Editor correctness and boundaries.** Add request identities plus buffer changedtick; invalidate queued work on cancel/dismiss/leave; validate acceptance; fix Tab textlock and multiline word insertion. Truncate at protocol boundaries rather than erasing tokens. Keep one completion owner for Tab. Verify with event-order reproductions and real insert-mode mappings.
2. **Prompt/transport limits.** Enforce context budgets, skip unsupported buffers, send JSON on stdin, add timeouts and a visible status command. Measure debounce-to-request, first-visible-text, final response, stale rejection and cancellation counts. Compare streaming FIM against nonstream/chat before changing debounce.
3. **Held-out quality evaluation.** Use cursor positions from real Lua, Python, Rust, Go and TypeScript files, including imports, midline insertion, multiline indentation and long contexts. Freeze fixtures before tuning. Compare FIM+boundary handling with chat+thinking disabled and conservative suffix handling, at identical context/output budgets. Count valid reconstructed code, unnecessary suffix duplication, useful completion coverage, and mean/p90 display latency. Adopt the endpoint change only if that held-out comparison supports it.

The minimal first change has strong evidence: output truncation and the editor fixes do not require a new model. The chat prototype's 22/22 result should not be used as a general quality claim.

## Reproduce

From `/Users/dna/dotfiles`:

```sh
nvim --headless -u NONE -l nvim/scripts/qwen_complete/reproduce.lua
python3 nvim/scripts/qwen_complete/benchmark.py --output /tmp/qwen-completion.jsonl
python3 nvim/scripts/qwen_complete/score.py /tmp/qwen-completion.jsonl
```

The benchmark performs local HTTP inference and requires the server to be running. The scorer performs no inference. Files under `results/` preserve the observed responses, timing, scoring and editor reproduction from this assessment.
