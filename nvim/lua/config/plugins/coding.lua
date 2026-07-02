-- Coding-related plugins
return {
  -- File explorer
  {
    "nvim-neo-tree/neo-tree.nvim",
    branch = "v3.x",
    dependencies = {
      "nvim-lua/plenary.nvim",
      "nvim-tree/nvim-web-devicons",
      "MunifTanjim/nui.nvim",
    },
    keys = {
      { "<leader>e", "<cmd>Neotree toggle<cr>", desc = "Toggle Neo-tree" },
      { "<leader>o", "<cmd>Neotree focus<cr>", desc = "Focus Neo-tree" },
    },
    opts = {
      filesystem = {
        bind_to_cwd = false,
        follow_current_file = { enabled = true },
        use_libuv_file_watcher = true,
        filtered_items = {
          hide_gitignored = false,
        },
      },
      window = {
        mappings = {
          ["<space>"] = "none",
        },
      },
    },
  },

  -- Surround text objects
  {
    "kylechui/nvim-surround",
    version = "*",
    event = "VeryLazy",
    opts = {}, -- Replaces config = function() require("nvim-surround").setup({}) end
  },

  -- Better comments (native comments enhanced with Treesitter context)
  {
    "folke/ts-comments.nvim",
    event = "VeryLazy",
    opts = {},
  },

  -- Markdown preview
  {
    "ellisonleao/glow.nvim",
    cmd = "Glow",
    keys = {
      { "<leader>mp", "<cmd>Glow<cr>", desc = "Preview Markdown" },
    },
    opts = {
      border = "rounded",
      pager = false,
    },
  },

  -- Which-key for keybinding hints
  {
    "folke/which-key.nvim",
    event = "VeryLazy",
    opts_extend = { "spec" }, -- Allows extending specs from other files cleanly
    opts = {
      win = {
        border = "rounded",
      },
      spec = {
        { "<leader>f", group = "find" },
        { "<leader>g", group = "git" },
        { "<leader>h", group = "hunk" },
        { "<leader>t", group = "toggle" },
        { "<leader>w", group = "workspace" },
        { "<leader>c", group = "code" },
        { "<leader>b", group = "buffer" },
        { "<leader>d", group = "debug" },
        { "<leader>x", group = "diagnostics" },
        { "<leader>S", group = "session" },
        { "<leader>m", group = "molten/markdown" },
      },
    },
  },

  -- Flash for better f/F/t/T motions
  {
    "folke/flash.nvim",
    event = "VeryLazy",
    opts = {},
    keys = {
      { "s", mode = { "n", "x", "o" }, function() require("flash").jump() end, desc = "Flash" },
      { "S", mode = { "n", "o", "x" }, function() require("flash").treesitter() end, desc = "Flash Treesitter" },
      { "r", mode = "o", function() require("flash").remote() end, desc = "Remote Flash" },
      { "R", mode = { "o", "x" }, function() require("flash").treesitter_search() end, desc = "Treesitter Search" },
    },
  },

  -- Aerial for code outline
  {
    "stevearc/aerial.nvim",
    opts = {},
    dependencies = {
      "nvim-treesitter/nvim-treesitter",
      "nvim-tree/nvim-web-devicons"
    },
    keys = {
      { "<leader>a", "<cmd>AerialToggle!<cr>", desc = "Toggle Aerial" },
    },
  },

  -- TODO/FIXME/HACK highlights
  {
    "folke/todo-comments.nvim",
    cmd = { "TodoTrouble", "TodoTelescope" },
    event = { "BufReadPost", "BufNewFile" },
    dependencies = { "nvim-lua/plenary.nvim" },
    opts = {},
    keys = {
      { "]t", function() require("todo-comments").jump_next() end, desc = "Next TODO" },
      { "[t", function() require("todo-comments").jump_prev() end, desc = "Prev TODO" },
      { "<leader>ft", "<cmd>TodoTelescope<cr>", desc = "Find TODOs" },
      { "<leader>xt", "<cmd>TodoTrouble<cr>", desc = "TODOs (Trouble)" },
    },
  },

  -- Session management (auto-save/restore per project)
  {
    "folke/persistence.nvim",
    event = "BufReadPre",
    opts = {},
    keys = {
      { "<leader>Sr", function() require("persistence").load() end, desc = "Restore Session" },
      { "<leader>Ss", function() require("persistence").select() end, desc = "Select Session" },
      { "<leader>Sl", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
      { "<leader>Sd", function() require("persistence").stop() end, desc = "Stop Persistence" },
    },
  },
}
