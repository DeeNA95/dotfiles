-- Live local endpoint check; no files are edited. Requires oMLX on :42069.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
vim.opt.virtualedit = "onemore"
local qwen = require("qwen_complete")
qwen.setup()
vim.bo.filetype = "python"
vim.api.nvim_buf_set_lines(0, 0, -1, false, {"def add(a, b):", "    return "})
vim.api.nvim_win_set_cursor(0, {2, 11})
qwen.complete(true)
assert(vim.wait(6500, function() return not qwen.status().pending end, 10), "request did not finish")
assert(not qwen.status().error, qwen.status().error)
local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("qwen_complete"), 0, -1, {details=true})
assert(#marks == 1, "no live suggestion displayed")
local ghost = marks[1][4].virt_text[1][1]
assert(not ghost:find("<|", 1, true), "protocol marker displayed")
vim.api.nvim_feedkeys(vim.api.nvim_replace_termcodes("i<M-l><Esc>", true, false, true), "xt", false)
assert(qwen.status().stats.accepted == 1, "live suggestion was not accepted")
local result = {ghost=ghost, buffer=vim.api.nvim_buf_get_lines(0, 0, -1, false), status=qwen.status()}
local output = vim.json.encode(result)
print(output)
if vim.env.QWEN_SMOKE_OUTPUT then vim.fn.writefile({output}, vim.env.QWEN_SMOKE_OUTPUT) end
vim.cmd("qa!")
