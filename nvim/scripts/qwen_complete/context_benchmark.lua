-- Same-file context ablation. Fixtures are frozen before local inference.
vim.opt.rtp:prepend(vim.fn.getcwd() .. "/nvim")
vim.opt.virtualedit = "onemore"
local qwen = require("qwen_complete")
local cases = {
  {name="json-alias", header="from json import loads as decode_json", signature="def parse_json(text):", prefix="    return ", suffix="(text)", expected="decode_json"},
  {name="path-alias", header="from pathlib import Path as FilePath", signature="def read_text(filename):", prefix="    return ", suffix="(filename).read_text()", expected="FilePath"},
  {name="count-multiline", signature="def count(items):", prefix="    return len(", suffix=")", expected="items"},
}
local rows = {}
for _, case in ipairs(cases) do
  for _, enabled in ipairs({false, true}) do
    qwen.setup({context_enabled=enabled})
    vim.bo.filetype = "python"
    local lines = {}
    if case.header then
      lines[1] = case.header
      for _ = 1, 90 do lines[#lines+1] = "# unrelated padding" end
    end
    lines[#lines+1] = case.signature
    lines[#lines+1] = case.prefix .. case.suffix
    vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)
    vim.api.nvim_win_set_cursor(0, {#lines, #case.prefix})
    qwen.complete(true)
    assert(vim.wait(6500, function() return not qwen.status().pending end, 1), "request timeout")
    assert(not qwen.status().error, qwen.status().error)
    local marks = vim.api.nvim_buf_get_extmarks(0, vim.api.nvim_create_namespace("qwen_complete"), 0, -1, {details=true})
    local displayed = {}
    if #marks > 0 then
      local details = marks[1][4]
      displayed[1] = details.virt_text[1][1]
      for _, virtual in ipairs(details.virt_lines or {}) do displayed[#displayed+1] = virtual[1][1] end
    end
    rows[#rows+1] = {case=case.name, context=enabled, text=table.concat(displayed, "\n"), expected=case.expected,
      prefix=case.prefix, suffix=case.suffix, signature=case.signature, header=case.header, status=qwen.status()}
    qwen.clear()
    vim.fn.writefile({vim.json.encode(rows)}, "nvim/scripts/qwen_complete/results/2026-10-06.context.json")
  end
end
print(vim.json.encode(rows))
vim.cmd("qa!")
