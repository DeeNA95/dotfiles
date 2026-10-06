-- nvim --headless -u NONE -i NONE -l nvim/scripts/qwen_complete/test.lua
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
local qwen = require("qwen_complete")
local pending, checks = {}, 0
local real_mode = vim.api.nvim_get_mode
local function check(value, description)
  assert(value, description)
  checks = checks + 1
end
vim.system = function(command, opts, callback)
  local request = { command = command, opts = opts, callback = callback, killed = 0 }
  request.process = { kill = function() request.killed = request.killed + 1 end }
  pending[#pending + 1] = request
  return request.process
end
qwen.setup({ debounce_ms = 25, stream = false })
vim.api.nvim_get_mode = function() return { mode = "i" } end
local function reset(lines, col)
  qwen.clear()
  vim.bo.buftype = ""
  vim.bo.modifiable = true
  vim.bo.filetype = "lua"
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or { "abc" })
  vim.api.nvim_win_set_cursor(0, { 1, col or 1 })
end
local function request()
  local n = #pending
  qwen.complete(true)
  check(#pending == n + 1, "request starts")
  return pending[#pending]
end
local function respond(req, text, out)
  req.callback(out or { code = 0, stdout = vim.json.encode({ choices = { { text = text, message = { content = text } } } }) })
  vim.wait(10, function() return false end)
end
local function ghost()
  local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("qwen_complete"), 0, -1, { details = true })
  return #marks > 0 and marks[1][4].virt_text[1][1] or nil
end

reset()
local stale = request()
vim.api.nvim_buf_set_lines(0, 0, -1, false, { "xyz" })
respond(stale, "STALE")
check(ghost() == nil, "changedtick rejects edits even without TextChanged events")

reset()
local cancelled = request()
qwen.clear()
respond(cancelled, "STALE")
check(ghost() == nil and cancelled.killed == 1, "cancelled callbacks cannot render")

reset()
local old, new = request(), request()
respond(old, "old")
check(qwen.status().pending, "late old callback preserves new process identity")
qwen.clear()
check(new.killed == 1, "new process still gets cancelled")

reset()
local queued = request()
queued.callback({ code = 0, stdout = vim.json.encode({ choices = { { text = "old" } } }) })
qwen.clear()
vim.wait(10, function() return false end)
check(ghost() == nil, "scheduled callback invalidated before rendering")

reset()
respond(request(), "\n  nextword tail")
check(qwen.accept_word(), "multiline word accepted")
check(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "a", "  nextwordbc" }), "multiline insertion preserves existing suffix")
check(ghost() == " tail", "multiline remainder retained")
vim.api.nvim_exec_autocmds("TextChangedI", {})
vim.api.nvim_exec_autocmds("CursorMovedI", {})
check(ghost() == " tail", "partial acceptance events retain remainder")
check(qwen.accept(), "remaining text accepts")
check(vim.deep_equal(vim.api.nvim_buf_get_lines(0, 0, -1, false), { "a", "  nextword tailbc" }), "remaining text at correct position")

reset()
respond(request(), "café tail")
qwen.accept_word()
check(vim.api.nvim_get_current_line() == "acafébc", "word acceptance preserves UTF-8")
check(ghost() == " tail", "UTF-8 word consumes complete word")

reset()
respond(request(), "NEXT")
vim.api.nvim_win_set_cursor(0, {1, 2})
check(not qwen.accept(), "acceptance rejects moved cursor")
check(vim.api.nvim_get_current_line() == "abc", "no stale insertion")

reset()
respond(request(), "NEXT")
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"xyz"})
check(not qwen.accept(), "acceptance rejects changedtick")

reset()
respond(request(), "a<|fim_prefix|>UNWANTED")
check(ghost() == "a", "protocol boundary truncates output")
check(qwen.clean("len(items)", ")") == "len(items)", "legitimate nested closing bracket preserved")
check(qwen.clean("items\n", ")\n") == "items", "midline trailing newline removed")
check(qwen.clean("\n  code\n", "") == "\n  code\n", "multiline whitespace preserved")
check(qwen.clean("```python\ncode\n```", "") == "", "Markdown wrapper rejected")

reset({string.rep("é", 10000)}, 10000)
local large = request()
local payload = vim.json.decode(large.opts.stdin)
local prefix, suffix = payload.prompt:match("^<|fim_prefix|>(.*)<|fim_suffix|>(.*)<|fim_middle|>$")
check(#prefix <= 2500 and #suffix <= 1000, "prefix and suffix byte budgets enforced")
check(vim.str_utfindex(prefix, "utf-32") == #prefix / 2 and vim.str_utfindex(suffix, "utf-32") == #suffix / 2, "UTF-8 context boundaries valid")
check(large.command[#large.command] == "@-", "stdin transport without temporary file")
check(vim.tbl_contains(large.command, "--max-time") and vim.tbl_contains(large.command, "--fail-with-body"), "timeout and HTTP errors enabled")

reset({string.rep("x", 70000)}, 1)
local before = #pending
qwen.complete(true)
check(#pending == before, "oversized line skipped")

reset()
vim.bo.buftype = "nofile"
before = #pending
qwen.complete(true)
check(#pending == before, "special buffer skipped")
vim.bo.buftype = ""
vim.bo.modifiable = false
qwen.complete(true)
check(#pending == before, "readonly buffer skipped")

reset()
respond(request(), nil, {code=28, stderr="timeout"})
check(qwen.status().error:find("timeout", 1, true) ~= nil and not qwen.status().pending, "transport failure visible")
respond(request(), nil, {code=0, stdout="{not json"})
check(qwen.status().error == "Invalid completion response", "bad JSON visible")
respond(request(), nil, {code=0, stdout='{"choices":42}'})
check(qwen.status().error == "Invalid completion response", "malformed choice rejected")

reset()
vim.api.nvim_exec_autocmds("TextChangedI", {})
qwen.clear()
before = #pending
vim.wait(50, function() return false end)
check(#pending == before, "dismiss stops pending debounce")

-- Test actual expression mapping under real insert-mode textlock.
reset()
respond(request(), "NEXT")
vim.api.nvim_get_mode = real_mode
vim.v.errmsg = ""
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab><Esc>", true, false, true), "xt", false)
check(vim.v.errmsg == "", "Tab mapping has no textlock error")
check(vim.api.nvim_get_current_line() == "aNEXTbc", "Tab inserts suggestion in real insert mode")

-- Exercise Blink's actual mapping layer, including menu/snippet and fallback routing.
vim.opt.rtp:prepend(vim.fn.stdpath("data") .. "/lazy/blink.cmp")
local blink_calls = 0
local visible, snippet = false, false
package.loaded["blink.cmp.config"] = { enabled = function() return true end }
package.loaded["blink.cmp"] = {
  is_visible = function() return visible end,
  snippet_active = function() return snippet end,
  accept = function() blink_calls = blink_calls + 1; return true end,
  select_and_accept = function() blink_calls = blink_calls + 1; return true end,
  snippet_forward = function() return false end,
}
package.loaded["blink.cmp.keymap.fallback"] = { wrap = function() return function() return "\t" end end }
local mappings = dofile("nvim/lua/config/plugins/blink.lua").opts.keymap
require("blink.cmp.keymap.apply").keymap_to_current_buffer({ ["<Tab>"] = mappings["<Tab>"] })
vim.api.nvim_get_mode = function() return { mode = "i" } end
reset()
respond(request(), "BLINK")
vim.api.nvim_get_mode = real_mode
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab><Esc>", true, false, true), "xt", false)
check(vim.api.nvim_get_current_line() == "aBLINKbc" and vim.v.errmsg == "", "Blink mapping accepts Qwen without textlock")
visible = true
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab><Esc>", true, false, true), "xt", false)
check(blink_calls == 1, "Blink popup takes priority")
visible, snippet = false, true
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab><Esc>", true, false, true), "xt", false)
check(blink_calls == 2, "Blink snippet takes priority")
snippet = false
reset()
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab><Esc>", true, false, true), "xt", false)
check(vim.api.nvim_get_current_line():find("\t", 1, true) ~= nil, "Blink fallback produces normal Tab")

-- Toggle state and opt-in chat routing.
qwen.set_enabled(false)
check(not qwen.is_enabled(), "Qwen can be disabled")
qwen.set_enabled(true)
check(qwen.is_enabled(), "Qwen can be reenabled")
check(vim.fn.filereadable("nvim/lua/config/plugins/supermaven.lua") == 0, "Supermaven spec removed")
local lock = vim.json.decode(table.concat(vim.fn.readfile("nvim/lazy-lock.json"), "\n"))
check(lock["supermaven-nvim"] == nil, "Supermaven lock entry removed")
qwen.setup({backend="chat", enabled=false, stream=false})
check(qwen.status().api_url == "http://127.0.0.1:42069/v1/chat/completions", "chat endpoint selected automatically")
qwen.set_enabled(true)
vim.api.nvim_get_mode = function() return {mode="i"} end
reset()
local chat = request()
local chat_payload = vim.json.decode(chat.opts.stdin)
check(chat_payload.chat_template_kwargs.enable_thinking == false and chat_payload.prompt == nil, "chat request disables thinking")
respond(chat, "CHAT")
check(ghost() == "CHAT", "chat message content renders")
vim.api.nvim_get_mode = real_mode

qwen.clear()
print("PASS: " .. checks .. " Qwen checks (buffers, callbacks, UTF-8, real mappings and Blink integration)")
vim.cmd("qa!")
