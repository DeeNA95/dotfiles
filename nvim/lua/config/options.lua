-- In your lua/config/options.lua
local opt = vim.opt

-- Font and icon settings
vim.g.have_nerd_font = true
vim.o.guifont = "Hack Nerd Font Mono:h12"  -- Changed to Mono variant for better icon display
vim.g.encoding = "UTF-8"
vim.g.fileencoding = "utf-8"

-- UI improvements
opt.termguicolors = true           -- True color support
opt.number = true                  -- Show line numbers
opt.relativenumber = false         -- Fixed line numbers, not relative
opt.mouse = "a"                    -- Enable mouse in all modes
opt.pumheight = 10                 -- Max height of popup menus
opt.showtabline = 2                -- Always show tabs
opt.title = true                   -- Set window title
opt.cursorline = true              -- Highlight current line
opt.signcolumn = "yes"             -- Always show sign column
opt.scrolloff = 8                  -- Lines of context above/below cursor
opt.sidescrolloff = 8              -- Columns of context to the left/right
opt.laststatus = 3                 -- Global statusline
opt.showcmd = false                -- Don't show command in last line
opt.cmdheight = 1                  -- More space for messages
opt.showmode = false               -- Don't show mode since we have a statusline
opt.conceallevel = 0               -- Show text normally
opt.wrap = false                   -- Display long lines as just one line
opt.linebreak = true               -- Break lines at word boundary
opt.splitbelow = true              -- New horizontal split appears below
opt.splitright = true              -- New vertical split appears to the right
opt.list = true                    -- Show some invisible characters
opt.listchars = {
  tab = "│ ",
  extends = "⟩",
  precedes = "⟨",
  trail = "·",
  nbsp = "␣"
}

-- Set window transparency if you want it
-- Comment this out if you don't want transparent background
vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "*",
  callback = function()
    -- -- Make background transparent
    -- vim.api.nvim_set_hl(0, "Normal", { bg = "NONE", ctermbg = "NONE" })
    -- vim.api.nvim_set_hl(0, "NormalFloat", { bg = "NONE", ctermbg = "NONE" })
  end,
})

-- Additional performance and behavior settings
opt.updatetime = 300                  -- Faster completion
opt.timeoutlen = 300                  -- How long to wait for mapped sequence (matches which-key)
opt.undofile = true                   -- Save undo history
opt.backup = false                    -- Don't create backup files
opt.writebackup = false               -- Don't create backup while editing
opt.swapfile = false                  -- Don't create swap files
opt.confirm = true                    -- Confirm before closing unsaved files
opt.autowrite = true                  -- Auto write when switching buffers
opt.autoread = true                   -- Auto read when file is changed outside
opt.clipboard = "unnamedplus"         -- Use system clipboard
opt.ignorecase = true                 -- Case insensitive search
opt.smartcase = true                  -- Override ignorecase if search has uppercase
opt.hlsearch = false                  -- Don't highlight all search matches
opt.completeopt = "menu,menuone,noselect" -- Better completion experience
opt.wildmode = "longest:full,full"    -- Better command line completion
opt.spelllang = { "en" }              -- Spell check language
opt.grepprg = "rg --vimgrep"          -- Use ripgrep for grep if available
opt.grepformat = "%f:%l:%c:%m"        -- Format for grep results

