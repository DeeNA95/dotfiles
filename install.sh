#!/usr/bin/env bash
set -e

DOTFILES_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "======================================"
echo "    Setting up dotfiles..."
echo "======================================"

# --- Utility Functions ---
backup_if_exists() {
    local target="$1"
    if [ -e "$target" ] || [ -L "$target" ]; then
        # Skip if it's already symlinked to our dotfiles
        if [ -L "$target" ] && [ "$(readlink "$target")" = "$2" ]; then
            return
        fi
        local timestamp=$(date +%Y%m%d_%H%M%S)
        local backup="${target}.${timestamp}.bak"
        echo "  • Backing up existing $(basename "$target") to $(basename "$backup")..."
        mv "$target" "$backup"
    fi
}

create_symlink() {
    local source_file="$1"
    local target_file="$2"
    
    # Create target directory if it doesn't exist
    mkdir -p "$(dirname "$target_file")"
    
    backup_if_exists "$target_file" "$source_file"
    
    if [ ! -L "$target_file" ]; then
        ln -sf "$source_file" "$target_file"
        echo "  ✔ Linked $target_file -> $source_file"
    else
        echo "  ✔ $target_file already linked"
    fi
}

# --- Core Setup ---

check_and_install_zsh() {
    if ! command -v zsh >/dev/null 2>&1; then
        echo "Zsh not found. Installing..."
        if command -v brew >/dev/null 2>&1; then
            brew install zsh
        elif command -v apt-get >/dev/null 2>&1; then
            sudo apt-get update && sudo apt-get install -y zsh
        elif command -v dnf >/dev/null 2>&1; then
            sudo dnf install -y zsh
        elif command -v pacman >/dev/null 2>&1; then
            sudo pacman -S --noconfirm zsh
        else
            echo "Error: No supported package manager found to install Zsh. Please install it manually."
            exit 1
        fi
    else
        echo "Zsh is already installed."
    fi
}

set_default_shell() {
    CURRENT_SHELL=$(basename "$SHELL")
    if [ "$CURRENT_SHELL" != "zsh" ]; then
        echo "Changing default shell to Zsh..."
        if command -v chsh >/dev/null 2>&1; then
            sudo chsh -s "$(which zsh)" "$USER"
        else
            echo "Warning: 'chsh' not found. Please manually set Zsh as your default shell."
        fi
    fi
}

install_zap() {
    if [ ! -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ]; then
        echo "Installing Zap (Zsh Plugin Manager)..."
        zsh <(curl -s https://raw.githubusercontent.com/zap-zsh/zap/master/install.zsh) --branch release-v1 --keep
    fi
}

install_packages() {
    if command -v brew >/dev/null 2>&1; then
        brew install starship zoxide eza bat fzf fastfetch tmux
    elif command -v apt-get >/dev/null 2>&1; then
        sudo apt-get update
        sudo apt-get install -y zoxide fzf bat fastfetch tmux eza 2>/dev/null || sudo apt-get install -y zoxide fzf batcat tmux
        if ! command -v starship &> /dev/null; then curl -sS https://starship.rs/install.sh | sh -s -- -y; fi
    fi
}

# Run Installations
check_and_install_zsh
set_default_shell
install_packages
install_zap

echo ""
echo "======================================"
echo "    Symlinking configurations..."
echo "======================================"

# 1. Zsh & Starship
create_symlink "$DOTFILES_DIR/zsh/.zshrc" "$HOME/.zshrc"
create_symlink "$DOTFILES_DIR/zsh/starship.toml" "$HOME/.config/starship.toml"

# 2. Tmux
create_symlink "$DOTFILES_DIR/tmux/tmux.conf" "$HOME/.tmux.conf"
if tmux info &>/dev/null; then
    tmux source-file "$HOME/.tmux.conf"
    echo "  • Reloaded running tmux server"
fi

# 3. WezTerm
create_symlink "$DOTFILES_DIR/wezterm/wezterm.lua" "$HOME/.config/wezterm/wezterm.lua"

echo ""
echo "✔ Setup complete! Please restart your terminal."
