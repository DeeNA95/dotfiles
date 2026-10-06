# Completion optimizations — 2026-10-06

All four requested optimizations are enabled in the existing local Qwen completion plugin. Restart Neovim to load the updated module. Tab remains routed through Blink; Alt-L accepts the whole suggestion, Alt-W accepts a word, Ctrl-] dismisses it, and `:QwenStatus` shows configuration, errors, counters and rolling timing statistics.

## Implemented behavior

- **Streaming:** SSE text becomes ghost text before curl exits. The decoder buffers split JSON/events, handles CRLF, keepalives, chat deltas and finish events, and bounds event/output bytes. Incomplete protocol tokens are withheld across chunks. The first complete FIM boundary ends generation locally. Errors and incomplete streams withdraw provisional text. Buffer/cursor/request validation still applies to every render and acceptance.
- **Matching-prefix reuse:** Typing exactly the beginning of a visible suggestion consumes that prefix and keeps its remainder. An active stream continues from the updated cursor without another request. UTF-8 and multiline edits are supported. Divergent text, deletion, editing elsewhere, cursor movement, leaving insert mode and popup menus invalidate the suggestion. Fully consuming a completed suggestion starts the next completion after debounce.
- **Bounded file context:** Distant imports and referenced declaration signatures supplement the nearby cursor text. Imports are complete source blocks; signatures are comments. The index examines at most 800 lines/75,000 bytes, with imports from the first 120 lines. Added context is at most 700 bytes and the combined prefix remains at most 2,500 bytes; suffix stays at most 1,000 bytes. Complete multiline imports are kept atomically, and incomplete blocks are omitted. Selection is heuristic and uses only the current buffer.
- **Measured debounce:** The default changed from 250 to 200 ms. `:QwenStatus` reports reused bytes, selected context counts, and count/mean/p90 of context preparation, first visible text, display latency including debounce, and transport completion over the latest 50 requests.

The implementation is in `nvim/lua/qwen_complete.lua`, with SSE and context helpers in `nvim/lua/qwen_complete/`. Lazy options remain in `nvim/lua/config/plugins/qwen-complete.lua`. FIM, the model, and server settings remain as evaluated in the initial update.

## Local latency evidence

`latency_benchmark.lua` loads the actual module in Neovim 0.11.6 and makes local HTTP requests to `Qwen3.6-35B-A3B-ffn4-attn16` at port 42069. Four short Python/Lua fixtures are repeated twice per variant, with variant order interleaved and two warmups discarded. Both variants use the same context/output budgets and temperature 0.2, without a fixed seed. Nonstream uses the previous 250 ms debounce; stream uses 200 ms. First meaningful extmark creation measures ghost-text availability, rather than physical screen painting.

| Metric | Previous nonstream mean / p90 | Streaming mean / p90 |
| --- | ---: | ---: |
| First ghost text, including debounce | 816 / 1,029 ms | 460 / 566 ms |
| First ghost text, after request starts | 569 / 779 ms | 263 / 371 ms |
| Transport completion | 569 / 779 ms | 419 / 449 ms |

There are eight measured observations per variant. Mean first-display latency decreased about 44% in this final warm smoke benchmark. Streaming transport completion includes early client termination at a FIM boundary; it does not measure full generation of the discarded trailing text. The sample is too small and synthetic to establish real-project latency or general completion quality. Multiline ghost text is captured in full in the final raw artifact.

Raw observations: `results/2026-10-06.latency.json`; calculated summary: `results/2026-10-06.latency.summary.json`. A separate live streaming acceptance smoke inserted `a + b` successfully (`results/2026-10-06.streaming-smoke.json`). Its single cold request is not representative of the warmed timings above.

## Debounce and context evidence

`debounce_benchmark.lua` uses real Neovim timers and a mock transport that leaves requests pending against frozen typing traces. This isolates request counts from inference variability. Cancellation counts describe this pending-request scenario, rather than measured cancellations against the live server.

| Trace | Character gaps | Requests at 250 / 200 / 150 ms |
| --- | --- | ---: |
| Fast | 60 ms | 1 / 1 / 1 |
| Steady | 120 ms | 1 / 1 / 1 |
| Deliberate | 180 ms | 1 / 1 / 5 |
| Pause | 70, 70, 350, 70, 70 ms | 2 / 2 / 2 |

At 200 ms, all traces retained the 250 ms request/cancellation counts and reduced the final debounce wait by approximately 50 ms. At 150 ms, deliberate typing caused four additional cancelled requests. These are synthetic traces, not user typing telemetry (`results/2026-10-06.debounce.json`).

Regression checks verify inclusion of distant imports, referenced signatures and complete multiline imports within the byte budget. A separate six-request ablation tested two distant import aliases and one multiline insertion. AST matches were **1/3 with local context and 1/3 with enriched context**. Both variants missed the aliases; enriched context abstained on one case where local context produced an incorrect name. This does not demonstrate a quality gain. The current heuristic improves available context, but a larger frozen repository workload is needed to assess accuracy. Results and AST scoring are preserved in `results/2026-10-06.context.json` and its summary.

## Verification and reproduction

The original 62 checks and 40 new optimization checks pass: **102 total**. They exercise actual buffers, extmarks and mappings with controlled callback order. New cases cover streaming before process exit, every transport split of a UTF-8 SSE packet, boundary cancellation, malformed/incomplete/timeout streams, late frames, matching and divergent edits, multiline reuse, exhausted suggestions, bounded context and Blink menu priority. Actual insert-mode typing followed by Tab consumes the remaining suggestion once. The original defect reproduction reports all bug flags false.

From `/Users/dna/dotfiles`:

```sh
nvim --headless -u NONE -l nvim/scripts/qwen_complete/test.lua
nvim --headless -u NONE -l nvim/scripts/qwen_complete/optimizations_test.lua
nvim --headless -u NONE -l nvim/scripts/qwen_complete/reproduce.lua
nvim --headless -u NONE -l nvim/scripts/qwen_complete/debounce_benchmark.lua
nvim --headless -u NONE -l nvim/scripts/qwen_complete/latency_benchmark.lua
nvim --headless -u NONE -l nvim/scripts/qwen_complete/context_benchmark.lua
python3 nvim/scripts/qwen_complete/summarize.py nvim/scripts/qwen_complete/results/2026-10-06.latency.json nvim/scripts/qwen_complete/results/2026-10-06.context.json
```

Latency/context benchmarks require the existing local server and overwrite their dated output artifacts. Tests and debounce measurements do not perform inference. `summarize.py` calculates nearest-rank p90 and compares reconstructed Python ASTs; it does not perform inference.

For individual ablations, set `stream = false`, `reuse = false`, `context_enabled = false`, or `debounce_ms = 250` in the Lazy plugin's `opts`. Context budget/scan limits are configurable there as well. Keep `map_tab = false` so Blink owns Tab.

The buffer event design follows Neovim's [buffer-update and textlock contracts](https://neovim.io/doc/user/api/#api-buffer-updates); stream callbacks use [vim.system](https://neovim.io/doc/user/lua/#vim.system()). `on_bytes` records the matching insertion and `on_lines` confirms the resulting changedtick. Buffer writes stay in deferred commands or normal main-loop handlers.
