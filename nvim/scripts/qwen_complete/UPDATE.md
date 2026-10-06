# Plugin update — 2026-10-03

This records the initial correctness update. The subsequent [October 6 optimizations](OPTIMIZATIONS.md) enable streaming, matching-prefix reuse, enriched context and a measured 200 ms debounce.

The active plugin now loads `nvim/lua/qwen_complete.lua`. It retains FIM on the existing Qwen/oMLX model and fixes the reproduced editor and boundary defects.

- Completion output terminates at the earliest known protocol marker. Leading indentation and meaningful multiline whitespace are preserved. Terminal newlines are removed for inline insertions before an existing suffix.
- Request identity, invalidation generations, buffer changedtick and cursor validation reject obsolete replies. Cancellation also stops pending debounce callbacks. An old callback cannot clear a newer process handle.
- Whole/word acceptance shares one insertion routine and validates the suggestion immediately before editing. Multiline words and UTF-8 words retain the remaining suggestion.
- Blink owns Tab. Visible Blink menus and snippets take priority; Qwen returns a command sequence that edits after expression-mapping textlock. Normal Tab still works without a suggestion.
- Prefix/suffix are bounded at 2500/1000 bytes and 60/40 preceding/following lines, preserving UTF-8 boundaries. Special, nonmodifiable and oversized-line buffers are skipped, as are visible completion menus.
- Curl receives JSON through stdin, has a one-second connection timeout and five-second request timeout, and treats HTTP errors as failures. `:QwenStatus` exposes errors, model/endpoint, pending state, request/cancellation/stale/display/acceptance counters and the last response/display latency.
- Supermaven was removed at the user's request, including its plugin specification, lock entry, toggle and Qwen integration. Qwen provides inline suggestions; Blink owns completion menus and Tab routing.

## Endpoint decision

Fresh held-out smoke fixtures were frozen before inference, with 24 sequential requests across 12 cases. They were scored using the actual Lua cleanup function. FIM and thinking-disabled chat each matched 8/12 expected completions; full-response mean was 530 ms for FIM and 343 ms for chat. This sample is small and scoring does not establish general quality; it also includes tasks with semantically reasonable alternatives to the exact reference. The old chat cleanup's 22/22 result did not carry over as a demonstrated quality advantage. FIM remains the default.

Blind suffix-punctuation removal was intentionally excluded from the update: `len(items)` inserted before an outer `)` requires both brackets. Automatically removing matching punctuation can break valid nested expressions. This behavior has a regression check. The chat backend is available by setting `backend = "chat"` in the Lazy plugin's `opts`; it selects the chat endpoint automatically and disables thinking, while leaving conservative cleanup in place.

## Verification

`test.lua` passes 62 checks using real Neovim buffers, extmarks and insert-mode mappings with controlled callback order. It covers stale edits, cancellation identity, queued callbacks, multiline and UTF-8 acceptance, context budgets, transport failures, malformed responses, debounce dismissal, actual Blink mapping integration, toggle state, plugin removal and chat payload routing. `reproduce.lua` now exercises the updated module and records all original bug flags as false; the formerly unbounded 20,042-byte prompt is 3542 bytes, including FIM markers.

`smoke.lua` performed a real request to the local endpoint and accepted the ghost text with Alt-l. The resulting buffer was:

```python
def add(a, b):
    return a + b
```

That single live request took 980 ms in the plugin's instrumentation. It is a transport/render/acceptance check, not a latency benchmark. No streaming or debounce speedup is claimed. Results are saved beside the original assessment under `results/`.

Run from `/Users/dna/dotfiles`:

```sh
nvim --headless -u NONE -i NONE -l nvim/scripts/qwen_complete/test.lua
nvim --headless -u NONE -i NONE -l nvim/scripts/qwen_complete/reproduce.lua
nvim --headless -u NONE -i NONE -l nvim/scripts/qwen_complete/smoke.lua
python3 nvim/scripts/qwen_complete/holdout.py
```

The last two commands require oMLX. Restart Neovim to load the updated plugin and provider mappings. Qwen shortcuts remain Tab or Alt-l for full acceptance, Alt-w for a word, Ctrl-] to dismiss, Alt-backslash to request and `<leader>tq` to toggle.
