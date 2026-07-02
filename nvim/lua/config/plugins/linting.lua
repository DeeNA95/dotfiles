-- Linting with nvim-lint
return {
  "mfussenegger/nvim-lint",
  event = { "BufReadPre", "BufNewFile" },
  config = function()
    local lint = require("lint")

    lint.linters_by_ft = {
      python = { "flake8" },
      -- C/C++/CUDA: linting handled by clangd + clang-tidy (LSP)
      go = { "golangcilint" },
      cmake = { "cmakelint" },
      make = { "checkmake" },
      dockerfile = { "hadolint" },
      markdown = { "markdownlint" },
      sh = { "shellcheck" },
      bash = { "shellcheck" },
    }

    -- Auto-lint on save and file read
    vim.api.nvim_create_autocmd({ "BufWritePost", "BufReadPost" }, {
      callback = function()
        lint.try_lint()
      end,
    })
  end,
}
