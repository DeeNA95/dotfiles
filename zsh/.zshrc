# Created by Zap installer
[ -f "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh" ] && source "${XDG_DATA_HOME:-$HOME/.local/share}/zap/zap.zsh"

# == Plugin configuration (must be set before the plugin loads) ==
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#565f89'

# == Plugins ==
plug "zsh-users/zsh-autosuggestions"
plug "zap-zsh/supercharge"
plug "zsh-users/zsh-history-substring-search"
plug "zsh-users/zsh-completions"
zmodload zsh/langinfo  # web-search's omz_urlencode needs $langinfo[CODESET]
plug "zap-zsh/web-search"
# NOTE: syntax-highlighting must be sourced last, after all other ZLE plugins.
plug "zsh-users/zsh-syntax-highlighting"

# Docker CLI completions (fpath must be set before compinit)
fpath=(/Users/dna/.docker/completions $fpath)

# Load and initialise completion system (once)
autoload -Uz compinit
mkdir -p "$HOME/.cache/zsh"
compinit

# == Completion styling ==
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'l:|=* r:|=*'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path "$HOME/.cache/zsh/zcompcache"
zstyle ':completion:*' group-name ''
zstyle ':completion:*:descriptions' format '%F{yellow}-- %d --%f'

# == Key bindings ==
# History substring search on Up/Down
if (( ${+terminfo[kcuu1]} )); then
    bindkey "${terminfo[kcuu1]}" history-substring-search-up
    bindkey "${terminfo[kcud1]}" history-substring-search-down
else
    bindkey '^[[A' history-substring-search-up
    bindkey '^[[B' history-substring-search-down
fi

# == Terminal settings ==
export TERM=xterm-256color
export LANG=en_US.UTF-8

# == History settings ==
HISTSIZE=10000
SAVEHIST=10000
setopt HIST_IGNORE_DUPS
setopt HIST_REDUCE_BLANKS
setopt HIST_VERIFY
setopt EXTENDED_HISTORY
setopt SHARE_HISTORY

# == Shell behaviour ==
setopt AUTO_CD
setopt INTERACTIVE_COMMENTS
setopt NO_BEEP

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

if [ -f "$HOME/google-cloud-sdk/path.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/path.zsh.inc"
fi
if [ -f "$HOME/google-cloud-sdk/completion.zsh.inc" ]; then
    source "$HOME/google-cloud-sdk/completion.zsh.inc"
fi

# == API Keys & Secrets ==
if [[ -f ~/.secrets ]]; then
    source ~/.secrets
fi

# SSH key loading (only if the agent doesn't already have identities)
if ! ssh-add -l &>/dev/null; then
    ssh-add ~/.ssh/id_ed25519_personal &>/dev/null
fi

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

# fzf (Ctrl-T files, Alt-C cd; Ctrl-R is owned by atuin below)
command -v fzf >/dev/null && eval "$(fzf --zsh)"

# Atuin (searchable, synced shell history)
command -v atuin >/dev/null && eval "$(atuin init zsh)"

# direnv (per-project environment variables)
command -v direnv >/dev/null && eval "$(direnv hook zsh)"

# thefuck (command correction, invoked as `fuck`)
command -v thefuck >/dev/null && eval "$(thefuck --alias)"

# Starship prompt (initialise last so it wraps the final prompt)
command -v starship >/dev/null && eval "$(starship init zsh)"

# == Custom functions ==
function mkcd() {
    mkdir -p "$1" && cd "$1"
}

function penny_health() {
    local url="http://127.0.0.1:42069/v1/models"
    local launch_state
    launch_state=$(launchctl print "gui/$(id -u)/ai.penny.omlx" 2>/dev/null | awk -F'= ' '/^[[:space:]]*state = / {print $2; exit}')

    if curl -fsS --max-time 3 "$url" >/dev/null 2>&1; then
        printf 'oMLX: healthy (HTTP endpoint responding)'
        [ -n "$launch_state" ] && printf ' | LaunchAgent: %s' "$launch_state"
        printf '\n'
        return 0
    fi

    printf 'oMLX: unhealthy (HTTP endpoint not responding)'
    [ -n "$launch_state" ] && printf ' | LaunchAgent: %s' "$launch_state"
    printf '\n'
    return 1
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
# fastfetch on shell start; set NO_FASTFETCH=1 to disable.
if [[ -o interactive && -z "$NO_FASTFETCH" ]] && command -v fastfetch >/dev/null; then
    fastfetch
fi

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
[ -s "$HOME/.bun/_bun" ] && source "$HOME/.bun/_bun"

# bun
export BUN_INSTALL="$HOME/.bun"
export PATH="$BUN_INSTALL/bin:$PATH"

# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"

# Added by Antigravity IDE
export PATH="$HOME/.antigravity-ide/antigravity-ide/bin:$PATH"

# opencode
export PATH=$HOME/.opencode/bin:$PATH

# == Android SDK / JDK 17 ==
export JAVA_HOME="/opt/homebrew/opt/openjdk@17/libexec/openjdk.jdk/Contents/Home"
export ANDROID_HOME="/opt/homebrew/share/android-commandlinetools"
export ANDROID_SDK_ROOT="$ANDROID_HOME"
export PATH="$JAVA_HOME/bin:$ANDROID_HOME/platform-tools:$PATH"
