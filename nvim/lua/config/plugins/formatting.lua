-- Formatting with conform.nvim
return {
  "stevearc/conform.nvim",
  event = { "BufWritePre" },
  cmd = { "ConformInfo" },
  keys = {
    {
      "<leader>f",
      function()
        require("conform").format({ async = true, lsp_fallback = true })
      end,
      mode = "",
      desc = "Format buffer",
    },
  },
  opts = {
    formatters_by_ft = {
      python = { "isort", "black" },
      c = { "clang-format" },
      cpp = { "clang-format" },
      go = { "goimports", "golines" },
      rust = { "rustfmt", lsp_format = "fallback" },
      cuda = { "clang-format" },
      cmake = { "cmake_format" },
      sh = { "shfmt" },
      bash = { "shfmt" },
      lua = { "stylua" },
      yaml = { "yamlfmt", "prettier", stop_after_first = true },
      json = { "prettier" },
      jsonc = { "prettier" },
      markdown = { "prettier" },
      toml = { "taplo" },
    },
    format_on_save = {
      timeout_ms = 3000,
      lsp_fallback = true,
    },
    formatters = {
      yamlfmt = {
        prepend_args = { "-conf", vim.fn.stdpath("config") .. "/.yamlfmt" },
      },
      golines = {
        prepend_args = { "--max-len=120" },
      },
    },
  },
}
