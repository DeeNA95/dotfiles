
-- Dashboard with alpha-nvim
return {
  "goolord/alpha-nvim",
  event = "VimEnter",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  opts = function()
    local dashboard = require("alpha.themes.dashboard")

    -- Master Roshi's Turtle Hermit School header
    dashboard.section.header.val = {
      "                                        ",
      "    ╔═══════════════════════════════╗    ",
      "    ║     🐢  TURTLE HERMIT SCHOOL  ║    ",
      "    ║        ── 亀仙流 ──           ║    ",
      "    ╠═══════════════════════════════╣    ",
      "    ║                               ║    ",
      "    ║  \"Work Hard, Study Well, and  ║    ",
      "    ║   Eat and Sleep Plenty!\"      ║    ",
      "    ║                               ║    ",
      "    ║         — Master Roshi        ║    ",
      "    ╚═══════════════════════════════╝    ",
      "                                        ",
    }

    dashboard.section.buttons.val = {
      dashboard.button("f", "  Find file (fff)",    "<cmd>lua require('fff').find_files()<cr>"),
      dashboard.button("r", "  Recent files (fzf)", "<cmd>FzfLua oldfiles<cr>"),
      dashboard.button("g", "  Find text (fzf)",    "<cmd>FzfLua live_grep<cr>"),
      dashboard.button("s", "  Restore session",    "<cmd>lua require('persistence').load()<cr>"),
      dashboard.button("n", "  New file",           "<cmd>ene <BAR> startinsert<cr>"),
      dashboard.button("c", "  Config",             "<cmd>e $MYVIMRC<cr>"),
      dashboard.button("l", "󰒲  Lazy",               "<cmd>Lazy<cr>"),
      dashboard.button("m", "  Mason",              "<cmd>Mason<cr>"),
      dashboard.button("q", "  Quit",               "<cmd>qa<cr>"),
    }

    -- Footer: show loaded plugin count
    dashboard.section.footer.val = function()
      local stats = require("lazy").stats()
      return "⚡ " .. stats.loaded .. "/" .. stats.count .. " plugins loaded in " .. string.format("%.1f", stats.startuptime) .. "ms"
    end

    dashboard.section.header.opts.hl = "AlphaHeader"
    dashboard.section.buttons.opts.hl = "AlphaButtons"
    dashboard.section.footer.opts.hl = "AlphaFooter"

    return dashboard
  end,
  config = function(_, dashboard)
    -- Highlight groups matching Kanagawa theme
    vim.api.nvim_create_autocmd("User", {
      pattern = "AlphaReady",
      callback = function()
        vim.api.nvim_set_hl(0, "AlphaHeader", { fg = "#E46876", bold = true })  -- Kanagawa red
        vim.api.nvim_set_hl(0, "AlphaButtons", { fg = "#7E9CD8" })              -- Kanagawa blue
        vim.api.nvim_set_hl(0, "AlphaFooter", { fg = "#717C7C", italic = true }) -- Kanagawa gray
      end,
    })

    -- Disable folding on alpha buffer
    vim.api.nvim_create_autocmd("FileType", {
      pattern = "alpha",
      callback = function()
        vim.opt_local.foldenable = false
      end,
    })

    require("alpha").setup(dashboard.opts)
  end,
}
