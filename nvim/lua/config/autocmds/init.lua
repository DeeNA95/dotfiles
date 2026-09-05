-- Autocommands for language-specific settings
local function setup_autocmds()
  local autocmd = vim.api.nvim_create_autocmd
  local augroup = vim.api.nvim_create_augroup

  -- Python specific settings
  local python_group = augroup("PythonSettings", { clear = true })
  autocmd("FileType", {
    group = python_group,
    pattern = "python",
    callback = function()
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
      vim.opt_local.expandtab = true
      vim.opt_local.colorcolumn = "88"  -- Black's default line length
    end,
  })

  -- C++ specific settings
  local cpp_group = augroup("CppSettings", { clear = true })
  autocmd("FileType", {
    group = cpp_group,
    pattern = {"cpp", "c"},
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
      vim.opt_local.colorcolumn = "80"
    end,
  })

  -- R specific settings
  local r_group = augroup("RSettings", { clear = true })
  autocmd("FileType", {
    group = r_group,
    pattern = "r",
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
    end,
  })

  -- Go specific settings
  local go_group = augroup("GoSettings", { clear = true })
  autocmd("FileType", {
    group = go_group,
    pattern = "go",
    callback = function()
      vim.opt_local.shiftwidth = 4
      vim.opt_local.tabstop = 4
      vim.opt_local.softtabstop = 4
      vim.opt_local.expandtab = false  -- Go uses tabs
      vim.opt_local.colorcolumn = "120"

      -- Go-specific key mappings
      local opts = { noremap = true, silent = true, buffer = true }
      vim.keymap.set('n', '<leader>gr', ':GoRun<CR>', vim.tbl_extend('force', opts, { desc = 'Go Run' }))
      vim.keymap.set('n', '<leader>gt', ':GoTest<CR>', vim.tbl_extend('force', opts, { desc = 'Go Test' }))
      vim.keymap.set('n', '<leader>gb', ':GoBuild<CR>', vim.tbl_extend('force', opts, { desc = 'Go Build' }))
      vim.keymap.set('n', '<leader>gc', ':GoCoverage<CR>', vim.tbl_extend('force', opts, { desc = 'Go Coverage' }))
      vim.keymap.set('n', '<leader>gi', ':GoImports<CR>', vim.tbl_extend('force', opts, { desc = 'Go Imports' }))
    end,
  })
  -- Lua specific settings
  local lua_group = augroup("LuaSettings", { clear = true })
  autocmd("FileType", {
    group = lua_group,
    pattern = "lua",
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
      vim.opt_local.colorcolumn = "120"
    end,
  })

  -- Shell/Bash specific settings
  local shell_group = augroup("ShellSettings", { clear = true })
  autocmd("FileType", {
    group = shell_group,
    pattern = { "sh", "bash", "zsh" },
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
      vim.opt_local.colorcolumn = "80"
    end,
  })

  -- YAML specific settings
  local yaml_group = augroup("YamlSettings", { clear = true })
  autocmd("FileType", {
    group = yaml_group,
    pattern = "yaml",
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
    end,
  })

  -- TOML specific settings
  local toml_group = augroup("TomlSettings", { clear = true })
  autocmd("FileType", {
    group = toml_group,
    pattern = "toml",
    callback = function()
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
    end,
  })

  -- Markdown specific settings
  local md_group = augroup("MarkdownSettings", { clear = true })
  autocmd("FileType", {
    group = md_group,
    pattern = "markdown",
    callback = function()
      vim.opt_local.wrap = true
      vim.opt_local.linebreak = true
      vim.opt_local.spell = true
      vim.opt_local.conceallevel = 2
      vim.opt_local.shiftwidth = 2
      vim.opt_local.tabstop = 2
      vim.opt_local.expandtab = true
    end,
  })

  -- Go format-on-save handled by conform.nvim (see plugins/formatting.lua)
end

return { setup = setup_autocmds }
