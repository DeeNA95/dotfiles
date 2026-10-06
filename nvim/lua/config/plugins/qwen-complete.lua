return {
  {
    name = "qwen-complete",
    dir = vim.fn.stdpath("config"),
    event = "InsertEnter",
    opts = { map_tab = false }, -- Blink owns Tab.
    config = function(_, opts)
      require("qwen_complete").setup(opts)
    end,
  },
}
