-- Jupyter notebook support via molten.nvim
return {
  {
    "benlubas/molten-nvim",
    version = "^1.0.0",
    build = ":UpdateRemotePlugins",
    init = function()
      vim.g.molten_image_provider = "image.nvim"
      vim.g.molten_output_win_max_height = 20
      vim.g.molten_auto_open_output = true
      vim.g.molten_virt_text_output = true
      vim.g.molten_virt_text_win_hl = "Comment"
      vim.g.molten_enter_output_behavior = "open_and_enter"
      vim.g.molten_save_cell_visual_selection = true
      vim.g.molten_virt_text_max_lines = 10
    end,
    config = function()
      -- Keymaps for molten
      vim.keymap.set("n", "<leader>mi", ":MoltenInit<CR>", { desc = "Molten: Initialize kernel" })
      vim.keymap.set("n", "<leader>mr", ":MoltenReevaluateCell<CR>", { desc = "Molten: Reevaluate cell" })
      vim.keymap.set("x", "<leader>mr", ":<C-u>MoltenEvaluateVisual<CR>", { desc = "Molten: Evaluate visual selection" })
      vim.keymap.set("n", "<leader>md", ":MoltenDelete<CR>", { desc = "Molten: Delete cell" })
      vim.keymap.set("n", "<leader>mo", ":MoltenShowOutput<CR>", { desc = "Molten: Show output" })
      vim.keymap.set("n", "<leader>mh", ":MoltenHideOutput<CR>", { desc = "Molten: Hide output" })
    end,
    dependencies = {
      "3rd/image.nvim",
      "nvim-lua/plenary.nvim",
    },
  },
  {
    "GCBallesteros/jupytext.nvim",
    config = true,
  },
}
