-- Bounded same-file context. Imports and referenced declarations supplement locality.
local M = {}
local cache = {}
function M.drop(bufnr) cache[bufnr] = nil end
local comments = { python = "#", lua = "--", sh = "#", bash = "#", ruby = "#",
  rust = "//", go = "//", javascript = "//", javascriptreact = "//", typescript = "//",
  typescriptreact = "//", c = "//", cpp = "//", cuda = "//", metal = "//", sql = "--" }

function M.tail(text, budget)
  local start = math.max(1, #text - budget + 1)
  while start <= #text and text:byte(start) >= 128 and text:byte(start) < 192 do start = start + 1 end
  return text:sub(start)
end
function M.head(text, budget)
  local last = math.min(#text, budget)
  while last < #text and text:byte(last + 1) >= 128 and text:byte(last + 1) < 192 do last = last - 1 end
  return text:sub(1, last)
end

local function declaration(line)
  return line:match("^%s*async%s+def%s+([%w_]+)") or line:match("^%s*def%s+([%w_]+)")
    or line:match("^%s*class%s+([%w_]+)") or line:match("^%s*local%s+function%s+([%w_%.:]+)")
    or line:match("^%s*function%s+([%w_%.:]+)") or line:match("^%s*pub%s+fn%s+([%w_]+)")
    or line:match("^%s*fn%s+([%w_]+)") or line:match("^%s*func%s+([%w_]+)")
    or line:match("^%s*export%s+function%s+([%w_]+)") or line:match("^%s*interface%s+([%w_]+)")
    or line:match("^%s*type%s+([%w_]+)") or line:match("^%s*struct%s+([%w_]+)")
end

local function index(bufnr, config)
  local tick = vim.api.nvim_buf_get_changedtick(bufnr)
  if cache[bufnr] and cache[bufnr].tick == tick then return cache[bufnr] end
  local result = { tick = tick, imports = {}, declarations = {} }
  local count = math.min(vim.api.nvim_buf_line_count(bufnr), config.context_scan_lines)
  local scanned, continuation = 0, nil
  for row = 0, count - 1 do
    local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
    scanned = scanned + #line + 1
    if scanned > config.context_scan_bytes then break end
    local import = line:match("^%s*import[%s%(]") or line:match("^%s*from%s+[%w_%.]+%s+import%s")
      or line:match("^%s*use%s") or line:match("^%s*#%s*include%s")
      or line:match("require%s*%(") or line:match("^%s*package%s")
    if continuation then
      continuation.text = continuation.text .. "\n" .. line
      continuation.remaining = continuation.remaining - 1
      local closed = continuation.slash and not line:match("\\%s*$") or line:match("^%s*[%)%}]")
      if closed then
        result.imports[#result.imports + 1] = continuation
        continuation = nil
      elseif continuation.remaining == 0 then
        continuation = nil -- Omit incomplete blocks rather than inventing source.
      end
    elseif import and row < config.import_scan_lines then
      if line:match("%(%s*$") or line:match("{%s*$") or line:match("\\%s*$") then
        continuation = {row=row, text=line, remaining=8, slash=line:match("\\%s*$") ~= nil}
      else
        result.imports[#result.imports + 1] = {row=row, text=line}
      end
    end
    local name = declaration(line)
    if name then result.declarations[#result.declarations + 1] = { row = row, name = name, text = line } end
  end
  cache[bufnr] = result
  return result
end

function M.build(bufnr, row, col, config)
  local line = vim.api.nvim_buf_get_lines(bufnr, row, row + 1, false)[1]
  if #line > config.max_line_bytes then return nil end
  local prefix = M.tail(line:sub(1, col), config.prefix_bytes)
  local at = row - 1
  while at >= math.max(0, row - config.prefix_lines) and #prefix < config.prefix_bytes do
    local prev = vim.api.nvim_buf_get_lines(bufnr, at, at + 1, false)[1]
    if #prev > config.max_line_bytes then break end
    prefix = M.tail(prev .. "\n" .. prefix, config.prefix_bytes)
    at = at - 1
  end
  local suffix = M.head(line:sub(col + 1), config.suffix_bytes)
  at = row + 1
  local count = vim.api.nvim_buf_line_count(bufnr)
  while at < math.min(count, row + config.suffix_lines + 1) and #suffix < config.suffix_bytes do
    local next_line = vim.api.nvim_buf_get_lines(bufnr, at, at + 1, false)[1]
    if #next_line > config.max_line_bytes then break end
    suffix = M.head(suffix .. "\n" .. next_line, config.suffix_bytes)
    at = at + 1
  end
  local metadata = { imports = 0, declarations = 0, bytes = 0 }
  local comment = comments[vim.bo[bufnr].filetype]
  if not config.context_enabled or not comment then return prefix, suffix, metadata end
  local indexed = index(bufnr, config)
  local budget = math.min(config.context_bytes, math.floor(config.prefix_bytes * 0.3))
  local heading = comment .. " File context: " .. vim.fn.fnamemodify(vim.api.nvim_buf_get_name(bufnr), ":t") .. "\n"
  local nearby = M.tail(prefix, config.prefix_bytes - budget)
  local refs = {}
  for word in (M.tail(prefix, 1000) .. M.head(suffix, 400)):gmatch("[%a_][%w_]*") do refs[word] = true end
  local pieces, bytes = {}, 0
  local function add(item, category)
    if item.row >= row or nearby:find(item.text, 1, true) then return end
    -- Import blocks stay atomic source; incomplete function signatures are comments.
    local value = (category == "imports" and "" or comment .. " ") .. item.text .. "\n"
    if bytes + #value <= budget - #heading then
      pieces[#pieces + 1] = value
      bytes = bytes + #value
      metadata[category] = metadata[category] + 1
    end
  end
  -- Prefer referenced signatures before unrelated imports consume the budget.
  for _, item in ipairs(indexed.declarations) do
    if refs[item.name] then add(item, "declarations") end
  end
  for _, item in ipairs(indexed.imports) do add(item, "imports") end
  if #pieces > 0 then
    local extra = heading .. table.concat(pieces)
    prefix = extra .. M.tail(prefix, config.prefix_bytes - #extra)
    metadata.bytes = #extra
  end
  return prefix, suffix, metadata
end

return M
