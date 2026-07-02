return {
  {
    "nvim-treesitter/nvim-treesitter",
    optional = true,
    keys = {
      { "<leader>ce", "<cmd>ExplainCode<CR>", desc = "Explain Code snippet", mode = "n" },
      { "<leader>ce", ":<C-u>'<,'>ExplainCode<CR>", desc = "Explain Code snippet", mode = "v" },
      { "<leader>cr", "<cmd>RefactorCode<CR>", desc = "Refactor Code snippet", mode = "n" },
      { "<leader>cr", ":<C-u>'<,'>RefactorCode<CR>", desc = "Refactor Code snippet", mode = "v" },
    },
    init = function()
      local daemon_obj = nil
      local script_dir = vim.fn.stdpath("config") .. "/scripts/antigravity_explain"

      local function ensure_daemon()
        local health_cmd = { "curl", "-s", "-f", "http://127.0.0.1:8593/health" }
        local out = vim.system(health_cmd):wait()
        if out.code ~= 0 then
          print("Pennyworth: Starting background daemon...")
          daemon_obj = vim.system({ "zsh", "-c", string.format("source ~/.zshrc >/dev/null 2>&1 && cd %s && uv run daemon.py", script_dir) }, { detach = true })
          -- Poll until the daemon is ready
          local max_retries = 30
          for i = 1, max_retries do
            vim.cmd("sleep 100m")
            if vim.system(health_cmd):wait().code == 0 then
              break
            end
          end
        end
      end

      local function get_framework_context()
        local cwd = vim.fn.getcwd()
        local context = ""
        if vim.fn.filereadable(cwd .. "/package.json") == 1 then
          context = context .. "Node.js/JS Workspace. "
        end
        if vim.fn.filereadable(cwd .. "/pyproject.toml") == 1 or vim.fn.filereadable(cwd .. "/requirements.txt") == 1 then
          context = context .. "Python Workspace. "
        end
        if vim.fn.filereadable(cwd .. "/Cargo.toml") == 1 then
          context = context .. "Rust Workspace. "
        end
        if vim.fn.filereadable(cwd .. "/go.mod") == 1 then
          context = context .. "Go Workspace. "
        end
        return context
      end

      local function do_ai_action(cmd_opts, ai_mode)
        ensure_daemon()
        
        local bufnr = vim.api.nvim_get_current_buf()
        local filetype = vim.bo[bufnr].filetype
        local lines = {}
        
        local start_row, end_row
        if cmd_opts.range == 2 then
          start_row = cmd_opts.line1 - 1
          end_row = cmd_opts.line2 - 1
          lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
        else
          local ok, ts_utils = pcall(require, "nvim-treesitter.ts_utils")
          if ok then
            local node = ts_utils.get_node_at_cursor()
            if node then
              local current = node
              while current do
                local type = current:type()
                if type:find("function") or type:find("declaration") or type:find("method") then
                  node = current
                  break
                end
                local parent = current:parent()
                if not parent then break end
                current = parent
              end
              start_row, _, end_row, _ = node:range()
              lines = vim.api.nvim_buf_get_lines(bufnr, start_row, end_row + 1, false)
            end
          end
        end
        
        if #lines == 0 or not start_row or not end_row then
          print("No code selected or treesitter node found")
          return
        end
        
        local diagnostics = vim.diagnostic.get(bufnr)
        local relevant_diags = {}
        for _, d in ipairs(diagnostics) do
          if d.lnum >= start_row and d.lnum <= end_row then
            local severity = d.severity == vim.diagnostic.severity.ERROR and "Error" or (d.severity == vim.diagnostic.severity.WARN and "Warning" or "Info")
            table.insert(relevant_diags, string.format("Line %d [%s]: %s", d.lnum + 1, severity, d.message))
          end
        end
        local diags_str = table.concat(relevant_diags, "\n")
        if diags_str == "" then diags_str = "No LSP errors/warnings." end
        
        local code_snippet = table.concat(lines, "\n")
        local full_file_lines = vim.api.nvim_buf_get_lines(bufnr, 0, -1, false)
        local full_file_context = table.concat(full_file_lines, "\n")
        local framework_context = get_framework_context()
        
        local payload = {
          filetype = filetype,
          code_snippet = code_snippet,
          full_file_context = full_file_context,
          framework_context = framework_context,
          diagnostics = diags_str,
        }
        
        local json_payload = vim.fn.json_encode(payload)
        local tmp_payload_file = vim.fn.tempname()
        vim.fn.writefile({json_payload}, tmp_payload_file)
        
        local cmd = { "curl", "-sS", "-N", "-X", "POST", "http://127.0.0.1:8593/" .. ai_mode, "-H", "Content-Type: application/json", "-d", "@" .. tmp_payload_file }
        
        if ai_mode == "explain" then
          local width = math.floor(vim.o.columns * 0.8)
          local height = math.floor(vim.o.lines * 0.8)
          local col = math.floor((vim.o.columns - width) / 2)
          local row = math.floor((vim.o.lines - height) / 2)
          
          local float_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_buf_set_option(float_buf, "filetype", "markdown")
          
          local win = vim.api.nvim_open_win(float_buf, true, {
            relative = "editor", width = width, height = height, col = col, row = row,
            style = "minimal", border = "rounded", title = " Pennyworth ", title_pos = "center",
          })
          
          vim.api.nvim_set_option_value("conceallevel", 3, { win = win })
          vim.api.nvim_set_option_value("concealcursor", "n", { win = win })
          vim.api.nvim_set_option_value("wrap", true, { win = win })
          vim.api.nvim_set_option_value("linebreak", true, { win = win })
          vim.api.nvim_set_option_value("spell", false, { win = win })
          
          vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, {"Pennyworth is thinking..."})
          vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = float_buf, silent = true })
          
          local function append_data(data)
            if not data or data == "" then return end
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(float_buf) then return end
              vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
              local b_lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
              
              if #b_lines == 1 and b_lines[1] == "Pennyworth is thinking..." then
                vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, {""})
              end
              
              local b_row = vim.api.nvim_buf_line_count(float_buf) - 1
              local last_line = vim.api.nvim_buf_get_lines(float_buf, b_row, b_row + 1, false)[1]
              local b_col = #last_line
              
              local new_lines = vim.split(data, '\n', { plain = true })
              vim.api.nvim_buf_set_text(float_buf, b_row, b_col, b_row, b_col, new_lines)
              vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
            end)
          end

          vim.keymap.set("n", "<CR>", function()
            local question = vim.fn.input("Pennyworth: ")
            if not question or question == "" then return end
            
            vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
            local b_lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
            table.insert(b_lines, "")
            table.insert(b_lines, "---")
            table.insert(b_lines, "### You:")
            table.insert(b_lines, question)
            table.insert(b_lines, "")
            table.insert(b_lines, "Pennyworth is thinking...")
            vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, b_lines)
            vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
            
            local history_lines = vim.list_slice(b_lines, 1, #b_lines - 1)
            
            local chat_payload = {
              filetype = filetype,
              code_snippet = code_snippet,
              full_file_context = full_file_context,
              framework_context = framework_context,
              diagnostics = diags_str,
              chat_history = table.concat(history_lines, "\n")
            }
            local chat_json = vim.fn.json_encode(chat_payload)
            local chat_tmp = vim.fn.tempname()
            vim.fn.writefile({chat_json}, chat_tmp)
            
            local chat_cmd = { "curl", "-sS", "-N", "-X", "POST", "http://127.0.0.1:8593/chat", "-H", "Content-Type: application/json", "-d", "@" .. chat_tmp }
            
            vim.system(chat_cmd, { text = true, stdout = function(err, data) append_data(data) end }, function(out)
              vim.schedule(function()
                if not vim.api.nvim_buf_is_valid(float_buf) then return end
                if out.code ~= 0 and out.stderr and out.stderr ~= "" then
                  vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
                  local curr_lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
                  table.insert(curr_lines, "")
                  table.insert(curr_lines, "### Process Error Logs")
                  for s in out.stderr:gmatch("[^\r\n]+") do table.insert(curr_lines, s) end
                  vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, curr_lines)
                  vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
                end
              end)
            end)
          end, { buffer = float_buf, silent = true })
          
          vim.system(cmd, { text = true, stdout = function(err, data) append_data(data) end }, function(out)
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(float_buf) then return end
              if out.code ~= 0 and out.stderr and out.stderr ~= "" then
                vim.api.nvim_buf_set_option(float_buf, "modifiable", true)
                local b_lines = vim.api.nvim_buf_get_lines(float_buf, 0, -1, false)
                table.insert(b_lines, "")
                table.insert(b_lines, "### Process Error Logs")
                for s in out.stderr:gmatch("[^\r\n]+") do table.insert(b_lines, s) end
                vim.api.nvim_buf_set_lines(float_buf, 0, -1, false, b_lines)
                vim.api.nvim_buf_set_option(float_buf, "modifiable", false)
              end
            end)
          end)
        else
          vim.cmd("vsplit")
          local scratch_buf = vim.api.nvim_create_buf(false, true)
          vim.api.nvim_win_set_buf(0, scratch_buf)
          vim.api.nvim_buf_set_option(scratch_buf, "filetype", filetype)
          vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, {
             "-- Pennyworth Refactoring",
             "-- Press <CR> to accept and replace, q to cancel",
             "-- =============================================",
             ""
          })
          vim.keymap.set("n", "q", "<cmd>close<CR>", { buffer = scratch_buf, silent = true })
          vim.keymap.set("n", "<CR>", function()
             local fixed_lines = vim.api.nvim_buf_get_lines(scratch_buf, 4, -1, false)
             while #fixed_lines > 0 and fixed_lines[#fixed_lines] == "" do table.remove(fixed_lines) end
             vim.api.nvim_buf_set_lines(bufnr, start_row, end_row + 1, false, fixed_lines)
             vim.cmd("close")
             print("Pennyworth: Refactoring applied.")
          end, { buffer = scratch_buf, silent = true })
          
          local function append_refactor_data(data)
            if not data or data == "" then return end
            vim.schedule(function()
              if not vim.api.nvim_buf_is_valid(scratch_buf) then return end
              local b_row = vim.api.nvim_buf_line_count(scratch_buf) - 1
              local last_line = vim.api.nvim_buf_get_lines(scratch_buf, b_row, b_row + 1, false)[1]
              local b_col = #last_line
              local new_lines = vim.split(data, '\n', { plain = true })
              vim.api.nvim_buf_set_text(scratch_buf, b_row, b_col, b_row, b_col, new_lines)
            end)
          end
          
          vim.system(cmd, { text = true, stdout = function(err, data) append_refactor_data(data) end }, function(out)
             if out.code ~= 0 and out.stderr and out.stderr ~= "" then
                vim.schedule(function()
                   if vim.api.nvim_buf_is_valid(scratch_buf) then
                      local b_lines = vim.api.nvim_buf_get_lines(scratch_buf, 0, -1, false)
                      table.insert(b_lines, "-- Error Logs:")
                      for s in out.stderr:gmatch("[^\r\n]+") do table.insert(b_lines, "-- " .. s) end
                      vim.api.nvim_buf_set_lines(scratch_buf, 0, -1, false, b_lines)
                   end
                end)
             end
          end)
        end
      end
      
      vim.api.nvim_create_user_command("ExplainCode", function(cmd_opts) do_ai_action(cmd_opts, "explain") end, { range = true })
      vim.api.nvim_create_user_command("RefactorCode", function(cmd_opts) do_ai_action(cmd_opts, "refactor") end, { range = true })
    end
  }
}
