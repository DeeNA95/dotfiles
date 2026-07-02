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
        echo "Detected Homebrew. Installing packages..."
        brew install starship zoxide eza bat fzf fastfetch tmux
    elif command -v apt-get >/dev/null 2>&1; then
        echo "Detected apt-get. Installing packages..."
        sudo apt-get update

        # Try to install eza via official repo if not already available
        if ! command -v eza &> /dev/null; then
            echo "Setting up eza community repository..."
            sudo mkdir -p /etc/apt/keyrings
            wget -qO- https://raw.githubusercontent.com/eza-community/eza/main/deb.asc | sudo gpg --dearmor --yes -o /etc/apt/keyrings/gierdot.gpg
            echo "deb [signed-by=/etc/apt/keyrings/gierdot.gpg] http://deb.gierdot.net/ stable main" | sudo tee /etc/apt/sources.list.d/gierdot.list
            sudo apt-get update
        fi

        sudo apt-get install -y zoxide fzf bat fastfetch eza tmux 2>/dev/null || sudo apt-get install -y zoxide fzf batcat tmux

        # starship recommendation for linux is script
        if ! command -v starship &> /dev/null; then
             curl -sS https://starship.rs/install.sh | sh -s -- -y
        fi

        # fix bat command name on ubuntu if installed as batcat
        if command -v batcat >/dev/null 2>&1 && ! command -v bat >/dev/null 2>&1; then
            mkdir -p ~/.local/bin
            ln -sf /usr/bin/batcat ~/.local/bin/bat
        fi

    elif command -v dnf >/dev/null 2>&1; then
        echo "Detected dnf. Installing packages..."
        sudo dnf install -y starship zoxide eza bat fzf fastfetch tmux
    elif command -v pacman >/dev/null 2>&1; then
        echo "Detected pacman. Installing packages..."
        sudo pacman -S --noconfirm starship zoxide eza bat fzf fastfetch tmux
    elif command -v conda >/dev/null 2>&1; then
        echo "Detected Conda. Installing packages..."
        conda install -y -c conda-forge starship zoxide bat fzf eza tmux
    else
        echo "No supported package manager found. Attempting manual installs..."
        # Starship
        if ! command -v starship &> /dev/null; then
             curl -sS https://starship.rs/install.sh | sh -s -- -y
        fi
        # Zoxide
        if ! command -v zoxide &> /dev/null; then
            curl -sS https://raw.githubusercontent.com/ajeetdsouza/zoxide/main/install.sh | bash
        fi
    fi

    # Universal fallback for eza
    if ! command -v eza &> /dev/null; then
        echo "eza not found. Attempting universal fallbacks..."
        if command -v cargo >/dev/null 2>&1; then
            echo "Installing eza via cargo..."
            rustc_version=$(rustc --version | awk '{print $2}')
            if [[ "$rustc_version" < "1.82.0" ]]; then
                cargo install eza --version 0.20.18
            else
                cargo install eza
            fi
        else
            echo "Cargo not found. Attempting to download pre-compiled binary from GitHub..."
            ARCH=$(uname -m)
            OS=$(uname -s)
            
            if [ "$OS" = "Linux" ]; then
                if [ "$ARCH" = "x86_64" ]; then
                    EZA_URL="https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-unknown-linux-gnu.tar.gz"
                elif [ "$ARCH" = "aarch64" ]; then
                    EZA_URL="https://github.com/eza-community/eza/releases/latest/download/eza_aarch64-unknown-linux-gnu.tar.gz"
                fi
            elif [ "$OS" = "Darwin" ]; then
                if [ "$ARCH" = "x86_64" ]; then
                    EZA_URL="https://github.com/eza-community/eza/releases/latest/download/eza_x86_64-apple-darwin.tar.gz"
                elif [ "$ARCH" = "arm64" ]; then
                    EZA_URL="https://github.com/eza-community/eza/releases/latest/download/eza_aarch64-apple-darwin.tar.gz"
                fi
            fi

            if [ -n "${EZA_URL:-}" ]; then
                echo "Downloading from $EZA_URL ..."
                TMP_DIR=$(mktemp -d)
                if curl -sL "$EZA_URL" | tar xz -C "$TMP_DIR"; then
                    mkdir -p "$HOME/.local/bin"
                    mv "$TMP_DIR/eza" "$HOME/.local/bin/eza"
                    chmod +x "$HOME/.local/bin/eza"
                    echo "eza installed to $HOME/.local/bin/eza"
                else
                    echo "Failed to download or extract eza."
                fi
                rm -rf "$TMP_DIR"
            else
                echo "Could not determine appropriate binary for OS=$OS ARCH=$ARCH."
            fi
        fi
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
