-- lua/config/plugins/treesitter.lua
return {
  -- Treesitter Parser Manager (main branch for Neovim 0.12+)
  {
    "nvim-treesitter/nvim-treesitter",
    branch = "main",
    lazy = false,
    build = ":TSUpdate",
    config = function()
      -- 1. Configure installation settings to prefer Git (more reliable than tarball extraction)
      require("nvim-treesitter.install").prefer_git = true

      -- 2. Ensure required parsers are installed
      local ts = require("nvim-treesitter")
      local ts_config = require("nvim-treesitter.config")
      local already_installed = ts_config.get_installed()
      local ensure_installed = {
        "lua", "vim", "vimdoc", "bash", "fish",
        "javascript", "typescript", "tsx", "json", "yaml", "toml",
        "python", "r", "cpp", "c", "cuda", "rust", "go",
        "html", "css", "scss", "markdown", "markdown_inline",
        "regex", "dockerfile", "gitignore", "query", "cmake"
      }

      local parsers_to_install = {}
      for _, parser in ipairs(ensure_installed) do
        if not vim.tbl_contains(already_installed, parser) then
          table.insert(parsers_to_install, parser)
        end
      end

      if #parsers_to_install > 0 then
        pcall(ts.install, parsers_to_install)
      end

      -- 2. Automatically enable Treesitter syntax highlighting and indentation (where appropriate)
      vim.api.nvim_create_autocmd("FileType", {
        pattern = "*",
        callback = function(ev)
          local ft = vim.bo[ev.buf].filetype
          local ok, parser = pcall(vim.treesitter.get_parser, ev.buf)
          if ok and parser then
            pcall(vim.treesitter.start, ev.buf)
            -- Enable Treesitter indentation except for python and yaml (known edge cases)
            if ft ~= "python" and ft ~= "yaml" then
              pcall(function()
                vim.bo[ev.buf].indentexpr = "v:lua.require'nvim-treesitter'.indentexpr()"
              end)
            end
          end
        end,
      })

      -- 3. Native Incremental Selection Keymaps
      -- Normal mode: Start visual selection on the parent node
      vim.keymap.set("n", "<C-space>", "van", { remap = true, silent = true, desc = "Init selection" })
      -- Visual mode: Expand selection to parent node
      vim.keymap.set("v", "<C-space>", "an", { remap = true, silent = true, desc = "Increment selection" })
      -- Visual mode: Shrink selection to child node
      vim.keymap.set("v", "<M-space>", "in", { remap = true, silent = true, desc = "Decrement selection" })
    end,
  },

  -- Treesitter Textobjects (main branch for Neovim 0.12+)
  {
    "nvim-treesitter/nvim-treesitter-textobjects",
    branch = "main",
    dependencies = { "nvim-treesitter/nvim-treesitter" },
    config = function()
      require("nvim-treesitter-textobjects").setup({
        select = {
          enable = true,
          lookahead = true,
          keymaps = {
            ["af"] = "@function.outer",
            ["if"] = "@function.inner",
            ["ac"] = "@class.outer",
            ["ic"] = "@class.inner",
            ["al"] = "@loop.outer",
            ["il"] = "@loop.inner",
            ["aa"] = "@parameter.outer",
            ["ia"] = "@parameter.inner",
          },
        },
        move = {
          enable = true,
          set_jumps = true,
          goto_next_start = {
            ["]f"] = "@function.outer",
            ["]c"] = "@class.outer",
          },
          goto_next_end = {
            ["]F"] = "@function.outer",
            ["]C"] = "@class.outer",
          },
          goto_previous_start = {
            ["[f"] = "@function.outer",
            ["[c"] = "@class.outer",
          },
          goto_previous_end = {
            ["[F"] = "@function.outer",
            ["[C"] = "@class.outer",
          },
        },
      })
    end,
  },
}

