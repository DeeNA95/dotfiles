-- Inline completion through local oMLX. No temporary files or cloud transport.
local M = {}
local contexts = require("qwen_complete.context")
local streams = require("qwen_complete.stream")
local defaults = {
  api_url = "http://127.0.0.1:42069/v1/completions",
  model = "Qwen3.6-35B-A3B-ffn4-attn16",
  backend = "fim",
  max_tokens = 32,
  temperature = 0.2,
  debounce_ms = 200,
  stream = true,
  reuse = true,
  context_enabled = true,
  context_bytes = 700,
  context_scan_lines = 800,
  context_scan_bytes = 75000,
  import_scan_lines = 120,
  max_output_bytes = 8192,
  prefix_bytes = 2500,
  suffix_bytes = 1000,
  prefix_lines = 60,
  suffix_lines = 40,
  max_line_bytes = 65536,
  timeout_s = 5,
  enabled = true,
  map_tab = true,
  denylist_ft = { "TelescopePrompt", "fzf", "help", "qf", "dashboard", "lazy", "mason", "gitcommit" },
}
local stops = { "<|fim_prefix|>", "<|fim_suffix|>", "<|fim_middle|>", "<|fim_pad|>", "<|endoftext|>", "<|im_end|>", "<|im_start|>", "<|repo_name|>", "<|file_sep|>" }
local config, state, ns
local schedule
local function now() return vim.uv.hrtime() / 1e6 end
local function inserting() return vim.api.nvim_get_mode().mode:sub(1, 1) == "i" end

local function timing(name, value)
  local samples = state.timings[name]
  samples[#samples + 1] = math.floor(value)
  if #samples > 50 then table.remove(samples, 1) end
end

-- Hold back incomplete protocol tokens, even when they span separate SSE events.
function M.stream_text(raw, final)
  local last = #raw + 1
  for _, stop in ipairs(stops) do
    local at = raw:find(stop, 1, true)
    if at then last = math.min(last, at) end
  end
  if last <= #raw then return raw:sub(1, last - 1), true end
  do
    local held = 0
    for _, stop in ipairs(stops) do
      for n = 1, math.min(#raw, #stop - 1) do
        if (not final or n >= 2) and raw:sub(-n) == stop:sub(1, n) then held = math.max(held, n) end
      end
    end
    local trimmed = vim.trim(raw)
    for _, wrapper in ipairs({ "```", "<think>", "</think>" }) do
      if not final and #trimmed > 0 and #trimmed < #wrapper and wrapper:sub(1, #trimmed) == trimmed then return "", false end
    end
    return raw:sub(1, #raw - held), false
  end
end

function M.clean(text, suffix)
  if type(text) ~= "string" then return "" end
  text = text:gsub("\r\n", "\n")
  local last = #text + 1
  for _, stop in ipairs(stops) do
    local at = text:find(stop, 1, true)
    if at then last = math.min(last, at) end
  end
  text = text:sub(1, last - 1)
  if text:match("^%s*```") or text:match("^%s*</?think>") then return "" end
  suffix = suffix or ""
  if suffix ~= "" and suffix:sub(1, 1) ~= "\n" then text = text:gsub("[\r\n]+$", "") end
  -- Do not strip matching punctuation blindly: len(items) before an outer ')'
  -- needs both closing brackets. Suffix handling belongs in the model prompt.
  return text
end

local function hide()
  if state.suggestion and vim.api.nvim_buf_is_valid(state.suggestion.bufnr) then
    vim.api.nvim_buf_clear_namespace(state.suggestion.bufnr, ns, 0, -1)
  end
  state.suggestion = nil
end

local function invalidate()
  state.generation = state.generation + 1
  state.timer:stop()
  local request = state.request
  state.request = nil
  if request and request.process then
    state.stats.cancelled = state.stats.cancelled + 1
    pcall(request.process.kill, request.process, 15)
  end
end

function M.clear()
  if not state then return end
  invalidate()
  hide()
end

local function eligible(bufnr, force)
  if not config.enabled or (not force and not inserting()) then return false end
  if vim.bo[bufnr].buftype ~= "" or not vim.bo[bufnr].modifiable then return false end
  if vim.tbl_contains(config.denylist_ft, vim.bo[bufnr].filetype) then return false end
  if vim.fn.pumvisible() == 1 then return false end
  local blink = package.loaded["blink.cmp"]
  if blink and blink.is_visible and blink.is_visible() then return false end
  return true
end

local function matches(snapshot)
  if not snapshot or vim.api.nvim_get_current_buf() ~= snapshot.bufnr or not vim.api.nvim_buf_is_valid(snapshot.bufnr) then return false end
  local cursor = vim.api.nvim_win_get_cursor(0)
  return snapshot.valid ~= false and vim.api.nvim_buf_get_changedtick(snapshot.bufnr) == snapshot.tick
    and cursor[1] == snapshot.row + 1 and cursor[2] == snapshot.col
end

local function render(snapshot, text)
  hide()
  if text == "" then return end
  local lines = vim.split(text, "\n", { plain = true })
  local opts = { virt_text = { { lines[1], "QwenGhostText" } }, virt_text_pos = "inline" }
  if #lines > 1 then
    opts.virt_lines = {}
    for i = 2, #lines do opts.virt_lines[#opts.virt_lines + 1] = { { lines[i], "QwenGhostText" } } end
  end
  local ok, err = pcall(vim.api.nvim_buf_set_extmark, snapshot.bufnr, ns, snapshot.row, snapshot.col, opts)
  if not ok then state.last_error = tostring(err); return false end
  state.suggestion = vim.tbl_extend("force", snapshot, { text = text })
  return true
end

local function attach(bufnr)
  if state.attached[bufnr] then return end
  state.attached[bufnr] = true
  local owner = state
  local function invalid()
    if state.suggestion and state.suggestion.bufnr == bufnr then state.suggestion.valid = false end
    if state.request and state.request.snapshot.bufnr == bufnr then state.request.snapshot.valid = false end
  end
  vim.api.nvim_buf_attach(bufnr, false, {
    on_bytes = function(_, buf, _, row, col, _, _, _, old_bytes, new_rows, new_col, new_bytes)
      if state ~= owner then return true end
      local suggestion = state.suggestion
      if not suggestion or suggestion.bufnr ~= buf then invalid(); return end
      if not config.reuse or not inserting() or suggestion.valid == false or old_bytes ~= 0
        or row ~= suggestion.row or col ~= suggestion.col or new_bytes == 0 or new_bytes > #suggestion.text then
        invalid(); return
      end
      local end_col = new_rows == 0 and col + new_col or new_col
      local inserted = table.concat(vim.api.nvim_buf_get_text(buf, row, col, row + new_rows, end_col, {}), "\n")
      if inserted ~= suggestion.text:sub(1, new_bytes) then invalid(); return end
      suggestion.row, suggestion.col = row + new_rows, end_col
      suggestion.tick = vim.api.nvim_buf_get_changedtick(buf)
      suggestion.text = suggestion.text:sub(new_bytes + 1)
      suggestion.reused = true
      suggestion.reuse_pending = true
      local request = state.request
      if request and request.snapshot.bufnr == buf then
        request.snapshot.row, request.snapshot.col, request.snapshot.tick = suggestion.row, suggestion.col, suggestion.tick
        request.consumed = request.consumed + new_bytes
      end
      state.stats.reused = state.stats.reused + 1
      state.stats.reused_bytes = state.stats.reused_bytes + new_bytes
    end,
    on_lines = function(_, buf, tick)
      if state ~= owner then return true end
      local suggestion = state.suggestion
      -- on_bytes fires before changedtick advances; on_lines confirms the edit.
      if suggestion and suggestion.bufnr == buf and suggestion.valid ~= false and suggestion.reuse_pending then
        suggestion.tick = tick
        suggestion.reuse_pending = nil
        if state.request and state.request.snapshot.bufnr == buf then state.request.snapshot.tick = tick end
      end
    end,
    on_changedtick = function() if state ~= owner then return true end; invalid() end,
    on_reload = function() contexts.drop(bufnr); if state ~= owner then return true end; invalid() end,
    on_detach = function()
      contexts.drop(bufnr)
      if state == owner then invalid(); state.attached[bufnr] = nil end
    end,
  })
end

local function current(request)
  return state.request == request and state.generation == request.generation
end

local function show(request, final)
  if not current(request) or not matches(request.snapshot) or not eligible(request.snapshot.bufnr, request.force) then return end
  local raw, boundary = M.stream_text(request.raw, final)
  local text = M.clean(raw, request.suffix):sub(request.consumed + 1)
  if text == "" then hide() else
    if render(request.snapshot, text) and not request.displayed and vim.trim(text) ~= "" then
      request.displayed = true
      state.stats.shown = state.stats.shown + 1
      state.stats.last_display_ms = math.floor(now() - request.display_started)
      state.stats.last_first_text_ms = math.floor(now() - request.started)
      timing("first_text", now() - request.started)
      timing("display", now() - request.display_started)
    end
  end
  if boundary and not request.boundary then
    request.boundary = true
    if request.process then pcall(request.process.kill, request.process, 15) end
  end
end

local function queue_show(request)
  if request.render_queued then return end
  request.render_queued = true
  vim.schedule(function()
    request.render_queued = false
    if current(request) then show(request, false) end
  end)
end

function M.complete(force, paused_at)
  if not state then return end
  invalidate()
  hide()
  local bufnr = vim.api.nvim_get_current_buf()
  if not eligible(bufnr, force) then return end
  local cursor = vim.api.nvim_win_get_cursor(0)
  local snapshot = { bufnr = bufnr, row = cursor[1] - 1, col = cursor[2], tick = vim.api.nvim_buf_get_changedtick(bufnr) }
  local context_started = now()
  local prefix, suffix, metadata = contexts.build(bufnr, snapshot.row, snapshot.col, config)
  timing("context", now() - context_started)
  if not prefix or vim.trim(prefix) == "" then return end
  attach(bufnr)
  state.stats.context = metadata
  local payload = { model = config.model, max_tokens = config.max_tokens, temperature = config.temperature, stop = stops, stream = config.stream }
  if config.backend == "chat" then
    payload.messages = {
      { role = "system", content = "Complete the code at the cursor. Output only the missing code, without explanation, Markdown, or repeating the prefix or suffix." },
      { role = "user", content = "Language: " .. vim.bo[bufnr].filetype .. "\nPREFIX:\n" .. prefix .. "\nSUFFIX:\n" .. suffix },
    }
    payload.chat_template_kwargs = { enable_thinking = false }
  else
    payload.prompt = "<|fim_prefix|>" .. prefix .. "<|fim_suffix|>" .. suffix .. "<|fim_middle|>"
  end
  local request = { snapshot = snapshot, generation = state.generation, started = now(), raw = "", consumed = 0, suffix = suffix, force = force }
  request.display_started = paused_at or request.started
  state.request = request
  state.stats.requests = state.stats.requests + 1
  state.last_error = nil
  local options = { text = true, stdin = vim.json.encode(payload) }
  if config.stream then
    request.decoder = streams.new(config.backend, function(text)
      if #request.raw + #text > config.max_output_bytes then request.error = "Completion exceeds byte limit"; return end
      request.raw = request.raw .. text
      queue_show(request)
    end)
    options.stdout = function(err, chunk)
      if not current(request) then return end
      if err then request.error = tostring(err) end
      if chunk then request.decoder:feed(chunk) end
    end
  end
  local ok, process = pcall(vim.system, {
    "curl", "--no-buffer", "--silent", "--show-error", "--fail-with-body", "--connect-timeout", "1",
    "--max-time", tostring(config.timeout_s), "-X", "POST", config.api_url,
    "-H", "Content-Type: application/json", "--data-binary", "@-",
  }, options, function(out)
    vim.schedule(function()
      if state.request ~= request or state.generation ~= request.generation then
        state.stats.stale = state.stats.stale + 1
        return
      end
      state.stats.last_response_ms = math.floor(now() - request.started)
      timing("response", now() - request.started)
      if config.stream and out.code == 0 and not request.boundary then request.decoder:finish() end
      local error = request.error or (request.decoder and request.decoder.error)
      if (out.code ~= 0 and not request.boundary) or error then
        local detail = out.stderr and out.stderr ~= "" and out.stderr or out.stdout or "request failed"
        state.last_error = error or "curl " .. tostring(out.code) .. ": " .. vim.trim(detail):sub(1, 240)
        state.stats.errors = state.stats.errors + 1
        state.request = nil
        hide()
        return
      end
      if not config.stream then
        local decoded, response = pcall(vim.json.decode, out.stdout or "")
        local choice = decoded and type(response) == "table" and type(response.choices) == "table" and response.choices[1]
        if type(choice) ~= "table" then
          state.last_error = decoded and type(response) == "table" and response.error and vim.inspect(response.error) or "Invalid completion response"
          state.stats.errors = state.stats.errors + 1
          state.request = nil
          return
        end
        request.raw = config.backend == "chat" and type(choice.message) == "table" and choice.message.content or choice.text
        if type(request.raw) ~= "string" then request.raw = "" end
      end
      if not matches(snapshot) or not eligible(bufnr, force) then
        state.stats.stale = state.stats.stale + 1
        state.request = nil
        hide()
        return
      end
      show(request, true)
      state.request = nil
      if request.consumed > 0 and not state.suggestion then schedule() end
    end)
  end)
  if ok then request.process = process else
    state.request = nil
    state.last_error = tostring(process)
    state.stats.errors = state.stats.errors + 1
  end
end

schedule = function()
  invalidate()
  local bufnr = vim.api.nvim_get_current_buf()
  if not eligible(bufnr, false) then return end
  state.paused_at = now()
  local generation = state.generation
  state.timer:start(config.debounce_ms, 0, function()
    vim.schedule(function()
      if state.generation == generation then M.complete(false, state.paused_at) end
    end)
  end)
end

function M.has_suggestion()
  return state ~= nil and config.enabled and state.suggestion ~= nil and inserting()
    and eligible(vim.api.nvim_get_current_buf(), false) and matches(state.suggestion)
end

local function insert(text, remaining)
  if not M.has_suggestion() then M.clear(); return false end
  local snapshot = state.suggestion
  invalidate()
  hide()
  local lines = vim.split(text, "\n", { plain = true })
  pcall(vim.cmd, "undojoin")
  vim.api.nvim_buf_set_text(snapshot.bufnr, snapshot.row, snapshot.col, snapshot.row, snapshot.col, lines)
  local row = snapshot.row + #lines - 1
  local col = #lines == 1 and snapshot.col + #lines[1] or #lines[#lines]
  vim.api.nvim_win_set_cursor(0, { row + 1, col })
  if remaining and remaining ~= "" then
    render({ bufnr = snapshot.bufnr, row = row, col = col, tick = vim.api.nvim_buf_get_changedtick(snapshot.bufnr) }, remaining)
  end
  state.stats.accepted = state.stats.accepted + 1
  return true
end

function M.accept()
  if not state or not state.suggestion then return false end
  return insert(state.suggestion.text)
end

function M.accept_word()
  if not state or not state.suggestion then return false end
  local text = state.suggestion.text
  local word = text:match("^%s*[%w_\128-\255]+") or text:match("^%s*[^%w%s]+") or text:match("^%s+$")
  if not word or word == "" then word = text end
  return insert(word, text:sub(#word + 1))
end

-- Expression mappings inspect state but defer buffer edits past textlock.
function M.accept_key()
  if M.has_suggestion() then return vim.api.nvim_replace_termcodes("<Cmd>QwenAccept<CR>", true, false, true) end
end

function M.is_enabled() return config ~= nil and config.enabled end

function M.set_enabled(enabled)
  if not state then return end
  config.enabled = enabled
  M.clear()
  if enabled then
    schedule()
  end
end

function M.status()
  if not state then return { enabled = false } end
  local timings = {}
  for name, samples in pairs(state.timings) do
    if #samples > 0 then
      local ordered, total = vim.deepcopy(samples), 0
      table.sort(ordered)
      for _, value in ipairs(samples) do total = total + value end
      timings[name] = { count = #samples, mean_ms = math.floor(total / #samples), p90_ms = ordered[math.ceil(#samples * 0.9)] }
    end
  end
  return { enabled = config.enabled, backend = config.backend, model = config.model, pending = state.request ~= nil,
    error = state.last_error, stats = vim.deepcopy(state.stats), api_url = config.api_url, stream = config.stream,
    reuse = config.reuse, debounce_ms = config.debounce_ms, timings = timings }
end

function M.setup(opts)
  if state then M.clear(); state.timer:close() end
  config = vim.tbl_deep_extend("force", vim.deepcopy(defaults), opts or {})
  assert(config.backend == "fim" or config.backend == "chat", "Qwen backend must be fim or chat")
  if config.backend == "chat" and not (opts and opts.api_url) then
    config.api_url = defaults.api_url:gsub("/completions$", "/chat/completions")
  end
  ns = vim.api.nvim_create_namespace("qwen_complete")
  vim.api.nvim_set_hl(0, "QwenGhostText", { fg = "#8a8a8a", italic = true, default = true })
  state = { generation = 0, timer = vim.uv.new_timer(), attached = {},
    timings = { response = {}, first_text = {}, display = {}, context = {} },
    stats = { requests = 0, cancelled = 0, stale = 0, errors = 0, shown = 0, accepted = 0, reused = 0, reused_bytes = 0 } }
  local group = vim.api.nvim_create_augroup("QwenCompleteGroup", { clear = true })
  vim.api.nvim_create_autocmd({ "TextChangedI", "TextChangedP", "CursorMovedI" }, { group = group, callback = function()
    if not eligible(vim.api.nvim_get_current_buf(), false) then M.clear(); return end
    if state.suggestion and matches(state.suggestion) then
      local suggestion = state.suggestion
      if suggestion.reused then render(suggestion, suggestion.text) end
      if state.suggestion or state.request then return end
    end
    hide()
    schedule()
  end })
  vim.api.nvim_create_autocmd("InsertEnter", { group = group, callback = schedule })
  vim.api.nvim_create_autocmd({ "InsertLeave", "BufLeave", "BufDelete", "CompleteChanged" }, { group = group, callback = M.clear })
  vim.api.nvim_create_autocmd("User", { group = group, pattern = "BlinkCmpMenuOpen", callback = M.clear })
  vim.api.nvim_create_autocmd("VimLeavePre", { group = group, callback = function() M.clear(); state.timer:close() end })
  vim.keymap.set("i", "<M-l>", M.accept, { desc = "Accept Qwen suggestion" })
  vim.keymap.set("i", "<M-w>", M.accept_word, { desc = "Accept Qwen next word" })
  vim.keymap.set("i", "<C-]>", M.clear, { desc = "Dismiss Qwen suggestion" })
  vim.keymap.set("i", "<M-\\>", M.complete, { desc = "Trigger Qwen suggestion" })
  if config.map_tab then
    vim.keymap.set("i", "<Tab>", function() return M.accept_key() or "\t" end, { expr = true, replace_keycodes = false, desc = "Accept Qwen suggestion or Tab" })
  end
  vim.api.nvim_create_user_command("QwenAccept", M.accept, { force = true })
  vim.api.nvim_create_user_command("QwenComplete", function() M.complete(true) end, { force = true })
  vim.api.nvim_create_user_command("QwenToggle", function()
    M.set_enabled(not config.enabled)
    vim.notify("Qwen completion: " .. (config.enabled and "enabled" or "disabled"))
  end, { force = true })
  vim.api.nvim_create_user_command("QwenStatus", function() vim.notify(vim.inspect(M.status())) end, { force = true })
  vim.keymap.set("n", "<leader>tq", "<cmd>QwenToggle<cr>", { desc = "Toggle Qwen autocomplete" })
  _G.QwenComplete = M
  M.set_enabled(config.enabled)
end

return M
