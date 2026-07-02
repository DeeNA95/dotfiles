-- Persistence: Simple session management
return {
  "folke/persistence.nvim",
  event = "BufReadPre", -- this will only start session saving when an actual file is opened
  opts = {
    -- directory where session files are saved
    dir = vim.fn.stdpath("state") .. "/sessions/",
    -- sessionoptions used for saving
    options = { "buffers", "curdir", "tabpages", "winsize" },
  },
  keys = {
    -- load the session for the current directory
    { "<leader>qs", function() require("persistence").load() end, desc = "Restore Session" },
    -- select a session to load
    { "<leader>qS", function() require("persistence").select() end, desc = "Select Session" },
    -- load the last session
    { "<leader>ql", function() require("persistence").load({ last = true }) end, desc = "Restore Last Session" },
    -- stop Persistence => session won't be saved on exit
    { "<leader>qd", function() require("persistence").stop() end, desc = "Don't Save Current Session" },
  },
}
