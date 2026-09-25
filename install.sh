#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  Hyprland Dotfiles - Instalador para Kali Linux (kali-rolling)
#  https://github.com/zarateaz/hyperland-kalilinux
# ══════════════════════════════════════════════════════════════════════

set -e          # salir si hay error crítico
set -o pipefail # detectar errores en pipes

# ─────────────────────────────────────────
# Colores y prefijos
# ─────────────────────────────────────────
OK="\e[32m[OK]\e[0m"
ERROR="\e[31m[ERROR]\e[0m"
INFO="\e[34m[INFO]\e[0m"
WARN="\e[33m[WARN]\e[0m"
STEP="\e[35m[PASO]\e[0m"

# Función segura para continuar aunque falle algo no crítico
run_safe() {
    "$@" || echo -e "$WARN  Falló (no crítico): $*"
}

# apt sin preguntas (evita diálogos de debconf / needrestart)
export DEBIAN_FRONTEND=noninteractive
export NEEDRESTART_MODE=a
APT="sudo DEBIAN_FRONTEND=noninteractive NEEDRESTART_MODE=a apt-get -y -o Dpkg::Options::=--force-confdef -o Dpkg::Options::=--force-confold"

# ¿El paquete existe en los repos configurados?
pkg_available() {
    LC_ALL=C apt-cache policy "$1" 2>/dev/null | grep -q 'Candidate: [^(]'
}

# Instala el primer paquete disponible de una lista "a|b|c"
apt_install_any() {
    local alt
    IFS='|' read -ra alts <<< "$1"
    for alt in "${alts[@]}"; do
        if pkg_available "$alt" && $APT install "$alt" >/dev/null 2>&1; then
            echo -e "$OK $alt"
            return 0
        fi
    done
    return 1
}

# ─────────────────────────────────────────
# NO ejecutar como root
# ─────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo -e "$ERROR NO ejecutes este script como root o con sudo."
    echo -e "$INFO  Ejecuta como usuario normal: bash install.sh"
    exit 1
fi

# ─────────────────────────────────────────
# Verificar que estamos en Kali (o derivado de Debian)
# ─────────────────────────────────────────
if ! command -v apt-get &>/dev/null; then
    echo -e "$ERROR Este instalador es para Kali Linux (apt). No se encontró apt-get."
    exit 1
fi
. /etc/os-release
if [ "${ID:-}" != "kali" ]; then
    echo -e "$WARN Distro detectada: ${PRETTY_NAME:-desconocida}. Este script está pensado para Kali Linux."
    echo -e "$WARN Se continuará, pero algunos paquetes podrían no existir."
fi

# ─────────────────────────────────────────
# Variables
# ─────────────────────────────────────────
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="$USER"
REAL_HOME="$HOME"
BUILD_DIR="$REAL_HOME/.hypr-kali-build"

echo -e "$INFO Usuario detectado: $REAL_USER"
echo -e "$INFO Directorio del script: $BASE_DIR"
echo ""

# ─────────────────────────────────────────
# PASO 1: Actualizar sistema
# ─────────────────────────────────────────
echo -e "$STEP 1/12 Actualizando repositorios del sistema..."
sudo apt-get update
if ! $APT full-upgrade; then
    echo -e "$WARN Falló la actualización completa (apt full-upgrade). Continuando con los paquetes actuales..."
fi

# ─────────────────────────────────────────
# PASO 2: Dependencias base (siempre necesarias)
# ─────────────────────────────────────────
echo -e "$STEP 2/12 Instalando dependencias base..."
$APT install git build-essential curl wget unzip xz-utils xdg-user-dirs \
    ca-certificates pkg-config cargo pipx python3 python3-gi python3-pil \
    fontconfig jq bc libnotify-bin

# ─────────────────────────────────────────
# Auto-clonado si se ejecuta como script individual (sin repositorio local)
# ─────────────────────────────────────────
if [[ ! -f "$BASE_DIR/zshrc" ]] || [[ ! -d "$BASE_DIR/config" ]] || [[ ! -d "$BASE_DIR/wallpapers" ]]; then
    echo -e "$INFO No se encontraron los archivos locales del repositorio."
    echo -e "$INFO Clonando el repositorio completo de GitHub..."
    TMP_REPO="$REAL_HOME/.hyperland-setup"
    rm -rf "$TMP_REPO"
    git clone https://github.com/zarateaz/hyperland-kalilinux.git "$TMP_REPO"
    BASE_DIR="$TMP_REPO"
    echo -e "$OK Repositorio clonado en $BASE_DIR"
fi

# ─────────────────────────────────────────
# PASO 3: Paquetes de los repos de Kali
#   "a|b" = se instala el primero que exista (nombres cambian entre versiones)
# ─────────────────────────────────────────
echo -e "$STEP 3/12 Instalando paquetes de los repositorios de Kali..."

# Críticos: sin estos no hay escritorio
critical=(hyprland xdg-desktop-portal-hyprland waybar kitty)

packages=(
    # Sistema base Hyprland
    hyprland
    hypridle
    hyprlock
    "hyprpolkitagent|policykit-1-gnome|polkit-kde-agent-1"
    xdg-desktop-portal-hyprland
    xdg-desktop-portal-gtk

    # Wayland utilities
    grim
    slurp
    swappy
    swww
    wl-clipboard
    cliphist
    xclip

    # Audio (PipeWire stack)
    pipewire
    pipewire-pulse
    wireplumber
    pamixer
    pavucontrol
    playerctl

    # Bar y notificaciones
    waybar
    sway-notification-center

    # Apariencia
    qt-style-kvantum
    nwg-look
    qt5ct
    qt6ct

    # Terminales y utilidades
    kitty
    fastfetch
    btop
    fzf
    bat
    lsd
    imagemagick
    mpv
    mpv-mpris
    yt-dlp

    # Gestión de archivos
    thunar
    thunar-archive-plugin
    thunar-volman
    tumbler
    ffmpegthumbnailer
    xarchiver
    mousepad

    # Red, bluetooth y display
    network-manager-gnome
    blueman
    nwg-displays
    brightnessctl
    nvtop

    # Rofi y menús (rofi >= 2.0 ya soporta Wayland)
    "rofi-wayland|rofi"
    wlogout
    yad
    qalculate-gtk

    # Shell
    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions

    # Fuentes (JetBrains Mono Nerd se descarga en el paso 4)
    fonts-noto
    fonts-noto-color-emoji
    fonts-jetbrains-mono
    fonts-font-awesome

    # Extras (si no existen en apt, se compilan/instalan en el paso 4)
    cava
    wallust
    pyprland
    waypaper
    quickshell
)

failed_pkgs=()
for pkg in "${packages[@]}"; do
    if ! apt_install_any "$pkg"; then
        echo -e "$WARN $pkg → no disponible en los repos de Kali"
        failed_pkgs+=("$pkg")
    fi
done

missing_critical=()
for pkg in "${critical[@]}"; do
    dpkg -s "$pkg" &>/dev/null || missing_critical+=("$pkg")
done
if [ "${#missing_critical[@]}" -gt 0 ]; then
    echo -e "$ERROR No se pudieron instalar paquetes críticos: ${missing_critical[*]}"
    echo -e "$INFO  Verifica /etc/apt/sources.list (debe tener: deb http://http.kali.org/kali kali-rolling main contrib non-free non-free-firmware)"
    exit 1
fi

# ─────────────────────────────────────────
# PASO 4: Lo que no está en apt (equivalente a los paquetes AUR)
# ─────────────────────────────────────────
echo -e "$STEP 4/12 Instalando herramientas que no están en los repos de Kali..."

rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"
export PATH="$REAL_HOME/.cargo/bin:$PATH"

# Instala un binario de cargo en /usr/local/bin para que Hyprland lo encuentre
cargo_to_system() {
    for bin in "$@"; do
        [ -x "$REAL_HOME/.cargo/bin/$bin" ] && sudo install -m 755 "$REAL_HOME/.cargo/bin/$bin" /usr/local/bin/
    done
}

# pipx global (binarios en /usr/local/bin)
pipx_global() {
    sudo PIPX_HOME=/opt/pipx PIPX_BIN_DIR=/usr/local/bin pipx install "$@"
}

# bat en Debian/Kali se llama 'batcat'
if ! command -v bat &>/dev/null && command -v batcat &>/dev/null; then
    sudo ln -sf "$(command -v batcat)" /usr/local/bin/bat
    echo -e "$OK Enlace bat → batcat creado"
fi

# swww (fondos de pantalla)
if ! command -v swww &>/dev/null; then
    echo -e "$INFO  → swww (compilando con cargo)"
    run_safe $APT install liblz4-dev libxkbcommon-dev libwayland-dev wayland-protocols
    if cargo install --locked --git https://github.com/LGFae/swww --tag v0.9.5 swww swww-daemon; then
        cargo_to_system swww swww-daemon
        echo -e "$OK swww"
    else
        echo -e "$WARN swww falló (se continúa de todos modos)"
    fi
fi

# wallust (colores a partir del wallpaper)
if ! command -v wallust &>/dev/null; then
    echo -e "$INFO  → wallust (compilando con cargo)"
    if cargo install --locked wallust; then
        cargo_to_system wallust
        echo -e "$OK wallust"
    else
        echo -e "$WARN wallust falló (se continúa de todos modos)"
    fi
fi

# pyprland
if ! command -v pypr &>/dev/null; then
    echo -e "$INFO  → pyprland (pipx)"
    run_safe pipx_global pyprland
fi

# waypaper (necesita GTK del sistema → --system-site-packages)
if ! command -v waypaper &>/dev/null; then
    echo -e "$INFO  → waypaper (pipx)"
    run_safe $APT install gir1.2-gtk-3.0
    run_safe pipx_global --system-site-packages waypaper
fi

# pokemon-colorscripts
if ! command -v pokemon-colorscripts &>/dev/null; then
    echo -e "$INFO  → pokemon-colorscripts"
    if git clone --depth=1 https://gitlab.com/phoneybadger/pokemon-colorscripts.git "$BUILD_DIR/pokemon-colorscripts"; then
        (cd "$BUILD_DIR/pokemon-colorscripts" && sudo ./install.sh) && echo -e "$OK pokemon-colorscripts" \
            || echo -e "$WARN pokemon-colorscripts falló"
    fi
fi

# zsh-sudo (en Arch venía del AUR)
if [ ! -f /usr/share/zsh-sudo/sudo.plugin.zsh ]; then
    echo -e "$INFO  → zsh-sudo"
    sudo mkdir -p /usr/share/zsh-sudo
    run_safe sudo curl -fsSL -o /usr/share/zsh-sudo/sudo.plugin.zsh \
        https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/plugins/sudo/sudo.plugin.zsh
fi

# JetBrains Mono Nerd Font
if ! fc-list | grep -qi "JetBrainsMono Nerd"; then
    echo -e "$INFO  → JetBrains Mono Nerd Font"
    if wget -q -O "$BUILD_DIR/JetBrainsMono.tar.xz" \
        https://github.com/ryanoasis/nerd-fonts/releases/latest/download/JetBrainsMono.tar.xz; then
        sudo mkdir -p /usr/local/share/fonts/JetBrainsMonoNerd
        sudo tar -xJf "$BUILD_DIR/JetBrainsMono.tar.xz" -C /usr/local/share/fonts/JetBrainsMonoNerd
        sudo fc-cache -f >/dev/null
        echo -e "$OK JetBrains Mono Nerd Font"
    else
        echo -e "$WARN No se pudo descargar JetBrains Mono Nerd Font"
    fi
fi

# quickshell no está empaquetado en Kali: es opcional (overview de escritorio)
if ! command -v qs &>/dev/null; then
    echo -e "$WARN quickshell no está disponible en Kali; el overview de escritorio (qs) quedará desactivado"
fi

rm -rf "$BUILD_DIR"

# ─────────────────────────────────────────
# PASO 5: Servicios de audio (PipeWire) para el usuario
# ─────────────────────────────────────────
echo -e "$STEP 5/12 Activando PipeWire para el usuario..."
run_safe systemctl --user enable pipewire pipewire-pulse wireplumber


# ─────────────────────────────────────────
# PASO 6: Oh My Zsh + Powerlevel10k (usuario normal)
# ─────────────────────────────────────────
echo -e "$STEP 6/12 Configurando Zsh + Oh My Zsh + Powerlevel10k..."

export RUNZSH=no
export CHSH=no

if [ ! -d "$REAL_HOME/.oh-my-zsh" ]; then
    run_safe sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo -e "$OK Oh My Zsh instalado"
else
    echo -e "$OK Oh My Zsh ya existe, omitiendo..."
fi

if [ ! -d "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    run_safe git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    echo -e "$OK Powerlevel10k instalado"
else
    echo -e "$OK Powerlevel10k ya existe, omitiendo..."
fi

# ─────────────────────────────────────────
# PASO 7: Oh My Zsh + Powerlevel10k (root)
# ─────────────────────────────────────────
echo -e "$STEP 7/12 Configurando Zsh para root..."

if [ ! -d "/root/.oh-my-zsh" ]; then
    run_safe sudo bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    run_safe sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        /root/.oh-my-zsh/custom/themes/powerlevel10k
    echo -e "$OK Oh My Zsh + Powerlevel10k para root instalados"
else
    echo -e "$OK Oh My Zsh root ya existe, omitiendo..."
fi

# ─────────────────────────────────────────
# PASO 8: Validar archivos necesarios antes de copiar
# ─────────────────────────────────────────
echo -e "$STEP 8/12 Validando archivos de configuración..."

missing=0
for file in zshrc .p10k.zsh zshrcroot p10k.zshroot; do
    if [[ ! -f "$BASE_DIR/$file" ]]; then
        echo -e "$ERROR Falta el archivo requerido: $BASE_DIR/$file"
        missing=1
    fi
done

if [[ "$missing" -eq 1 ]]; then
    echo -e "$ERROR Faltan archivos necesarios. ¿Clonaste el repositorio completo?"
    exit 1
fi
echo -e "$OK Todos los archivos requeridos están presentes"

# ─────────────────────────────────────────
# PASO 9: Copiar configs de Zsh
# ─────────────────────────────────────────
echo -e "$STEP 9/12 Copiando configuración Zsh..."

cp -fv "$BASE_DIR/zshrc"     "$REAL_HOME/.zshrc"
cp -fv "$BASE_DIR/.p10k.zsh" "$REAL_HOME/.p10k.zsh"

run_safe sudo cp -fv "$BASE_DIR/zshrcroot"   /root/.zshrc
run_safe sudo cp -fv "$BASE_DIR/p10k.zshroot" /root/.p10k.zsh

echo -e "$OK Configuración Zsh copiada"

# ─────────────────────────────────────────
# PASO 10: Copiar dotfiles / configuración
# ─────────────────────────────────────────
echo -e "$STEP 10/12 Copiando dotfiles..."

mkdir -p "$REAL_HOME/.config"

# Limpiar enlaces simbólicos rotos (dangling symlinks) para evitar errores con cp
find "$REAL_HOME/.config" -type l ! -exec test -e {} \; -delete 2>/dev/null || true

for dir in "$BASE_DIR"/config/*/; do
    dirname=$(basename "$dir")
    echo -e "$INFO  → .config/$dirname"
    cp -r "$dir" "$REAL_HOME/.config/"
done

# Wallpapers
PICS_DIR=$(xdg-user-dir PICTURES 2>/dev/null || echo "$REAL_HOME/Pictures")
mkdir -p "$PICS_DIR"
if [ -d "$BASE_DIR/wallpapers" ]; then
    cp -r "$BASE_DIR/wallpapers" "$PICS_DIR/"
    echo -e "$OK Wallpapers copiados a $PICS_DIR/wallpapers"
fi

# Compatibilidad para scripts que buscan ~/Pictures
if [ "$PICS_DIR" != "$REAL_HOME/Pictures" ]; then
    mkdir -p "$REAL_HOME/Pictures"
    ln -sf "$PICS_DIR/wallpapers" "$REAL_HOME/Pictures/wallpapers"
    echo -e "$OK Creado enlace simbólico ~/Pictures/wallpapers para compatibilidad"
fi

# Archivos extra en home (zsh_historyroot → ~/.zsh_historyroot)
for f in zsh_historyroot; do
    if [ -f "$BASE_DIR/$f" ]; then
        cp -v "$BASE_DIR/$f" "$REAL_HOME/.${f}"
        echo -e "$OK $f copiado a ~/.$f"
    fi
done

# ─────────────────────────────────────────
# Detección y configuración automática de hardware (Monitor, Lockscreen y Touchpad)
# ─────────────────────────────────────────
echo -e "$STEP 10b/12 Detectando y configurando hardware automáticamente..."

# 1. Configuración de Pantalla (Monitor)
MONITORS_CONF="$REAL_HOME/.config/hypr/monitors.conf"
mkdir -p "$(dirname "$MONITORS_CONF")"

cat <<EOF > "$MONITORS_CONF"
# Autogenerated Monitor Configuration
# See https://wiki.hyprland.org/Configuring/Monitors/
EOF

found_any=0
max_height=0

for status_file in /sys/class/drm/*/status; do
    if [ -f "$status_file" ]; then
        status=$(cat "$status_file")
        if [ "$status" = "connected" ]; then
            connector=$(basename "$(dirname "$status_file")" | cut -d'-' -f2-)
            modes_file="$(dirname "$status_file")/modes"
            if [ -f "$modes_file" ]; then
                pref_mode=$(head -n 1 "$modes_file")
                if [ -n "$pref_mode" ]; then
                    echo "monitor = $connector, $pref_mode, auto, 1" >> "$MONITORS_CONF"
                    echo -e "$OK Pantalla detectada: $connector ($pref_mode)"
                    found_any=1
                    
                    height=$(echo "$pref_mode" | cut -d'x' -f2 | grep -o '^[0-9]\+')
                    if [ -n "$height" ] && [ "$height" -gt "$max_height" ]; then
                        max_height=$height
                    fi
                fi
            fi
        fi
    fi
done

if [ "$found_any" -eq 0 ]; then
    echo "monitor = , preferred, auto, 1" >> "$MONITORS_CONF"
    echo -e "$WARN No se detectaron pantallas conectadas. Usando configuración genérica."
    max_height=1080
fi

# 2. Adaptar la configuración de hyprlock según la resolución
if [ "$max_height" -ge 1080 ]; then
    echo -e "$INFO Pantalla de alta resolución ($max_height px de alto). Aplicando hyprlock para resoluciones >= 1080p."
    if [ -f "$BASE_DIR/config/hypr/hyprlock-2k.conf" ]; then
        cp -fv "$BASE_DIR/config/hypr/hyprlock-2k.conf" "$REAL_HOME/.config/hypr/hyprlock.conf"
    fi
else
    echo -e "$INFO Pantalla estándar ($max_height px de alto). Aplicando hyprlock para resoluciones < 1080p."
    if [ -f "$BASE_DIR/config/hypr/hyprlock.conf" ]; then
        cp -fv "$BASE_DIR/config/hypr/hyprlock.conf" "$REAL_HOME/.config/hypr/hyprlock.conf"
    fi
fi

# 3. Detectar y configurar el Touchpad automáticamente en Laptops.conf
echo -e "$INFO Detectando Touchpad..."
TOUCHPAD_NAME=$(grep -i 'touchpad' /proc/bus/input/devices | head -n 1 | cut -d'"' -f2 | tr '[:upper:]' '[:lower:]' | tr ' ' '-')
if [ -n "$TOUCHPAD_NAME" ]; then
    echo -e "$OK Touchpad detectado: $TOUCHPAD_NAME"
    if [ -f "$REAL_HOME/.config/hypr/UserConfigs/Laptops.conf" ]; then
        sed -i "s/\$Touchpad_Device=.*/\$Touchpad_Device=$TOUCHPAD_NAME/g" "$REAL_HOME/.config/hypr/UserConfigs/Laptops.conf"
        echo -e "$OK Touchpad configurado en Laptops.conf"
    fi
else
    echo -e "$WARN No se pudo detectar el touchpad automáticamente"
fi

# ─────────────────────────────────────────
# PASO 11: Permisos a scripts de Hypr
# ─────────────────────────────────────────
echo -e "$STEP 11/12 Asignando permisos a scripts..."

for dir in \
    "$REAL_HOME/.config/hypr/scripts" \
    "$REAL_HOME/.config/hypr/UserScripts"
do
    if [ -d "$dir" ]; then
        find "$dir" -type f -name "*.sh" -exec chmod +x {} \;
        echo -e "$OK Permisos asignados: $dir"
    fi
done

# ─────────────────────────────────────────
# PASO 12: Cambiar shell por defecto a Zsh
# ─────────────────────────────────────────
echo -e "$STEP 12/12 Estableciendo Zsh como shell predeterminado..."

ZSH_PATH="$(command -v zsh)"
if [ -n "$ZSH_PATH" ]; then
    # Asegurarse de que zsh esté en /etc/shells
    if ! grep -qx "$ZSH_PATH" /etc/shells; then
        echo "$ZSH_PATH" | sudo tee -a /etc/shells > /dev/null
        echo -e "$OK $ZSH_PATH agregado a /etc/shells"
    fi
    sudo chsh -s "$ZSH_PATH" "$REAL_USER"
    run_safe sudo chsh -s "$ZSH_PATH" root
    echo -e "$OK Shell cambiado a zsh ($ZSH_PATH)"
else
    echo -e "$WARN zsh no encontrado en PATH, omitiendo cambio de shell"
fi

# Directorios XDG
xdg-user-dirs-update 2>/dev/null || true
echo -e "$OK Directorios XDG actualizados"

# ─────────────────────────────────────────
# Resumen final
# ─────────────────────────────────────────
echo ""
echo -e "\e[32m╔══════════════════════════════════════════════════════════╗\e[0m"
echo -e "\e[32m║  ✅  ¡Instalación completa!                              ║\e[0m"
echo -e "\e[32m║                                                          ║\e[0m"
echo -e "\e[32m║  Próximos pasos:                                         ║\e[0m"
echo -e "\e[32m║  → Cierra sesión y vuelve a entrar (o reinicia)          ║\e[0m"
echo -e "\e[32m║  → Selecciona Hyprland en tu gestor de login             ║\e[0m"
echo -e "\e[32m╚══════════════════════════════════════════════════════════╝\e[0m"
echo ""

if [ "${#failed_pkgs[@]}" -gt 0 ]; then
    echo -e "$WARN Paquetes que no estaban en apt (revisa que sus alternativas se hayan instalado):"
    printf '       - %s\n' "${failed_pkgs[@]}"
fi
