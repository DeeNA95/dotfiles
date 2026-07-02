return {
  -- Seamless navigation between Neovim and terminal multiplexers (WezTerm)
  {
    'mrjones2014/smart-splits.nvim',
    lazy = false,
    opts = {
      -- Ignored filetypes (e.g. file explorer)
      ignored_filetypes = { 'nofile', 'quickfix', 'qf', 'prompt' },
      -- Ignored buffer types
      ignored_buftypes = { 'nofile' },
    },
    keys = {
      { '<C-h>', function() require('smart-splits').move_cursor_left() end, desc = 'Move left' },
      { '<C-j>', function() require('smart-splits').move_cursor_down() end, desc = 'Move down' },
      { '<C-k>', function() require('smart-splits').move_cursor_up() end, desc = 'Move up' },
      { '<C-l>', function() require('smart-splits').move_cursor_right() end, desc = 'Move right' },
      -- Resizing splits
      { '<C-Left>', function() require('smart-splits').resize_left() end, desc = 'Resize left' },
      { '<C-Down>', function() require('smart-splits').resize_down() end, desc = 'Resize down' },
      { '<C-Up>', function() require('smart-splits').resize_up() end, desc = 'Resize up' },
      { '<C-Right>', function() require('smart-splits').resize_right() end, desc = 'Resize right' },
    },
  },
}
