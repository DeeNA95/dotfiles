local notebook_python = vim.fn.stdpath("data") .. "/python3"

return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    init = function()
      local python = notebook_python .. "/bin/python"
      local bin = notebook_python .. "/bin"
      if vim.fn.executable(python) == 1 then
        vim.g.python3_host_prog = python
      end
      if vim.fn.isdirectory(bin) == 1 and not vim.env.PATH:find(bin, 1, true) then
        vim.env.PATH = bin .. ":" .. vim.env.PATH
      end

      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = false
      vim.g.molten_virt_text_output = true
      vim.g.molten_output_virt_lines = true
      vim.g.molten_output_show_more = true
      vim.g.molten_wrap_output = true
      vim.g.molten_enter_output_behavior = "open_and_enter"
      vim.g.molten_save_cell_visual_selection = true
      vim.g.molten_virt_text_max_lines = 10
    end,
    config = function()
      require("config.notebook").setup()
    end,
    dependencies = {
      "3rd/image.nvim",
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "GCBallesteros/jupytext.nvim",
    lazy = false,
    opts = {
      style = "percent",
      output_extension = "auto",
    },
    config = function(_, opts)
      require("jupytext").setup(opts)
    end,
  },
}
