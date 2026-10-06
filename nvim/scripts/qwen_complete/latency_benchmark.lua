-- Matched local requests measured at Neovim ghost-text rendering, including debounce.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
vim.opt.virtualedit = "onemore"
local qwen = require("qwen_complete")
vim.api.nvim_get_mode = function() return {mode="i"} end
local cases = {
  {name="add", ft="python", lines={"def add(a, b):", "    return "}},
  {name="square", ft="python", lines={"def square(x):", "    return "}},
  {name="count", ft="python", lines={"def count(items):", "    return len("}, suffix=")"},
  {name="concat", ft="lua", lines={'local lines = {"a", "b"}', "local text = table."}, suffix='(lines, "\\n")'},
}
local rows = {}
local function run(case, stream, warmup)
  qwen.setup({stream=stream, debounce_ms=stream and 200 or 250, enabled=false})
  vim.bo.filetype = case.ft
  local lines = vim.deepcopy(case.lines)
  local col = #lines[#lines]
  lines[#lines] = lines[#lines] .. (case.suffix or "")
  vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
  vim.api.nvim_win_set_cursor(0, {#lines, col})
  qwen.set_enabled(true)
  vim.api.nvim_exec_autocmds("TextChangedI", {})
  assert(vim.wait(6500, function()
    local status = qwen.status()
    return status.stats.requests > 0 and not status.pending
  end, 1), "benchmark timeout")
  local status = qwen.status()
  assert(not status.error, status.error)
  local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("qwen_complete"), 0, -1, {details=true})
  local text = ""
  if #marks > 0 then
    local details = marks[1][4]
    local display_lines = {details.virt_text[1][1]}
    for _, virtual in ipairs(details.virt_lines or {}) do display_lines[#display_lines+1] = virtual[1][1] end
    text = table.concat(display_lines, "\n")
  end
  if not warmup then
    rows[#rows+1] = {case=case.name, stream=stream, debounce_ms=status.debounce_ms, first_text_ms=status.stats.last_first_text_ms,
      display_ms=status.stats.last_display_ms, response_ms=status.stats.last_response_ms, text=text, timings=status.timings}
  end
  qwen.clear()
end
run(cases[1], false, true)
run(cases[1], true, true)
for repeat_index = 1, 2 do
  for index, case in ipairs(cases) do
    if (index+repeat_index)%2 == 0 then run(case, false); run(case, true)
    else run(case, true); run(case, false) end
    vim.fn.writefile({vim.json.encode(rows)}, "nvim/scripts/qwen_complete/results/2026-10-06.latency.json")
  end
end
print(vim.json.encode(rows))
vim.cmd("qa!")
