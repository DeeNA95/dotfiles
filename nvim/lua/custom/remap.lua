-- Leader keys set in init.lua

local keymap = vim.keymap
local opts = { noremap = true, silent = true }

-- File operations
keymap.set("n", "<leader>pv", ":Ex<CR>", { desc = "Open directory (Ex)" })
keymap.set("n", "<C-s>", ":w<CR>", { desc = "Save file" })
keymap.set("n", "<leader>w", ":w<CR>", { desc = "Save file" })
keymap.set("n", "<leader>q", ":q<CR>", { desc = "Quit" })
keymap.set("n", "<leader>Q", ":x<CR>", { desc = "Save and quit" })

-- Window management
keymap.set('n', '<leader>s', ':vsplit<CR>', { desc = "Vertical split" })
keymap.set('n', '<leader>h', ':split<CR>', { desc = "Horizontal split" })
keymap.set('n', '<C-h>', '<C-w>h', { desc = "Move to left window" })
keymap.set('n', '<C-j>', '<C-w>j', { desc = "Move to bottom window" })
keymap.set('n', '<C-k>', '<C-w>k', { desc = "Move to top window" })
keymap.set('n', '<C-l>', '<C-w>l', { desc = "Move to right window" })
keymap.set('n', '<C-Up>', ':resize +2<CR>', { desc = "Increase window height" })
keymap.set('n', '<C-Down>', ':resize -2<CR>', { desc = "Decrease window height" })
keymap.set('n', '<C-Left>', ':vertical resize -2<CR>', { desc = "Decrease window width" })
keymap.set('n', '<C-Right>', ':vertical resize +2<CR>', { desc = "Increase window width" })

-- Buffer navigation
keymap.set('n', '<S-l>', ':bnext<CR>', { desc = "Next buffer" })
keymap.set('n', '<S-h>', ':bprevious<CR>', { desc = "Previous buffer" })
keymap.set('n', '<leader>bd', ':bdelete<CR>', { desc = "Delete buffer" })
keymap.set('n', '<leader>ba', ':%bd|e#|bd#<CR>', { desc = "Delete all buffers except current" })

-- Text manipulation
keymap.set('v', '<', '<gv', { desc = "Indent left and reselect" })
keymap.set('v', '>', '>gv', { desc = "Indent right and reselect" })
keymap.set('v', 'J', ":m '>+1<CR>gv=gv", { desc = "Move selected lines down" })
keymap.set('v', 'K', ":m '<-2<CR>gv=gv", { desc = "Move selected lines up" })
keymap.set('n', 'J', 'mzJ`z', { desc = "Join lines and keep cursor position" })

-- Better search
keymap.set('n', 'n', 'nzzzv', { desc = "Next search result (centered)" })
keymap.set('n', 'N', 'Nzzzv', { desc = "Previous search result (centered)" })
-- <leader>/ is mapped to buffer fuzzy find by Telescope

-- Clipboard
keymap.set('n', '<leader>y', '"+y', { desc = "Copy to system clipboard" })
keymap.set('v', '<leader>y', '"+y', { desc = "Copy to system clipboard" })
keymap.set('n', '<leader>Y', '"+Y', { desc = "Copy line to system clipboard" })
keymap.set('n', '<leader>P', '"+p', { desc = "Paste from system clipboard" })
keymap.set('v', '<leader>P', '"+p', { desc = "Paste from system clipboard" })

-- macOS-style clipboard shortcuts (Cmd+C, Cmd+V)
keymap.set('v', '<D-c>', '"+y', { desc = "Copy selection to system clipboard (Cmd+C)" })
keymap.set('n', '<D-c>', '"+yy', { desc = "Copy line to system clipboard (Cmd+C)" })
keymap.set('n', '<D-v>', '"+p', { desc = "Paste from system clipboard (Cmd+V)" })
keymap.set('v', '<D-v>', '"+p', { desc = "Paste from system clipboard (Cmd+V)" })
keymap.set('i', '<D-v>', '<C-r>+', { desc = "Paste from system clipboard in insert mode (Cmd+V)" })
keymap.set('c', '<D-v>', '<C-r>+', { desc = "Paste from system clipboard in command mode (Cmd+V)" })

-- Commenting (macOS-style Cmd+/)
keymap.set('n', '<D-/>', 'gcc', { remap = true, desc = "Comment line (Cmd+/)" })
keymap.set('v', '<D-/>', 'gc', { remap = true, desc = "Comment selection (Cmd+/)" })
keymap.set('n', '<C-_>', 'gcc', { remap = true, desc = "Comment line (fallback for Cmd+/)" })
keymap.set('v', '<C-_>', 'gc', { remap = true, desc = "Comment selection (fallback for Cmd+/)" })
keymap.set('n', '<C-/>', 'gcc', { remap = true, desc = "Comment line (fallback for Cmd+/)" })
keymap.set('v', '<C-/>', 'gc', { remap = true, desc = "Comment selection (fallback for Cmd+/)" })

-- Quick command
keymap.set('n', '<leader>;', ':', { desc = "Command mode" })

-- Toggle options
keymap.set('n', '<leader>tw', ':set wrap!<CR>', { desc = "Toggle word wrap" })
keymap.set('n', '<leader>tn', ':set number!<CR>', { desc = "Toggle line numbers" })
keymap.set('n', '<leader>tr', ':set relativenumber!<CR>', { desc = "Toggle relative numbers" })

