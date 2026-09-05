package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local notebook = require("config.notebook")
local source_path = vim.fn.tempname() .. ".py"
local paired_path = vim.fn.fnamemodify(source_path, ":r") .. ".ipynb"
local last_notebook = "not read"

local function notebook_has_output()
  local read_ok, document = pcall(function()
    last_notebook = table.concat(vim.fn.readfile(paired_path), "\n")
    return vim.json.decode(last_notebook)
  end)
  if not read_ok or not document.cells then
    return false
  end

  for _, cell in ipairs(document.cells) do
    local source = type(cell.source) == "table" and table.concat(cell.source, "") or cell.source
    if cell.cell_type == "code" and source:find("answer = 40 + 2", 1, true) then
      local encoded_outputs = vim.json.encode(cell.outputs or {})
      return #cell.outputs > 0 and encoded_outputs:find("42", 1, true) ~= nil
    end
  end
  return false
end

local function run()
  vim.env.PATH = "/Users/dna/.local/share/nvim/python3/bin:" .. vim.env.PATH
  notebook.setup()
  vim.fn.writefile({
    "# %%",
    "answer = 40 + 2",
    "answer",
    "",
    "# %% [markdown]",
    "# The answer is produced by the code cell above.",
  }, source_path)

  vim.cmd.edit(vim.fn.fnameescape(source_path))
  assert(notebook.pair(false), "pairing failed")

  local marker
  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line:match("^%s*# %%%%") then
      marker = line_number
      break
    end
  end
  assert(marker, "paired source has no percent cell")
  vim.api.nvim_win_set_cursor(0, { marker + 1, 0 })

  vim.cmd("MoltenInit python3")
  assert(
    vim.wait(5000, function()
      return vim.b.molten_kernel_ready == true
    end, 50),
    "Molten kernel did not initialize"
  )

  assert(notebook.run_cell(), "cell execution failed")
  vim.wait(2500)
  assert(notebook.sync(), "notebook sync failed")
  assert(vim.wait(5000, notebook_has_output, 50), "executed output was not exported to the notebook: " .. last_notebook)

  local source_buffer = vim.api.nvim_get_current_buf()
  vim.cmd.enew()
  vim.api.nvim_buf_delete(source_buffer, { force = true })

  require("jupytext").setup({ style = "percent", output_extension = "auto" })
  vim.cmd.edit(vim.fn.fnameescape(paired_path))
  assert(vim.bo.filetype == "python", "Jupytext did not expose the notebook as Python")

  local code_line
  for line_number, line in ipairs(vim.api.nvim_buf_get_lines(0, 0, -1, false)) do
    if line == "answer = 40 + 2" then
      code_line = line_number
      break
    end
  end
  assert(code_line, "Jupytext did not expose percent-format code")
  vim.api.nvim_buf_set_lines(0, code_line - 1, code_line, false, { "answer = 41 + 1" })
  vim.cmd.write()

  local updated = table.concat(vim.fn.readfile(paired_path), "\n")
  assert(updated:find("answer = 41 + 1", 1, true), "editing the Jupytext buffer did not update the notebook")
end

local ok, err = xpcall(run, debug.traceback)
pcall(vim.cmd, "MoltenDeinit")
pcall(vim.cmd, "silent! %bwipeout!")
vim.fn.delete(source_path)
vim.fn.delete(paired_path)

if not ok then
  error(err)
end

print("notebook_e2e: ok")
