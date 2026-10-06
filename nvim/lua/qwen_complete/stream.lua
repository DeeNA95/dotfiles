-- Incremental SSE decoder. Transport chunks need not align with lines/events.
local M = {}

function M.new(backend, emit)
  local parser = { buffer = "", data = {}, data_bytes = 0, done = false, finished = false }
  local function event()
    if #parser.data == 0 or parser.done then parser.data = {}; return end
    local data = table.concat(parser.data, "\n")
    parser.data = {}
    parser.data_bytes = 0
    if data == "[DONE]" then parser.done = true; return end
    local ok, response = pcall(vim.json.decode, data)
    if not ok or type(response) ~= "table" then parser.error = "Invalid SSE JSON"; return end
    if response.error then parser.error = vim.inspect(response.error); return end
    if response.choices == nil and response.usage then return end
    if type(response.choices) ~= "table" then parser.error = "Invalid SSE choices"; return end
    if #response.choices == 0 then return end -- usage / keepalive
    local choice = response.choices[1]
    if type(choice) ~= "table" then parser.error = "Invalid SSE choice"; return end
    local text = backend == "chat" and type(choice.delta) == "table" and choice.delta.content or choice.text
    if type(text) == "string" and text ~= "" then emit(text) end
    if choice.finish_reason and choice.finish_reason ~= vim.NIL then parser.finished = true end
  end
  function parser:feed(chunk)
    if self.error or self.done then return end
    self.buffer = self.buffer .. chunk
    if #self.buffer > 65536 then self.error = "SSE event exceeds limit"; return end
    while not self.error do
      local at = self.buffer:find("\n", 1, true)
      if not at then break end
      local line = self.buffer:sub(1, at - 1):gsub("\r$", "")
      self.buffer = self.buffer:sub(at + 1)
      if line == "" then event()
      elseif line:sub(1, 5) == "data:" then
        self.data[#self.data + 1] = line:sub(6):gsub("^ ", "")
        self.data_bytes = self.data_bytes + #line
        if self.data_bytes > 65536 then self.error = "SSE event exceeds limit" end
      end
      if self.done then break end
    end
  end
  function parser:finish()
    self:feed("\n\n")
    if not self.done and not self.finished and not self.error then self.error = "Incomplete SSE response" end
  end
  return parser
end

return M
