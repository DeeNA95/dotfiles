# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-syntax-highlighting"
plug "zsh-users/zsh-history-substring-search"
plug "zsh-users/zsh-completions"
plug "zap-zsh/web-search"
# plug "zap-zsh/git" -- Relying on system git and manual aliases

# Load and initialise completion system
autoload -Uz compinit
compinit

# == Terminal settings ==
export TERM=xterm-256color
export LANG=en_US.UTF-8

# == History settings ==
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt SHARE_HISTORY

# == PATH configuration ==
export PATH="/opt/homebrew/bin:/opt/homebrew/sbin:$PATH"
export PATH="/usr/local/bin:/usr/bin:/bin:/usr/sbin:/sbin:$PATH"
export PATH="/Library/Frameworks/Python.framework/Versions/3.12/bin:$PATH"
export PATH="$HOME/.local/bin:$PATH"
export PATH="$HOME/.antigravity/antigravity/bin:$PATH"
export PATH="/Applications/WezTerm.app/Contents/MacOS:$PATH"

# == Google Cloud ==
export GOOGLE_GENAI_USE_VERTEXAI=true
export GOOGLE_CLOUD_PROJECT=zeta-turbine-457610-h4
export GOOGLE_CLOUD_LOCATION=us-central1

if [ -f '/Users/dna/google-cloud-sdk/path.zsh.inc' ]; then
    source '/Users/dna/google-cloud-sdk/path.zsh.inc'
fi
if [ -f '/Users/dna/google-cloud-sdk/completion.zsh.inc' ]; then
    source '/Users/dna/google-cloud-sdk/completion.zsh.inc'
fi

# == API Keys & Secrets ==
if [[ -f ~/.secrets ]]; then
    source ~/.secrets
fi

# SSH key loading
ssh-add ~/.ssh/id_ed25519_personal 2>/dev/null

# == Enhanced aliases ==
alias dna='sudo'
alias get_ip="curl -s https://ipinfo.io"
alias ..='cd ..'
alias ...='cd ../..'
alias ....='cd ../../..'
alias .....='cd ../../../..'
alias egrep='egrep --color=auto'
alias cat='bat --theme="tokyonight_night"'
alias ls='eza --icons --git --group-directories-first'
alias ll='eza -al --icons --git --group-directories-first'
alias la='eza -a --icons --git --group-directories-first'
alias lt='eza --tree --level=2 --icons'
alias preview='fzf --preview "bat --color=always --style=numbers --line-range=:500 {}"'


# == Git aliases ==
alias gs='git status'
alias ga='git add'
alias gc='git commit'
alias gp='git push'
alias gl='git pull'
alias gd='git diff'
alias gb='git branch'
alias gco='git checkout'
alias glog='git log --oneline --graph --decorate --all'

# == Docker aliases ==
alias d='docker'
alias dc='docker-compose'
alias dps='docker ps'
alias dpa='docker ps -a'
alias di='docker images'

# == Tools Initialization ==
# Zoxide (better cd)
if command -v zoxide > /dev/null; then
    unalias cd 2>/dev/null
    eval "$(zoxide init zsh --cmd cd)"
fi

# Starship prompt
eval "$(starship init zsh)"



# == Custom functions ==
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function extract() {
    if [ -f $1 ]; then
        case $1 in
            *.tar.bz2)   tar xjf $1     ;;
            *.tar.gz)    tar xzf $1     ;;
            *.bz2)       bunzip2 $1     ;;
            *.rar)       unrar e $1     ;;
            *.gz)        gunzip $1      ;;
            *.tar)       tar xf $1      ;;
            *.tbz2)      tar xjf $1     ;;
            *.tgz)       tar xzf $1     ;;
            *.zip)       unzip $1       ;;
            *.Z)         uncompress $1  ;;
            *.7z)        7z x $1        ;;
            *)     echo "'$1' cannot be extracted via extract()" ;;
        esac
    else
        echo "'$1' is not a valid file"
    fi
}

# == Startup ==
welcome_message() {
    fastfetch
}

welcome_message

# == Professional Aliases (Force Override) ==
unalias y 2>/dev/null
alias y='yazi'
alias lg='lazygit'
alias ld='lazydocker'
alias py='uv run python'
alias pip='uv pip'
alias uvv='uv venv'
alias uvr='uv run'
export PKG_CONFIG_PATH="/opt/homebrew/opt/imagemagick/lib/pkgconfig:$PKG_CONFIG_PATH"
export DYLD_LIBRARY_PATH="/opt/homebrew/opt/ffmpeg/lib:$DYLD_LIBRARY_PATH"

# bun completions
[ -s "/Users/dna/.bun/_bun" ] && source "/Users/dna/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"
# The following lines have been added by Docker Desktop to enable Docker CLI completions.
fpath=(/Users/dna/.docker/completions $fpath)
autoload -Uz compinit
compinit
# End of Docker CLI completions


# Added by Antigravity CLI installer
export PATH="/Users/dna/.local/bin:$PATH"

# Added by Antigravity IDE
export PATH="/Users/dna/.antigravity-ide/antigravity-ide/bin:$PATH"
