 #!/bin/bash

# Configuration
CONFIG_DIR="$HOME/.config/nvim"
LOCAL_DIR="$HOME/.local"
LOCAL_BIN="$LOCAL_DIR/bin"
NVIM_PYTHON_ENV="$LOCAL_DIR/share/nvim/python3"
NVIM_VERSION="0.11.6"

echo "🚀 Starting Neovim configuration setup..."

# 1. Ensure local bin directory exists
mkdir -p "$LOCAL_BIN"

# Function to check Neovim version
check_nvim_version() {
    if command -v nvim >/dev/null 2>&1; then
        # Extract version number (e.g., 0.11.6)
        CURRENT_VERSION=$(nvim --version | head -n 1 | grep -oE '[0-9]+\.[0-9]+\.[0-9]+')
        if [ "$(printf '%s\n' "$NVIM_VERSION" "$CURRENT_VERSION" | sort -V | head -n1)" = "$NVIM_VERSION" ]; then
            echo "✅ Neovim $CURRENT_VERSION already installed (>= $NVIM_VERSION)."
            return 0
        fi
    fi
    return 1
}

# Function to install Neovim
install_nvim() {
    OS="$(uname -s)"
    ARCH="$(uname -m)"

    echo "📦 Installing Neovim $NVIM_VERSION for $OS ($ARCH)..."

    if [ "$OS" = "Linux" ]; then
        if [ "$ARCH" = "x86_64" ]; then
            echo "🐧 Ensuring FUSE is installed for AppImage support..."
            if command -v apt-get >/dev/null 2>&1; then
                # Ubuntu 24.04 uses libfuse2t64, older use libfuse2
                sudo apt-get update && sudo apt-get install -y libfuse2t64 || sudo apt-get install -y libfuse2
            fi
            echo "⬇️ Downloading Neovim AppImage..."
            curl -LO "https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-linux-x86_64.appimage"
            chmod +x nvim-linux-x86_64.appimage
            mv nvim-linux-x86_64.appimage "$LOCAL_BIN/nvim"
            echo "✅ Neovim $NVIM_VERSION AppImage installed to $LOCAL_BIN/nvim"
            return 0
        fi
    fi

    # Fallback/Default for macOS or other Linux architectures
    DOWNLOAD_URL=""
    case "$OS" in
        Darwin)
            if [ "$ARCH" = "arm64" ]; then
                DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-macos-arm64.tar.gz"
            else
                DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-macos-x86_64.tar.gz"
            fi
            ;;
        Linux)
            if [ "$ARCH" = "aarch64" ] || [ "$ARCH" = "arm64" ]; then
                DOWNLOAD_URL="https://github.com/neovim/neovim/releases/download/v$NVIM_VERSION/nvim-linux-arm64.tar.gz"
            fi
            ;;
    esac

    if [ -z "$DOWNLOAD_URL" ]; then
        echo "❌ Error: Unsupported OS/Architecture for tarball fallback: $OS/$ARCH"
        exit 1
    fi

    TEMP_DIR=$(mktemp -d)
    echo "⬇️ Downloading Neovim from $DOWNLOAD_URL..."
    if ! curl -LO --output-dir "$TEMP_DIR" "$DOWNLOAD_URL"; then
        echo "❌ Error: Failed to download Neovim."
        rm -rf "$TEMP_DIR"
        exit 1
    fi

    echo "📂 Extracting Neovim..."
    tar -xzf "$TEMP_DIR"/*.tar.gz -C "$TEMP_DIR"
    EXTRACTED_DIR=$(find "$TEMP_DIR" -maxdepth 1 -type d -name "nvim-*" | head -n 1)
    cp -r "$EXTRACTED_DIR"/* "$LOCAL_DIR/"
    rm -rf "$TEMP_DIR"
    echo "✅ Neovim $NVIM_VERSION installed successfully."
}

# Function to check LuaRocks version
check_luarocks_version() {
    if command -v luarocks >/dev/null 2>&1; then
        LUAROCKS_INFO=$(luarocks --version 2>&1)
        if echo "$LUAROCKS_INFO" | grep -q "Lua 5.1"; then
            echo "✅ LuaRocks targeting Lua 5.1 already installed."
            return 0
        fi
    fi
    return 1
}

# Function to install LuaRocks 5.1
install_luarocks() {
    OS="$(uname -s)"
    echo "📦 Installing LuaRocks targeting Lua 5.1 for $OS..."

    case "$OS" in
        Darwin)
            if command -v brew >/dev/null 2>&1; then
                echo "🍺 Using Homebrew to install LuaRocks..."
                brew install luarocks
            else
                echo "❌ Error: Homebrew not found. Please install Homebrew or install LuaRocks 5.1 manually."
                exit 1
            fi
            ;;
        Linux)
            echo "🐧 Installing LuaRocks and Lua 5.1 via package manager..."
            if command -v apt-get >/dev/null 2>&1; then
                sudo apt-get update && sudo apt-get install -y luarocks lua5.1 liblua5.1-0-dev
            elif command -v dnf >/dev/null 2>&1; then
                sudo dnf install -y luarocks lua-devel
            elif command -v yum >/dev/null 2>&1; then
                sudo yum install -y luarocks
            else
                echo "❌ Error: Unsupported Linux package manager. Please install LuaRocks 5.1 manually."
                exit 1
            fi
            ;;
    esac
}

install_rust_components() {
    if ! command -v rustup >/dev/null 2>&1; then
        echo "⚠️ rustup not found. Install Rust from https://rustup.rs/ for rustfmt and clippy support."
        return 0
    fi

    echo "📦 Ensuring Rust formatter and linter components are installed..."
    rustup component add rustfmt clippy
}

install_notebook_python() {
    if ! command -v uv >/dev/null 2>&1; then
        echo "❌ uv is required for the Neovim Python provider and notebook tools."
        return 1
    fi

    if [ ! -x "$NVIM_PYTHON_ENV/bin/python" ]; then
        echo "📦 Creating the Neovim Python environment with uv..."
        uv venv "$NVIM_PYTHON_ENV"
    fi

    echo "📦 Installing the Molten and Jupytext Python dependencies with uv..."
    uv pip install --python "$NVIM_PYTHON_ENV/bin/python" --upgrade \
        pynvim jupyter-client ipykernel nbformat jupytext
}

register_molten_plugin() {
    MOLTEN_DIR="$LOCAL_DIR/share/nvim/lazy/molten-nvim"
    if [ ! -d "$MOLTEN_DIR" ]; then
        echo "ℹ️ Molten will register when lazy.nvim installs it on first launch."
        return 0
    fi

    echo "📦 Registering Molten with the isolated Neovim Python provider..."
    nvim -u NORC --headless \
        --cmd "let g:python3_host_prog='$NVIM_PYTHON_ENV/bin/python'" \
        --cmd "execute 'set runtimepath+=' . fnameescape('$MOLTEN_DIR')" \
        +UpdateRemotePlugins +qa
}

# 2. Install Neovim if needed
if ! check_nvim_version; then
    install_nvim
fi

# 2b. Install LuaRocks 5.1 if needed
if ! check_luarocks_version; then
    install_luarocks
fi

# 2c. Install Rust components used by rust-analyzer/conform.nvim
install_rust_components

# 2d. Install the isolated Python provider used by Molten and Jupytext
install_notebook_python

# 5. Add ~/.local/bin to PATH for the current session if not present
case ":$PATH:" in
    *":$LOCAL_BIN:"*) ;;
    *)
        export PATH="$LOCAL_BIN:$PATH"
        echo "⚠️ Added $LOCAL_BIN to current session PATH."
        ;;
esac

register_molten_plugin
