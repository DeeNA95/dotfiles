local M = {}

local CELL_MARKER = "^%s*# %%%%"
local NOTEBOOK_FORMAT = "ipynb,py:percent"

local function notify(message, level)
  vim.notify(message, level or vim.log.levels.INFO, { title = "Notebook" })
end

local function current_lines()
  return vim.api.nvim_buf_get_lines(0, 0, -1, false)
end

local function marker_kind(line)
  local normalized = line:lower()
  if normalized:find("[markdown]", 1, true) then
    return "markdown"
  end
  if normalized:find("[raw]", 1, true) then
    return "raw"
  end
  return "code"
end

local function has_source(lines, cell)
  for line_number = cell.start_line, cell.end_line do
    if lines[line_number] and lines[line_number]:find("%S") then
      return true
    end
  end
  return false
end

local function run_command(argv)
  if vim.fn.executable(argv[1]) ~= 1 then
    notify(("%s is unavailable; run nvim/install_deps.sh"):format(argv[1]), vim.log.levels.ERROR)
    return false
  end

  local result = vim.system(argv, { text = true }):wait()
  if result.code == 0 then
    return true
  end

  local detail = vim.trim(result.stderr or result.stdout or "")
  if detail == "" then
    detail = "exit code " .. result.code
  end
  notify(("Jupytext failed: %s"):format(detail), vim.log.levels.ERROR)
  return false
end

local function current_path()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    notify("Save the Python file before pairing or syncing it", vim.log.levels.WARN)
    return nil
  end
  return vim.fn.fnamemodify(path, ":p")
end

local function python_source_path()
  local path = current_path()
  if not path then
    return nil
  end
  if vim.fn.fnamemodify(path, ":e"):lower() ~= "py" then
    notify("Pairing and explicit sync use a .py source file", vim.log.levels.WARN)
    return nil
  end
  return path
end

local function notebook_path(source_path)
  return vim.fn.fnamemodify(source_path, ":r") .. ".ipynb"
end

local function write_source()
  local ok, err = pcall(vim.cmd.update)
  if not ok then
    notify("Could not save the source file: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

local function molten_initialized()
  local ok, kernels = pcall(vim.fn.MoltenRunningKernels, true)
  return ok and type(kernels) == "table" and #kernels > 0
end

local function kernel_ready()
  return molten_initialized() and vim.b.molten_kernel_ready == true
end

local function export_outputs(path)
  if not molten_initialized() then
    return false
  end

  local ok, err = pcall(vim.cmd, "MoltenExportOutput! " .. vim.fn.fnameescape(path))
  if not ok then
    notify("Code synced, but Molten could not export outputs: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.parse_cells(lines)
  local markers = {}
  for line_number, line in ipairs(lines) do
    if line:match(CELL_MARKER) then
      table.insert(markers, { line = line_number, kind = marker_kind(line) })
    end
  end

  if #markers == 0 then
    if #lines == 0 then
      return {}
    end
    return {
      { marker_line = nil, start_line = 1, end_line = #lines, kind = "code" },
    }
  end

  local cells = {}
  for index, marker in ipairs(markers) do
    local next_marker = markers[index + 1]
    table.insert(cells, {
      marker_line = marker.line,
      start_line = marker.line + 1,
      end_line = next_marker and next_marker.line - 1 or #lines,
      kind = marker.kind,
    })
  end
  return cells
end

function M.cell_at(lines, row)
  for _, cell in ipairs(M.parse_cells(lines)) do
    local first_line = cell.marker_line or cell.start_line
    if row >= first_line and row <= cell.end_line then
      return cell
    end
  end
  return nil
end

function M.cell_target(lines, row, direction)
  local markers = {}
  for line_number, line in ipairs(lines) do
    if line:match(CELL_MARKER) then
      table.insert(markers, line_number)
    end
  end

  if direction > 0 then
    for _, line_number in ipairs(markers) do
      if line_number > row then
        return line_number
      end
    end
  else
    for index = #markers, 1, -1 do
      if markers[index] < row then
        return markers[index]
      end
    end
  end
  return nil
end

function M.is_paired(lines)
  for index = 1, math.min(#lines, 120) do
    local normalized = lines[index]:lower()
    if normalized:find("formats:", 1, true) and normalized:find("ipynb", 1, true) then
      return true
    end
  end
  return false
end

function M.run_cell()
  if not molten_initialized() then
    notify("Initialize a kernel with <leader>mi before running a cell", vim.log.levels.WARN)
    return false
  end
  if not kernel_ready() then
    notify("The kernel is still starting; wait for its ready notification", vim.log.levels.WARN)
    return false
  end

  local lines = current_lines()
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local cell = M.cell_at(lines, row)
  if not cell then
    notify("Move to a # %% cell before running code", vim.log.levels.WARN)
    return false
  end
  if cell.kind ~= "code" then
    notify(("The current %s cell is not executable"):format(cell.kind), vim.log.levels.WARN)
    return false
  end
  if cell.start_line > cell.end_line or not has_source(lines, cell) then
    notify("The current code cell is empty", vim.log.levels.WARN)
    return false
  end

  local ok, err = pcall(vim.fn.MoltenEvaluateRange, cell.start_line, cell.end_line)
  if not ok then
    notify("Could not run the cell: " .. tostring(err), vim.log.levels.ERROR)
    return false
  end
  return true
end

function M.goto_cell(direction)
  local row = vim.api.nvim_win_get_cursor(0)[1]
  local target = M.cell_target(current_lines(), row, direction)
  if not target then
    notify(direction > 0 and "Already at the last notebook cell" or "Already at the first notebook cell")
    return false
  end
  vim.api.nvim_win_set_cursor(0, { target, 0 })
  return true
end

function M.run_cell_and_advance()
  if M.run_cell() then
    M.goto_cell(1)
  end
end

function M.run_all()
  if not molten_initialized() then
    notify("Initialize a kernel with <leader>mi before running every cell", vim.log.levels.WARN)
    return false
  end
  if not kernel_ready() then
    notify("The kernel is still starting; wait for its ready notification", vim.log.levels.WARN)
    return false
  end

  local lines = current_lines()
  local count = 0
  for _, cell in ipairs(M.parse_cells(lines)) do
    if cell.kind == "code" and cell.start_line <= cell.end_line and has_source(lines, cell) then
      local ok, err = pcall(vim.fn.MoltenEvaluateRange, cell.start_line, cell.end_line)
      if not ok then
        notify("Stopped while running cells: " .. tostring(err), vim.log.levels.ERROR)
        return false
      end
      count = count + 1
    end
  end

  notify(("Queued %d code cell%s"):format(count, count == 1 and "" or "s"))
  return true
end

function M.pair(force)
  local source = python_source_path()
  if not source or not write_source() then
    return false
  end

  local paired = notebook_path(source)
  if vim.fn.filereadable(paired) == 1 and not M.is_paired(current_lines()) and not force then
    notify(("%s already exists; use :NotebookPair! to pair intentionally"):format(paired), vim.log.levels.WARN)
    return false
  end

  if not run_command({ "jupytext", "--set-formats", NOTEBOOK_FORMAT, "--set-kernel", "python3", source }) then
    return false
  end

  vim.cmd.edit({ bang = true })
  notify(("Paired %s with %s"):format(vim.fn.fnamemodify(source, ":t"), vim.fn.fnamemodify(paired, ":t")))
  return true
end

function M.sync()
  local source = python_source_path()
  if not source or not write_source() then
    return false
  end
  if not M.is_paired(current_lines()) then
    notify("This source is not paired; run :NotebookPair first", vim.log.levels.WARN)
    return false
  end

  local paired = notebook_path(source)
  local argv = { "jupytext", source, "--to", "ipynb", "--output", paired }
  if vim.fn.filereadable(paired) == 1 then
    table.insert(argv, 2, "--update")
  end
  if not run_command(argv) then
    return false
  end

  local outputs_exported = export_outputs(paired)
  notify(outputs_exported and "Synced notebook code; queued Molten output export" or "Synced notebook code")
  return true
end

function M.setup()
  if M.configured then
    return
  end
  M.configured = true

  local group = vim.api.nvim_create_augroup("notebook-molten-state", { clear = true })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = { "MoltenInitPre", "MoltenDeinitPost" },
    callback = function()
      vim.b.molten_kernel_ready = false
    end,
  })
  vim.api.nvim_create_autocmd("User", {
    group = group,
    pattern = "MoltenKernelReady",
    callback = function()
      vim.b.molten_kernel_ready = true
    end,
  })

  local commands = {
    NotebookNextCell = function()
      M.goto_cell(1)
    end,
    NotebookPrevCell = function()
      M.goto_cell(-1)
    end,
    NotebookRunAll = M.run_all,
    NotebookRunCell = M.run_cell,
    NotebookRunCellAndAdvance = M.run_cell_and_advance,
    NotebookSync = M.sync,
  }
  for name, callback in pairs(commands) do
    vim.api.nvim_create_user_command(name, callback, {})
  end
  vim.api.nvim_create_user_command("NotebookPair", function(options)
    M.pair(options.bang)
  end, { bang = true })

  local mappings = {
    {
      "n",
      "]m",
      function()
        M.goto_cell(1)
      end,
      "Next notebook cell",
    },
    {
      "n",
      "[m",
      function()
        M.goto_cell(-1)
      end,
      "Previous notebook cell",
    },
    {
      "n",
      "<leader>mn",
      function()
        M.goto_cell(1)
      end,
      "Next cell",
    },
    {
      "n",
      "<leader>mb",
      function()
        M.goto_cell(-1)
      end,
      "Previous cell",
    },
    { "n", "<leader>mr", M.run_cell, "Run cell" },
    { "n", "<leader>mj", M.run_cell_and_advance, "Run cell and advance" },
    { "n", "<leader>mA", M.run_all, "Run all code cells" },
    { "n", "<leader>ms", M.sync, "Sync paired notebook" },
    { "n", "<leader>mi", "<cmd>MoltenInit<cr>", "Initialize kernel" },
    { "n", "<leader>mk", "<cmd>MoltenInterrupt<cr>", "Interrupt kernel" },
    {
      "n",
      "<leader>mR",
      function()
        vim.b.molten_kernel_ready = false
        vim.cmd("MoltenRestart")
      end,
      "Restart kernel",
    },
    { "n", "<leader>md", "<cmd>MoltenDelete<cr>", "Delete cell output" },
    { "n", "<leader>mo", "<cmd>noautocmd MoltenEnterOutput<cr>", "Open and enter output" },
    { "n", "<leader>mh", "<cmd>MoltenHideOutput<cr>", "Hide output" },
    { "n", "<leader>mB", "<cmd>MoltenOpenInBrowser<cr>", "Open HTML output in browser" },
    { "x", "<leader>mr", ":<C-u>MoltenEvaluateVisual<CR>gv", "Run selection" },
  }
  for _, mapping in ipairs(mappings) do
    vim.keymap.set(mapping[1], mapping[2], mapping[3], { desc = mapping[4], silent = true })
  end
end

return M
