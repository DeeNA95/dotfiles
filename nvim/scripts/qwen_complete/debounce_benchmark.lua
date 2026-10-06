-- Repeatable input traces through the real debounce timer, with transport mocked.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
vim.opt.virtualedit = "onemore"
local qwen = require("qwen_complete")
vim.api.nvim_get_mode = function() return {mode="i"} end
local launches = {}
local origin, last_edit
vim.system = function(_, _, _)
  launches[#launches+1] = vim.uv.hrtime()/1e6 - origin
  return {kill=function() end}
end
local traces = {
  {name="fast", gaps={60, 60, 60, 60, 60}},
  {name="steady", gaps={120, 120, 120, 120, 120}},
  {name="deliberate", gaps={180, 180, 180, 180}},
  {name="pause", gaps={70, 70, 350, 70, 70}},
}
local rows = {}
for _, delay in ipairs({250, 200, 150}) do
  for _, trace in ipairs(traces) do
    launches = {}
    qwen.setup({debounce_ms=delay, stream=false, context_enabled=false, enabled=false})
    vim.api.nvim_buf_set_lines(0, 0, -1, false, {"a"})
    vim.api.nvim_win_set_cursor(0, {1, 1})
    qwen.set_enabled(true)
    origin = vim.uv.hrtime()/1e6
    local offset = 0
    local function edit()
      local col = vim.api.nvim_win_get_cursor(0)[2]
      vim.api.nvim_buf_set_text(0, 0, col, 0, col, {"x"})
      vim.api.nvim_win_set_cursor(0, {1, col+1})
      vim.api.nvim_exec_autocmds("TextChangedI", {})
      vim.api.nvim_exec_autocmds("CursorMovedI", {})
      last_edit = vim.uv.hrtime()/1e6
    end
    edit()
    for _, gap in ipairs(trace.gaps) do
      offset = offset + gap
      vim.wait(gap+20, function() return vim.uv.hrtime()/1e6-origin >= offset end, 1)
      edit()
    end
    vim.wait(delay+30, function() return false end, 1)
    local last_launch = launches[#launches]
    rows[#rows+1] = {debounce_ms=delay, trace=trace.name, requests=#launches, cancelled=qwen.status().stats.cancelled,
      final_wait_ms=math.floor(last_launch - (last_edit-origin))}
    qwen.clear()
  end
end
vim.fn.writefile({vim.json.encode(rows)}, "nvim/scripts/qwen_complete/results/2026-10-06.debounce.json")
print(vim.json.encode(rows))
vim.cmd("qa!")
