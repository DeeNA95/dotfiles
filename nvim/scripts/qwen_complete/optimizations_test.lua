-- Regression coverage for streaming, matching edits and bounded context selection.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
vim.opt.virtualedit = "onemore"
local qwen = require("qwen_complete")
local pending, checks = {}, 0
local real_mode = vim.api.nvim_get_mode
local function check(value, description) assert(value, description); checks = checks + 1 end
vim.system = function(command, opts, callback)
  local request = {command=command, opts=opts, callback=callback, killed=0}
  request.process = {kill=function() request.killed=request.killed+1 end}
  pending[#pending+1] = request
  return request.process
end
qwen.setup({debounce_ms=30})
vim.api.nvim_get_mode = function() return {mode="i"} end
local function settle() vim.wait(5, function() return false end) end
local function reset(lines, row, col)
  qwen.clear()
  vim.bo.filetype = "python"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or {"abc"})
  vim.api.nvim_win_set_cursor(0, {row or 1, col or 1})
end
local function request() qwen.complete(true); return pending[#pending] end
local function ghost()
  local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("qwen_complete"), 0, -1, {details=true})
  return #marks > 0 and marks[1][4].virt_text[1][1] or nil
end
local function event(text, backend, finish)
  local choice = backend == "chat" and {delta={content=text}, finish_reason=finish} or {text=text, finish_reason=finish}
  return "data: " .. vim.json.encode({choices={choice}}) .. "\r\n\r\n"
end
local function chunk(req, text) req.opts.stdout(nil, text); settle() end
local function finish(req)
  chunk(req, "data: [DONE]\n\n")
  req.callback({code=0, stderr=""}); settle()
end
local function type_text(text)
  local cursor = vim.api.nvim_win_get_cursor(0)
  local row, col = cursor[1]-1, cursor[2]
  local lines = vim.split(text, "\n", {plain=true})
  vim.api.nvim_buf_set_text(0, row, col, row, col, lines)
  vim.api.nvim_win_set_cursor(0, {row+#lines, #lines==1 and col+#lines[1] or #lines[#lines]})
  vim.api.nvim_exec_autocmds("TextChangedI", {})
  vim.api.nvim_exec_autocmds("CursorMovedI", {})
end

reset()
local early = request()
local packet = event("NEXT")
chunk(early, packet:sub(1, 10))
check(ghost() == nil, "partial SSE JSON not rendered")
chunk(early, packet:sub(11))
check(ghost() == "NEXT" and qwen.status().pending, "ghost appears before process exit")
finish(early)
check(ghost() == "NEXT" and not qwen.status().pending, "stream completes retaining ghost")
check(qwen.status().timings.first_text.count == 1, "first display measured once")

reset()
local menu_request = request()
chunk(menu_request, event("NEXT"))
vim.api.nvim_exec_autocmds("User", {pattern="BlinkCmpMenuOpen"})
check(ghost() == nil and menu_request.killed == 1, "Blink menu opening clears ghost and active stream")
chunk(menu_request, event("LATE"))
check(ghost() == nil, "Blink menu cancellation rejects late frames")
reset()
local reused_menu = request()
chunk(reused_menu, event("NEXT"))
local saved_blink = package.loaded["blink.cmp"]
package.loaded["blink.cmp"] = {is_visible=function() return true end}
type_text("N")
check(ghost() == nil and not qwen.status().pending, "reused suggestion yields to visible Blink menu")
package.loaded["blink.cmp"] = saved_blink

reset()
local boundary = request()
chunk(boundary, event("value<|fim_"))
check(ghost() == "value", "split boundary prefix withheld")
chunk(boundary, event("prefix|>UNWANTED"))
check(ghost() == "value" and boundary.killed == 1, "full boundary stops generation")
boundary.callback({code=143, stderr=""}); settle()
check(not qwen.status().error and ghost() == "value", "boundary abort counts as success")
check(qwen.stream_text("value<|fim_", true) == "value", "truncated final marker withheld")
check(qwen.stream_text("value <", true) == "value <", "ordinary final comparison preserved")
local decoder_module = require("qwen_complete.stream")
local unicode_packet = event("café") .. "data: [DONE]\n\n"
local every_split = true
for cut = 1, #unicode_packet-1 do
  local output = ""
  local parser = decoder_module.new("fim", function(text) output=output..text end)
  parser:feed(unicode_packet:sub(1, cut)); parser:feed(unicode_packet:sub(cut+1)); parser:finish()
  every_split = every_split and output == "café" and parser.done and not parser.error
end
check(every_split, "all transport split positions preserve UTF-8 and SSE frames")
local oversized = decoder_module.new("fim", function() end)
oversized:feed("data: " .. string.rep("x", 65537))
check(oversized.error == "SSE event exceeds limit", "oversized SSE bounded")
check(qwen.stream_text("``", false) == "" and qwen.clean("```python\ncode") == "", "split Markdown wrapper cannot be accepted")

reset()
local reused = request()
chunk(reused, event("café tail"))
local n = #pending
local reused_before = qwen.status().stats.reused_bytes
type_text("café")
check(ghost() == " tail", "typed matching UTF-8 prefix shrinks suggestion")
check(reused.killed == 0 and qwen.status().pending, "matching edit preserves active stream")
chunk(reused, event(" extended"))
check(ghost() == " tail extended", "later stream text follows consumed prefix")
finish(reused)
vim.wait(40, function() return false end)
check(#pending == n, "matching typing launches no additional request")
check(qwen.status().stats.reused_bytes - reused_before == #"café", "reuse bytes measured")
type_text(" different")
check(ghost() == nil, "divergent text invalidates completion")
qwen.clear()

reset()
local multiline = request()
chunk(multiline, event("\n  word tail"))
type_text("\n  word")
check(ghost() == " tail", "matching multiline text updates row/column")
finish(multiline)
check(qwen.accept(), "reused multiline remainder accepts")
check(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), {"a", "  word tailbc"}), "multiline suffix intact")

reset()
local outside = request()
chunk(outside, event("NEXT"))
vim.api.nvim_buf_set_text(0, 0, 0, 0, 0, {"z"})
vim.api.nvim_win_set_cursor(0, {1, 2})
vim.api.nvim_exec_autocmds("TextChangedI", {})
check(ghost() == nil and outside.killed == 1, "edit elsewhere rejects reuse")
qwen.clear()

reset()
local deleted = request()
chunk(deleted, event("NEXT"))
vim.api.nvim_buf_set_text(0, 0, 0, 0, 1, {""})
vim.api.nvim_win_set_cursor(0, {1, 0})
vim.api.nvim_exec_autocmds("TextChangedI", {})
check(ghost() == nil and deleted.killed == 1, "deletion invalidates reuse")
qwen.clear()

reset()
local cancelled = request()
qwen.clear()
chunk(cancelled, event("STALE"))
finish(cancelled)
check(ghost() == nil, "late stream frames cannot resurrect cancelled request")

reset()
local broken = request()
chunk(broken, "data: {bad json}\n\n")
broken.callback({code=0, stderr=""}); settle()
check(qwen.status().error == "Invalid SSE JSON", "malformed SSE visible")
reset()
local incomplete = request()
chunk(incomplete, event("PARTIAL"))
incomplete.callback({code=0, stderr=""}); settle()
check(qwen.status().error == "Incomplete SSE response" and ghost() == nil, "incomplete stream withdrawn")
reset()
local timedout = request()
chunk(timedout, event("PARTIAL"))
timedout.callback({code=28, stderr="timeout"}); settle()
check(qwen.status().error:find("timeout", 1, true) ~= nil and ghost() == nil, "stream timeout clears partial suggestion")

reset()
local exhausted = request()
chunk(exhausted, event("X"))
type_text("X")
finish(exhausted)
local count_before = #pending
vim.wait(45, function() return false end)
check(#pending == count_before+1, "fully typed completion schedules continuation after stream ends")
qwen.clear()

local lines = {"import json", "from pathlib import Path", "", "def helper(value: str) -> str:", "    return value.upper()"}
for _ = 1, 90 do lines[#lines+1] = "# unrelated filler" end
lines[#lines+1] = "def decode(value):"
lines[#lines+1] = "    return helper("
reset(lines, #lines, #lines[#lines])
local selected = request()
local payload = vim.json.decode(selected.opts.stdin)
local prefix = payload.prompt:match("^<|fim_prefix|>(.*)<|fim_suffix|>")
check(prefix:find("import json", 1, true) ~= nil, "distant imports included")
check(prefix:find("def helper(value: str) -> str:", 1, true) ~= nil, "referenced declaration included")
check(prefix:sub(-#lines[#lines]) == lines[#lines], "immediate cursor context retained")
check(#prefix <= 2500 and qwen.status().stats.context.bytes <= 700, "enriched prefix remains within budget")
check(qwen.status().stats.context.imports == 2 and qwen.status().stats.context.declarations == 1, "context selection counted")
qwen.clear()
local block = {"from package import (", "    Alias,", ")"}
for _ = 1, 90 do block[#block+1] = "# unrelated filler" end
block[#block+1] = "def run():"
block[#block+1] = "    return Alias("
reset(block, #block, #block[#block])
local imported = request()
local imported_prefix = vim.json.decode(imported.opts.stdin).prompt
check(imported_prefix:find("from package import (\n    Alias,\n)\n", 1, true) ~= nil, "multiline imports included as complete source blocks")
qwen.clear()

qwen.setup({backend="chat", debounce_ms=30})
reset()
local chat = request()
chunk(chat, ": keepalive\n\n" .. event("CHAT", "chat"))
check(ghost() == "CHAT", "chat deltas and keepalives supported")
finish(chat)
qwen.clear()

-- Actual queued insert-mode typing can precede TextChangedI, so on_bytes is essential.
qwen.setup({debounce_ms=30})
reset()
local typed = request()
chunk(typed, event("NEXT"))
finish(typed)
vim.api.nvim_get_mode = real_mode
vim.v.errmsg = ""
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("iNE<Tab><Esc>", true, false, true), "xt", false)
check(vim.api.nvim_get_current_line() == "aNEXTbc" and vim.v.errmsg == "", "real typing then Tab consumes remainder once")
check(qwen.status().stats.reused_bytes == 2, "real insert-mode typing reused both characters")
print("PASS: " .. checks .. " optimization checks")
vim.cmd("qa!")
