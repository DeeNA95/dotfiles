package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local notebook = require("config.notebook")

local function assert_equal(actual, expected, label)
  assert(
    vim.deep_equal(actual, expected),
    ("%s: expected %s, got %s"):format(label, vim.inspect(expected), vim.inspect(actual))
  )
end

local lines = {
  "# ---",
  "# jupytext metadata",
  "# %%",
  "answer = 40 + 2",
  "answer",
  "# %% [markdown]",
  "# A result",
  "# %% [raw]",
  "# raw content",
  "# %%",
  "print(answer)",
}

local cells = notebook.parse_cells(lines)
assert_equal(#cells, 4, "cell count")
assert_equal(cells[1].start_line, 4, "first code start")
assert_equal(cells[1].end_line, 5, "first code end")
assert_equal(cells[2].kind, "markdown", "markdown kind")
assert_equal(cells[3].kind, "raw", "raw kind")
assert_equal(cells[4].end_line, 11, "last code end")

assert_equal(notebook.cell_at(lines, 4), cells[1], "cell at code")
assert_equal(notebook.cell_at(lines, 2), nil, "metadata is not a cell")
assert_equal(notebook.cell_target(lines, 4, 1), 6, "next cell")
assert_equal(notebook.cell_target(lines, 7, -1), 6, "previous cell")
assert_equal(notebook.cell_target(lines, 3, -1), nil, "no previous cell")

local plain = notebook.parse_cells({ "value = 42", "print(value)" })
assert_equal(#plain, 1, "plain Python cell count")
assert_equal(plain[1].start_line, 1, "plain Python start")
assert_equal(plain[1].end_line, 2, "plain Python end")

assert(notebook.is_paired({ "#     formats: ipynb,py:percent" }), "paired metadata should be detected")
assert(not notebook.is_paired({ "# ordinary python" }), "ordinary Python should not be paired")

notebook.setup()
for _, command in ipairs({
  "NotebookNextCell",
  "NotebookPair",
  "NotebookPrevCell",
  "NotebookRunAll",
  "NotebookRunCell",
  "NotebookRunCellAndAdvance",
  "NotebookSync",
}) do
  assert_equal(vim.fn.exists(":" .. command), 2, command .. " registration")
end

vim.cmd([[
  function! MoltenRunningKernels(...) abort
    return ['python3']
  endfunction
  function! MoltenEvaluateRange(...) abort
    call add(g:notebook_ranges, a:000)
  endfunction
]])
vim.g.notebook_ranges = {}
vim.b.molten_kernel_ready = true
vim.api.nvim_buf_set_lines(0, 0, -1, false, lines)

vim.api.nvim_win_set_cursor(0, { 7, 0 })
assert(not notebook.run_cell(), "markdown cells must not execute")
assert_equal(#vim.g.notebook_ranges, 0, "markdown execution count")

vim.api.nvim_win_set_cursor(0, { 4, 0 })
assert(notebook.run_cell(), "code cell should execute")
assert_equal(vim.g.notebook_ranges, { { 4, 5 } }, "current code range")

vim.g.notebook_ranges = {}
assert(notebook.run_all(), "all code cells should execute")
assert_equal(vim.g.notebook_ranges, { { 4, 5 }, { 11, 11 } }, "all code ranges")

print("notebook_spec: ok")
