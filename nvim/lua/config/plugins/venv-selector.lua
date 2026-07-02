return {
  "linux-cultist/venv-selector.nvim",
  dependencies = {
    "neovim/nvim-lspconfig",
    "mfussenegger/nvim-dap", "mfussenegger/nvim-dap-python", --optional
    { "nvim-telescope/telescope.nvim", branch = "0.1.x", dependencies = { "nvim-lua/plenary.nvim" } },
  },
  branch = "main", -- V2 was merged to main
  config = function()
    require("venv-selector").setup({
      options = {
        notify_user_on_venv_activation = true,
      },
      search = {
        -- 1. Check workspace venvs first (hiding errors for missing folders)
        workspace_envs = {
          command = "$FD '/bin/python$' $CWD/.venv $CWD/venv $CWD/env $CWD/.env --full-path --hidden --no-ignore --absolute-path 2>/dev/null",
        },
        -- 2. Check parent directory venvs next
        parent_envs = {
          command = "$FD '/bin/python$' $CWD/../.venv $CWD/../venv $CWD/../env $CWD/../.env --full-path --hidden --no-ignore --absolute-path 2>/dev/null",
        },
      },
    })
  end,
  keys = {
    { "<leader>cv", "<cmd>VenvSelect<cr>", desc = "Select VirtualEnv" },
    { "<leader>cV", "<cmd>VenvSelectCached<cr>", desc = "Retrieve Cached VirtualEnv" },
  },
}
