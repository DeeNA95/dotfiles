-- Run from repo root: nvim --headless -u NONE -l nvim/scripts/qwen_complete/reproduce.lua
-- Uses real Neovim buffers/extmarks and a controlled transport to exercise races.
local pending = {}
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
local real_mode = vim.api.nvim_get_mode
vim.system = function(command, opts, callback)
  local request = { callback = callback, killed = 0, command = command, opts = opts }
  request.process = { kill = function() request.killed = request.killed + 1 end }
  pending[#pending + 1] = request
  return request.process
end
require("qwen_complete").setup({ map_tab = true, stream = false })
vim.api.nvim_get_mode = function() return { mode = "i" } end
local ns = vim.api.nvim_create_namespace("qwen_complete")
local results = {}
local function reset(lines, col)
  vim.api.nvim_exec_autocmds("InsertLeave", {})
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines or {"abc"})
  vim.api.nvim_win_set_cursor(0, {1, col or 1})
end
local function request()
  _G.QwenComplete.complete(true)
  return pending[#pending]
end
local function respond(req, text)
  req.callback({code=0, stdout=vim.json.encode({choices={{text=text}}})})
  vim.wait(20, function() return false end)
end
local function ghost()
  local marks = vim.api.nvim_buf_get_extmarks(0, ns, 0, -1, {details=true})
  if #marks == 0 then return nil end
  return marks[1][4].virt_text[1][1]
end
reset()
local a = request()
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"xyz"})
vim.api.nvim_win_set_cursor(0, {1, 1})
vim.api.nvim_exec_autocmds("TextChangedI", {}) -- cancel request before its late reply
respond(a, "STALE")
results.stale_after_edit = ghost() == "STALE"

reset()
local old = request()
local new = request() -- cancels old, starts new
respond(old, "old") -- late old callback clears active_proc for new
vim.api.nvim_exec_autocmds("InsertLeave", {})
results.new_request_not_cancelled_after_old_callback = new.killed == 0

reset()
respond(request(), "\n  nextword tail")
_G.QwenComplete.accept_word()
results.multiline_word_lost = vim.api.nvim_get_current_line() == "abc" and ghost() == nil

reset()
respond(request(), "remaining")
vim.api.nvim_win_set_cursor(0, {1, 2})
results.accept_at_stale_cursor = _G.QwenComplete.accept()

reset()
respond(request(), "NEXT")
vim.api.nvim_get_mode = real_mode
vim.v.errmsg = ""
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<Tab><Esc>", true, false, true), "xt", false)
results.tab_error = vim.v.errmsg
results.tab_buffer = vim.api.nvim_get_current_line()

reset({string.rep("x", 20000)}, 10000)
local large = request()
local payload = vim.json.decode(large.opts.stdin)
results.single_line_prompt_bytes = #payload.prompt

vim.api.nvim_exec_autocmds("InsertLeave", {})
local output = vim.json.encode(results)
print(output)
if vim.env.QWEN_REPRO_OUTPUT then vim.fn.writefile({output}, vim.env.QWEN_REPRO_OUTPUT) end
vim.cmd("qa!")
