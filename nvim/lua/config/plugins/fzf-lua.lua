return {
  "ibhagwan/fzf-lua",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  config = function()
    local fzf = require("fzf-lua")
    fzf.setup({
      -- Fuzzy by default, optimizing for best matches (shorter/earlier)
      fzf_opts = {
        ["--tiebreak"] = "begin,length",
      },
      winopts = {
        height = 0.85,
        width = 0.80,
        preview = {
          layout = "vertical",
          vertical = "down:50%",
        },
      },
    })

    -- Map Telescope-like keys to fzf-lua
    vim.keymap.set("n", "<leader>fb", function() fzf.buffers() end, { desc = "Buffers" })
    vim.keymap.set("n", "<leader>fh", function() fzf.help_tags() end, { desc = "Help Tags" })
    vim.keymap.set("n", "<leader>fr", function() fzf.oldfiles() end, { desc = "Recent Files" })
    vim.keymap.set("n", "<leader>fw", function() fzf.grep_cword() end, { desc = "Grep word under cursor" })
    vim.keymap.set("n", "<leader>fc", function() fzf.commands() end, { desc = "Commands" })
    vim.keymap.set("n", "<leader>fk", function() fzf.keymaps() end, { desc = "Keymaps" })
    vim.keymap.set("n", "<leader>fs", function() fzf.lsp_document_symbols() end, { desc = "Document Symbols" })
    vim.keymap.set("n", "<leader>fS", function() fzf.lsp_workspace_symbols() end, { desc = "Workspace Symbols" })
    vim.keymap.set("n", "<leader>/", function() fzf.lgrep_curbuf() end, { desc = "Fuzzy find in buffer" })
  end,
}
