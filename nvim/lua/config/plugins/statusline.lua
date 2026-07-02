-- In lua/config/plugins/statusline.lua
return {
  {
    "nvim-lualine/lualine.nvim",
    event = "VeryLazy",
    dependencies = { "nvim-tree/nvim-web-devicons" },
    opts = function()
      return {
        options = {
          theme = "auto", -- Matches your colorscheme
          component_separators = { left = "", right = "" },
          section_separators = { left = "", right = "" },
          globalstatus = true,
          disabled_filetypes = { statusline = { "dashboard", "alpha" } },
        },
        sections = {
          lualine_a = { { "mode", icon = "" } },
          lualine_b = {
            { "branch", icon = "" },
            {
              "diff",
              symbols = {
                added = " ",
                modified = " ",
                removed = " ",
              },
            },
          },
          lualine_c = {
            {
              "filename",
              path = 1, -- Show relative path
              symbols = {
                modified = "  ",
                readonly = "  ",
                unnamed = "[No Name]",
                newfile = "[New]",
              },
            },
            {
              "diagnostics",
              sources = { "nvim_diagnostic" },
              symbols = {
                error = " ",
                warn = " ",
                info = " ",
                hint = " ",
              },
            },
          },
          lualine_x = {
            {
              function()
                local clients = vim.lsp.get_clients({ bufnr = 0 })
                if #clients == 0 then return "No LSP" end
                local names = {}
                for _, client in ipairs(clients) do table.insert(names, client.name) end
                return " " .. table.concat(names, ", ")
              end,
            },
            { "filetype", colored = true, icon_only = false },
            { "encoding" },
            {
              "fileformat",
              symbols = {
                unix = " ",
                dos = " ",
                mac = " ",
              },
            },
          },
          lualine_y = { "progress" },
          lualine_z = { "location" },
        },
        extensions = { "lazy", "nvim-tree", "toggleterm", "quickfix" },
      }
    end,
  },
}

