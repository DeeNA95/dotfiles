return {
  "dmtrKovalenko/fff.nvim",
  build = function()
    require("fff.download").download_or_build_binary()
  end,
  lazy = true, -- Set to true to prevent startup crash if binary is missing
  dependencies = { "nvim-lua/plenary.nvim" },
  opts = {
    grep = {
      modes = { 'fuzzy', 'plain', 'regex' }, -- 'fuzzy' first makes it the default
    },
  },
  config = function(_, opts)
    require("fff").setup(opts)
  end,
  keys = {
    {
      "<leader>ff",
      function() require('fff').find_files() end,
      desc = "Find files (fff)",
    },
    {
      "<leader>fF",
      function() require('fff').find_files({ hidden = true, no_ignore = true }) end,
      desc = "Find all files (fff)",
    },
    {
      "<leader>fg",
      function() require('fff').live_grep() end,
      desc = "Live Grep (fff)",
    },
  }
}
