-- Global settings that need to be set early
vim.g.mapleader = " "       -- Set leader key
vim.g.maplocalleader = ","  -- Set local leader key

-- Load configuration modules
require "config.options"    -- General Neovim options
require "custom.remap"      -- Key mappings
require "config.lazy"       -- Plugin manager setup

-- Load autocommands
require("config.autocmds").setup()
