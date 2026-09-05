-- WezTerm Configuration for AI/ML Developers
-- Optimized for Python, Go, C++, and CUDA development

local wezterm = require 'wezterm'
local config = wezterm.config_builder()

-- == Colors & Aesthetics ==
-- Dynamically load light/dark theme depending on OS
wezterm.on('window-config-reloaded', function(window, pane)
  local overrides = window:get_config_overrides() or {}
  local appearance = window:get_appearance()

  if appearance:find 'Dark' then
    overrides.color_scheme = 'Kanagawa (Gogh)'
    -- Match the Penny TUI's dark Kanagawa palette exactly so the app
    -- blends seamlessly with the terminal (docs/tui-visual-spec.md §10).
    overrides.colors = {
      background = '#16161d',
      foreground = '#dcd7ba',
      cursor_bg = '#7e9cd8',
      cursor_fg = '#101016',
      selection_bg = '#2d4f67',
      selection_fg = '#dcd7ba',
      ansi = {
        '#16161d', '#e46876', '#98bb6c', '#e6c384',
        '#7e9cd8', '#957fb8', '#7aa89f', '#dcd7ba',
      },
      brights = {
        '#54546d', '#e46876', '#98bb6c', '#e6c384',
        '#7e9cd8', '#957fb8', '#7aa89f', '#ffffff',
      },
    }
  else
    overrides.color_scheme = 'rose-pine'
  end
  window:set_config_overrides(overrides)
end)
-- Penny TUI uses Nerd Font glyphs (spinners, ◆, ╭─ code frames); prefer the
-- JetBrainsMono Nerd Font installed via:
--   brew install --cask font-jetbrains-mono-nerd-font
config.font = wezterm.font_with_fallback({
  'JetBrainsMono Nerd Font',
  'JetBrains Mono',
  'Symbols Nerd Font Mono', -- For nice icons in logs/status
})
config.font_size = 14.0
config.line_height = 1.0

-- Glassmorphism / Vibrant Blur (macOS optimized)
config.window_background_opacity =0.85
config.macos_window_background_blur = 30
config.window_decorations = "RESIZE"
config.window_padding = { left = 15, right = 15, top = 15, bottom = 10 }

-- == Performance & ML Specifics ==
config.scrollback_lines = 100000 -- Essential for long training/build logs
config.front_end = "WebGpu" -- Hardware accelerated rendering
config.animation_fps = 120
config.cursor_blink_rate = 500
-- Allow terminal applications such as Penny to request unambiguous
-- Command-modified key events through the kitty keyboard protocol.
config.enable_kitty_keyboard = true

-- == UI Elements ==
config.enable_tab_bar = true
config.hide_tab_bar_if_only_one_tab = true
config.use_fancy_tab_bar = true
config.tab_bar_at_bottom = false

-- Status bar showing ML-relevant info
config.status_update_interval = 1000
wezterm.on('update-right-status', function(window, pane)
  local date = wezterm.strftime('%H:%M')
  local workspace = window:active_workspace()

  window:set_right_status(wezterm.format {
    { Foreground = { AnsiColor = 'Fuchsia' } },
    { Text = ' 󰀄 AI/ML Flow ' },
    { Foreground = { Color = '#7aa2f7' } },
    { Text = ' | ' .. workspace .. ' | ' .. date .. ' ' },
  })
end)

-- == Key Bindings ==
local act = wezterm.action

local function is_penny(pane)
  local process = pane:get_foreground_process_name() or ''
  local title = pane:get_title() or ''
  local vars = pane:get_user_vars() or {}
  return process == 'penny'
    or process:match('/penny$') ~= nil
    or title == 'penny'
    or vars.PENNY_TUI == '1'
end

-- Send explicit Kitty CSI-u sequences instead of asking WezTerm to synthesize
-- a CMD key. The latter is consumed on some macOS/WezTerm builds before the
-- terminal application receives it. Raw sequences remain reliable through
-- panes, wrappers and multiplexers, while the fallback preserves native
-- WezTerm behavior everywhere outside Penny.
local function penny_input(sequence, fallback)
  return wezterm.action_callback(function(window, pane)
    if is_penny(pane) then
      window:perform_action(act.SendString(sequence), pane)
    else
      window:perform_action(fallback, pane)
    end
  end)
end

config.keys = {
  -- Native query editing in Penny.
  { key = 'a', mods = 'CMD', action = penny_input('\x1b[97;9u', act.SendKey { key = 'a', mods = 'CMD' }) },
  { key = 'c', mods = 'CMD', action = penny_input('\x1b[99;9u', act.CopyTo 'Clipboard') },
  { key = 'x', mods = 'CMD', action = penny_input('\x1b[120;9u', act.SendKey { key = 'x', mods = 'CMD' }) },
  { key = 'v', mods = 'CMD', action = penny_input('\x1b[118;9u', act.PasteFrom 'Clipboard') },
  { key = 'z', mods = 'CMD', action = penny_input('\x1b[122;9u', act.SendKey { key = 'z', mods = 'CMD' }) },
  { key = 'Z', mods = 'CMD|SHIFT', action = penny_input('\x1b[122;10u', act.SendKey { key = 'Z', mods = 'CMD|SHIFT' }) },

  -- Fast Workspace switching & Creation
  { key = 'w', mods = 'CMD', action = act.CloseCurrentTab { confirm = true } },
  { key = 't', mods = 'CMD', action = act.SpawnTab 'CurrentPaneDomain' },

  -- Intelligent Splitting (Vertical/Horizontal)
  -- CMD+D: Splitting horizontally (side-by-side) - good for code/logs
  { key = 'd', mods = 'CMD', action = act.SplitHorizontal { domain = 'CurrentPaneDomain' } },
  -- CMD+SHIFT+D: Splitting vertically (top/bottom) - good for monitor/nvidia-smi
  { key = 'D', mods = 'CMD|SHIFT', action = act.SplitVertical { domain = 'CurrentPaneDomain' } },

  -- Navigation (VIM-style)
  -- Navigation (Smart-Splits)
  { key = 'h', mods = 'CMD', action = act.EmitEvent 'smart-split-h' },
  { key = 'j', mods = 'CMD', action = act.EmitEvent 'smart-split-j' },
  { key = 'k', mods = 'CMD', action = act.EmitEvent 'smart-split-k' },
  { key = 'l', mods = 'CMD', action = act.EmitEvent 'smart-split-l' },

  -- Search (CMD+F)
  { key = 'f', mods = 'CMD', action = act.Search 'CurrentSelectionOrEmptyString' },

  -- Command Palette (CMD+SHIFT+P)
  { key = 'P', mods = 'CMD|SHIFT', action = act.ActivateCommandPalette },

  -- Font size adjustment (Essential for screen sharing/presenting math/code)
  { key = '=', mods = 'CMD', action = act.IncreaseFontSize },
  { key = '-', mods = 'CMD', action = act.DecreaseFontSize },
  { key = '0', mods = 'CMD', action = act.ResetFontSize },

  -- macOS-style deletion
  -- CMD+Backspace: Delete whole line
  { key = 'Backspace', mods = 'CMD', action = penny_input('\x1b[127;9u', act.SendString '\u{15}') },
  -- OPTION+Backspace: Delete one word
  { key = 'Backspace', mods = 'OPT', action = penny_input('\x1b[127;3u', act.SendString '\u{1b}\u{7f}') },
  -- macOS-style navigation
  { key = 'LeftArrow', mods = 'OPT', action = penny_input('\x1b[1;3D', act.SendString '\u{1b}b') },
  { key = 'RightArrow', mods = 'OPT', action = penny_input('\x1b[1;3C', act.SendString '\u{1b}f') },
  { key = 'LeftArrow', mods = 'OPT|SHIFT', action = penny_input('\x1b[1;4D', act.SendKey { key = 'LeftArrow', mods = 'OPT|SHIFT' }) },
  { key = 'RightArrow', mods = 'OPT|SHIFT', action = penny_input('\x1b[1;4C', act.SendKey { key = 'RightArrow', mods = 'OPT|SHIFT' }) },
  { key = 'LeftArrow', mods = 'CMD', action = penny_input('\x1b[1;9D', act.SendString '\u{1}') },
  { key = 'RightArrow', mods = 'CMD', action = penny_input('\x1b[1;9C', act.SendString '\u{5}') },
  { key = 'LeftArrow', mods = 'CMD|SHIFT', action = penny_input('\x1b[1;10D', act.SendKey { key = 'LeftArrow', mods = 'CMD|SHIFT' }) },
  { key = 'RightArrow', mods = 'CMD|SHIFT', action = penny_input('\x1b[1;10C', act.SendKey { key = 'RightArrow', mods = 'CMD|SHIFT' }) },
  { key = 'UpArrow', mods = 'CMD', action = penny_input('\x1b[1;9A', act.SendKey { key = 'UpArrow', mods = 'CMD' }) },
  { key = 'DownArrow', mods = 'CMD', action = penny_input('\x1b[1;9B', act.SendKey { key = 'DownArrow', mods = 'CMD' }) },
  { key = 'UpArrow', mods = 'CMD|SHIFT', action = penny_input('\x1b[1;10A', act.SendKey { key = 'UpArrow', mods = 'CMD|SHIFT' }) },
  { key = 'DownArrow', mods = 'CMD|SHIFT', action = penny_input('\x1b[1;10B', act.SendKey { key = 'DownArrow', mods = 'CMD|SHIFT' }) },

  -- Workspace Management
  { key = 's', mods = 'CMD', action = act.ShowLauncherArgs { flags = 'WORKSPACES' } },
  {
    key = 'n',
    mods = 'CMD',
    action = act.PromptInputLine {
      description = 'Enter name for new workspace',
      action = wezterm.action_callback(function(window, pane, line)
        if line then
          window:perform_action(
            act.SwitchToWorkspace {
              name = line,
            },
            pane
          )
        end
      end),
    },
  },
}

-- == Advanced Interaction ==
-- Quickly pick up SHA, Hex, or Python file paths from the screen
config.quick_select_patterns = {
  -- Python Traceback file paths
  'File "([^"]+)", line ([0-9]+)',
  -- CUDA/C++ error symbols
  '0x[0-9a-fA-F]+',
}

-- Hyperlink rules for file paths (makes clicking errors open them)
config.hyperlink_rules = {
    -- Link to local files: file:///path/to/file
    {
      regex = [[\bfile://(\S+)\b]],
      format = 'file://$1',
    },
    -- Standard HTTP links
    {
      regex = [[https?://\S+]],
      format = '$0',
    },
}

-- == Cursor & Selection ==
config.default_cursor_style = 'BlinkingBar'
config.selection_word_boundary = " \t\n{}[]()\"'`" -- Optimized for code selection

-- == Smart-splits logic for seamless navigation between Neovim and WezTerm ==
local function is_vim(pane)
  -- This checks if the current pane is running vim/nvim
  return pane:get_foreground_process_name():find('n?vim') ~= nil
end

local function split_nav(resize_or_move, key)
  return function(window, pane)
    if is_vim(pane) then
      -- Pass the keys to nvim (using Ctrl bindings for smart-splits)
      window:perform_action({ SendKey = { key = key, mods = 'CTRL' } }, pane)
    else
      window:perform_action({ ActivatePaneDirection = resize_or_move }, pane)
    end
  end
end

wezterm.on('smart-split-h', split_nav('Left', 'h'))
wezterm.on('smart-split-j', split_nav('Down', 'j'))
wezterm.on('smart-split-k', split_nav('Up', 'k'))
wezterm.on('smart-split-l', split_nav('Right', 'l'))

return config
