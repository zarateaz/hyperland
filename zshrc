# Fix the Java Problem
export _JAVA_AWT_WM_NONREPARENTING=1

# Enable Powerlevel10k instant prompt. Should stay at the top of ~/.zshrc.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
  source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# Path to Oh My Zsh
export ZSH="$HOME/.oh-my-zsh"
ZSH_THEME="powerlevel10k/powerlevel10k"

plugins=(git sudo)

source $ZSH/oh-my-zsh.sh

setopt histignorealldups sharehistory

# Use emacs keybindings even if our EDITOR is set to vi
bindkey -e

# Keep 1000 lines of history within the shell and save it to ~/.zsh_history:
HISTSIZE=1000
SAVEHIST=1000
HISTFILE=~/.zsh_history

# ──────────────────────────────────────────────
# 🌌 COMPLETION SYSTEM & FZF-TAB (HUD FUTURISTA)
# ──────────────────────────────────────────────
autoload -Uz compinit
compinit -d ~/.zcompdump

setopt ALWAYS_TO_END
setopt AUTO_MENU
setopt COMPLETE_IN_WORD

zstyle ':completion:*' auto-description 'specify: %d'
zstyle ':completion:*' completer _expand _complete _correct _approximate
zstyle ':completion:*' format '\e[1;36m[Completing %d]\e[0m'
zstyle ':completion:*' group-name ''
zstyle ':completion:*' matcher-list '' 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=* l:|=*'
zstyle ':completion:*' verbose true
zstyle ':completion:*:default' list-colors ${(s.:.)LS_COLORS}

# FZF Neon Cyber Theme
export FZF_DEFAULT_OPTS=" --color=bg+:#1e2030,bg:#0a0f18,spinner:#ff007f,hl:#00f0ff --color=fg:#cdd6f4,header:#ff007f,info:#bd93f9,pointer:#00f0ff --color=marker:#00ff9f,fg+:#ffffff,prompt:#00f0ff,hl+:#00f0ff --prompt='󰍉 ' --pointer='󱐋 ' --marker='󰸞 ' --border=rounded"

# Cargar fzf-tab (Menu flotante interactivo con vista previa)
if [ -f "$HOME/.oh-my-zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh" ]; then
    source "$HOME/.oh-my-zsh/custom/plugins/fzf-tab/fzf-tab.plugin.zsh"
fi

zstyle ':fzf-tab:*' switch-group '<' '>'
zstyle ':fzf-tab:complete:cd:*' fzf-preview 'eza -1 --icons=always --color=always $realpath 2>/dev/null'
zstyle ':fzf-tab:complete:(cat|bat|nano|vim|nvim|mousepad):*' fzf-preview 'bat --color=always --line-range :50 $realpath 2>/dev/null || cat $realpath 2>/dev/null'
zstyle ':completion:*:*:*:*:processes' command "ps -u $USER -o pid,user,%cpu,%mem,command -w -w"
zstyle ':fzf-tab:complete:(kill|pkill|killall):*' fzf-preview '[[ $group == "[process ID]" ]] && ps -p $word -o pid,user,%cpu,%mem,command -w -w 2>/dev/null'
zstyle ':fzf-tab:complete:(kill|pkill|killall):*' fzf-flags --preview-window=down:3:wrap
zstyle ':fzf-tab:complete:git-(checkout|switch|diff):*' fzf-preview 'git log --oneline --graph --color=always $word 2>/dev/null'

# To customize prompt, run `p10k configure` or edit ~/.p10k.zsh.
[[ -f ~/.p10k.zsh ]] && source ~/.p10k.zsh

# ──────────────────────────────────────────────
# PATH (Kali Linux)
# ──────────────────────────────────────────────
export PATH="$HOME/.config/bin:$HOME/.local/bin:$HOME/.cargo/bin:/usr/local/bin:/usr/bin:/bin:/usr/local/sbin:/usr/sbin:/sbin"

# ──────────────────────────────────────────────
# Aliases (en Kali bat se llama 'batcat'; el instalador crea el enlace 'bat')
# ──────────────────────────────────────────────
if command -v eza &>/dev/null; then
    alias ls='eza --icons=always --color=always --group-directories-first'
    alias ll='eza -lh --icons=always --color=always --git --group-directories-first'
    alias la='eza -a --icons=always --color=always --group-directories-first'
    alias lla='eza -lha --icons=always --color=always --git --group-directories-first'
    alias tree='eza --tree --icons=always'
else
    alias ls='lsd --icon=always --group-dirs=first'
    alias ll='lsd -lh --icon=always --group-dirs=first'
    alias la='lsd -a --icon=always --group-dirs=first'
    alias lla='lsd -lha --icon=always --group-dirs=first'
fi
if command -v bat &>/dev/null; then
    alias cat='bat --paging=never'
    alias catnl='bat'
elif command -v batcat &>/dev/null; then
    alias bat='batcat'
    alias cat='batcat --paging=never'
    alias catnl='batcat'
fi
alias catn='/bin/cat'
if command -v pacman &>/dev/null; then
    if command -v paru &>/dev/null; then
        alias update='paru -Syu'
    elif command -v yay &>/dev/null; then
        alias update='yay -Syu'
    else
        alias update='sudo pacman -Syu'
    fi
elif command -v apt &>/dev/null; then
    alias update='sudo apt update && sudo apt full-upgrade -y'
fi

# FZF
if [ -f ~/.fzf.zsh ]; then
    source ~/.fzf.zsh
elif [ -f /usr/share/fzf/key-bindings.zsh ]; then
    source /usr/share/fzf/key-bindings.zsh
    [ -f /usr/share/fzf/completion.zsh ] && source /usr/share/fzf/completion.zsh
elif [ -f /usr/share/doc/fzf/examples/key-bindings.zsh ]; then
    source /usr/share/doc/fzf/examples/key-bindings.zsh
    [ -f /usr/share/doc/fzf/examples/completion.zsh ] && source /usr/share/doc/fzf/examples/completion.zsh
fi

# ──────────────────────────────────────────────
# ⚡ AUTOSUGGESTIONS & SYNTAX HIGHLIGHTING
# ──────────────────────────────────────────────
# zsh-autosuggestions: texto de sugerencia en blanco brillante (#ffffff,bold)
ZSH_AUTOSUGGEST_HIGHLIGHT_STYLE='fg=#ffffff,bold'
ZSH_AUTOSUGGEST_STRATEGY=(history completion)
ZSH_AUTOSUGGEST_BUFFER_MAX_SIZE=50

if [ -f "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh" ]; then
    source "$HOME/.oh-my-zsh/custom/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh"
elif [ -f /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh/plugins/zsh-autosuggestions/zsh-autosuggestions.zsh
elif [ -f /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ]; then
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
fi

# Atajos ultra rápidos para aceptar sugerencias:
bindkey '^ ' autosuggest-accept        # Ctrl + Espacio: aceptar sugerencia completa
bindkey '^E' autosuggest-accept        # Ctrl + E: aceptar sugerencia completa
bindkey '^[[C' forward-char            # Flecha Derecha: avanzar / aceptar
bindkey '^[OC' forward-char            # Flecha Derecha (numpad/kitty)
bindkey '^[[1;5C' forward-word         # Ctrl + Flecha Derecha: aceptar palabra por palabra
bindkey '^[[F' end-of-line             # Tecla Fin: aceptar sugerencia completa

# Paleta Neón Cyberpunk de alta visibilidad para zsh-syntax-highlighting
typeset -gA ZSH_HIGHLIGHT_STYLES
ZSH_HIGHLIGHT_STYLES[command]='fg=#00ff9f,bold'             # Comandos válidos en verde neón brillante
ZSH_HIGHLIGHT_STYLES[builtin]='fg=#00f0ff,bold'             # Builtins (cd, echo, etc) en cian neón
ZSH_HIGHLIGHT_STYLES[alias]='fg=#00f0ff,bold'               # Aliases en cian neón
ZSH_HIGHLIGHT_STYLES[function]='fg=#38bdf8,bold'            # Funciones en celeste vibrante
ZSH_HIGHLIGHT_STYLES[unknown-token]='fg=#ff4365,bold'       # Comandos inválidos/errores en rojo neón
ZSH_HIGHLIGHT_STYLES[reserved-word]='fg=#c084fc,bold'       # Palabras clave (if, for, etc) en violeta
ZSH_HIGHLIGHT_STYLES[single-hyphen-option]='fg=#ffd166,bold'   # Banderas cortas (-la) en amarillo oro
ZSH_HIGHLIGHT_STYLES[double-hyphen-option]='fg=#ffd166,bold'   # Banderas largas (--all) en amarillo oro
ZSH_HIGHLIGHT_STYLES[single-quoted-argument]='fg=#ffe082'   # Strings '...' en amarillo suave
ZSH_HIGHLIGHT_STYLES[double-quoted-argument]='fg=#ffe082'   # Strings "..." en amarillo suave
ZSH_HIGHLIGHT_STYLES[dollar-quoted-argument]='fg=#ffe082'
ZSH_HIGHLIGHT_STYLES[path]='fg=#67e8f9,underline'           # Rutas existentes en cian subrayado
ZSH_HIGHLIGHT_STYLES[path_prefix]='fg=#67e8f9'
ZSH_HIGHLIGHT_STYLES[globbing]='fg=#ff007f,bold'            # Wildcards (*.txt) en fucsia neón
ZSH_HIGHLIGHT_STYLES[history-expansion]='fg=#00f0ff,bold'
ZSH_HIGHLIGHT_STYLES[command-substitution]='fg=#c084fc'
ZSH_HIGHLIGHT_STYLES[redirection]='fg=#ff007f,bold'         # Redirecciones (> >> |) en fucsia
ZSH_HIGHLIGHT_STYLES[assign]='fg=#00ff9f,bold'              # Variables VAR=val
ZSH_HIGHLIGHT_STYLES[comment]='fg=#6272a4,italic'           # Comentarios

# zsh-syntax-highlighting (DEBE cargarse al final)
if [ -f "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ]; then
    source "$HOME/.oh-my-zsh/custom/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
elif [ -f /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh/plugins/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
elif [ -f /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ]; then
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
fi

# zsh-sudo (descargado por install.sh)
if [ -f /usr/share/zsh-sudo/sudo.plugin.zsh ]; then
    source /usr/share/zsh-sudo/sudo.plugin.zsh
fi

# ──────────────────────────────────────────────
# Functions
# ──────────────────────────────────────────────
function mkt(){
    mkdir -p {nmap,content,exploits,scripts}
}

# Extract nmap information
function extractPorts(){
    ports="$(cat "$1" | grep -oP '\d{1,5}/open' | awk '{print $1}' FS='/' | xargs | tr ' ' ',')"
    ip_address="$(cat "$1" | grep -oP '\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}' | sort -u | head -n 1)"
    echo -e "\n[*] Extracting information...\n" > extractPorts.tmp
    echo -e "\t[*] IP Address: $ip_address"  >> extractPorts.tmp
    echo -e "\t[*] Open ports: $ports\n"  >> extractPorts.tmp
    if command -v wl-copy &>/dev/null; then
        echo -n "$ports" | wl-copy
    elif command -v xclip &>/dev/null; then
        echo -n "$ports" | xclip -sel clip
    fi
    echo -e "[*] Ports copied to clipboard\n"  >> extractPorts.tmp
    cat extractPorts.tmp; rm -f extractPorts.tmp
}

# settarget
function settarget(){
    if [ -x "$HOME/.config/bin/settarget" ]; then
        "$HOME/.config/bin/settarget" "$@"
    elif [ -x /usr/local/bin/settarget ]; then
        /usr/local/bin/settarget "$@"
    elif [ $# -eq 1 ]; then
        echo "$1" > ~/.config/bin/target
    elif [ $# -gt 2 ]; then
        echo "settarget [IP] [NAME] | settarget [IP]"
    else
        echo "$1" "$2" > ~/.config/bin/target
    fi
}

# setports
function setports(){
    if [ -x "$HOME/.config/bin/setports" ]; then
        "$HOME/.config/bin/setports" "$@"
    elif [ -x /usr/local/bin/setports ]; then
        /usr/local/bin/setports "$@"
    else
        echo "$@" > ~/.config/bin/ports
        echo "Ports fijados: $@"
    fi
}

# Set 'man' colors
function man() {
    env \
    LESS_TERMCAP_mb=$'\e[01;31m' \
    LESS_TERMCAP_md=$'\e[01;31m' \
    LESS_TERMCAP_me=$'\e[0m' \
    LESS_TERMCAP_se=$'\e[0m' \
    LESS_TERMCAP_so=$'\e[01;44;33m' \
    LESS_TERMCAP_ue=$'\e[0m' \
    LESS_TERMCAP_us=$'\e[01;32m' \
    man "$@"
}

# fzf improvement
function fzf-lovely(){
    if [ "$1" = "h" ]; then
        fzf -m --reverse --preview-window down:20 --preview '[[ $(file --mime {}) =~ binary ]] &&
                    echo {} is a binary file ||
                     (bat --style=numbers --color=always {} ||
                      highlight -O ansi -l {} ||
                      cat {}) 2> /dev/null | head -500'
    else
        fzf -m --preview '[[ $(file --mime {}) =~ binary ]] &&
                         echo {} is a binary file ||
                         (bat --style=numbers --color=always {} ||
                          highlight -O ansi -l {} ||
                          cat {}) 2> /dev/null | head -500'
    fi
}

function rmk(){
    shred -zun 10 -v $1
}

# Finalize Powerlevel10k instant prompt. Should stay at the bottom of ~/.zshrc.
(( ! ${+functions[p10k-instant-prompt-finalize]} )) || p10k-instant-prompt-finalize

bindkey "^[[H" beginning-of-line
bindkey "^[[F" end-of-line
bindkey "^[[3~" delete-char
bindkey "^[[1;3C" forward-word
bindkey "^[[1;3D" backward-word


# Added by Antigravity CLI installer
export PATH="$HOME/.local/bin:$PATH"
