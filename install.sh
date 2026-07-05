#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  Hyprland Dotfiles - Instalador para Arch Linux / Garuda Linux
#  https://github.com/espinalclark/Hyprland-Kali
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

# ─────────────────────────────────────────
# NO ejecutar como root
# ─────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo -e "$ERROR NO ejecutes este script como root o con sudo."
    echo -e "$INFO  Ejecuta como usuario normal: bash install.sh"
    exit 1
fi

# ─────────────────────────────────────────
# Variables
# ─────────────────────────────────────────
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REAL_USER="$USER"
REAL_HOME="$HOME"

echo -e "$INFO Usuario detectado: $REAL_USER"
echo -e "$INFO Directorio del script: $BASE_DIR"
echo ""

# ─────────────────────────────────────────
# PASO 1: Actualizar sistema
# ─────────────────────────────────────────
echo -e "$STEP 1/12 Actualizando repositorios del sistema..."
sudo pacman -Syu --noconfirm

# ─────────────────────────────────────────
# PASO 2: Dependencias base (siempre necesarias)
# ─────────────────────────────────────────
echo -e "$STEP 2/12 Instalando dependencias base..."
sudo pacman -S --needed --noconfirm git base-devel curl wget xdg-user-dirs

# ─────────────────────────────────────────
# Auto-clonado si se ejecuta como script individual (sin repositorio local)
# ─────────────────────────────────────────
if [[ ! -f "$BASE_DIR/zshrc" ]] || [[ ! -d "$BASE_DIR/config" ]] || [[ ! -d "$BASE_DIR/wallpapers" ]]; then
    echo -e "$INFO No se encontraron los archivos locales del repositorio."
    echo -e "$INFO Clonando el repositorio completo de GitHub..."
    TMP_REPO="$REAL_HOME/.hyperland-setup"
    rm -rf "$TMP_REPO"
    git clone https://github.com/zarateaz/hyperland.git "$TMP_REPO"
    BASE_DIR="$TMP_REPO"
    echo -e "$OK Repositorio clonado en $BASE_DIR"
fi

# ─────────────────────────────────────────
# PASO 3: Instalar AUR helper (yay o paru)
#   Garuda ya trae paru, Arch normalmente no tiene ninguno
# ─────────────────────────────────────────
echo -e "$STEP 3/12 Verificando AUR helper..."

AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    echo -e "$OK paru detectado (modo Garuda)"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    echo -e "$OK yay ya está instalado"
else
    echo -e "$INFO Instalando yay (AUR helper)..."
    YAY_TMP="$REAL_HOME/.yay-build"
    rm -rf "$YAY_TMP"
    mkdir -p "$YAY_TMP"
    git clone https://aur.archlinux.org/yay.git "$YAY_TMP/yay"
    pushd "$YAY_TMP/yay" > /dev/null
    makepkg -si --noconfirm
    popd > /dev/null
    rm -rf "$YAY_TMP"
    AUR_HELPER="yay"
    echo -e "$OK yay instalado correctamente"
fi

# ─────────────────────────────────────────
# PASO 4: Paquetes oficiales de Arch/Garuda
#   Separados en grupos para mejor diagnóstico
# ─────────────────────────────────────────
echo -e "$STEP 4/12 Instalando paquetes oficiales..."

packages=(
    # Sistema base Hyprland
    hyprland
    hypridle
    hyprlock
    hyprpolkitagent
    xdg-desktop-portal-hyprland

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
    swaync

    # Apariencia
    kvantum
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
    yt-dlp

    # Gestión de archivos
    thunar
    thunar-archive-plugin
    thunar-volman
    tumbler
    ffmpegthumbnailer
    xarchiver
    mousepad

    # Red y display
    network-manager-applet
    nwg-displays
    brightnessctl
    nvtop

    # Rofi y menús
    rofi-wayland
    wlogout
    yad
    qalculate-gtk

    # Shell
    zsh
    zsh-syntax-highlighting
    zsh-autosuggestions

    # Fuentes
    ttf-jetbrains-mono-nerd
    noto-fonts
    noto-fonts-emoji

    # Extras
    cava
    wallust
    pyprland
    waypaper
)

failed_pkgs=()
for pkg in "${packages[@]}"; do
    if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
        echo -e "$OK $pkg"
    else
        echo -e "$WARN $pkg → no encontrado en repos oficiales, se intentará con AUR"
        failed_pkgs+=("$pkg")
    fi
done

# ─────────────────────────────────────────
# PASO 5: Paquetes exclusivos de AUR
# ─────────────────────────────────────────
echo -e "$STEP 5/12 Instalando paquetes AUR..."

aur_packages=(
    "pokemon-colorscripts-git"
    "quickshell-git"
    "mpv-mpris"
    "zsh-sudo"
)

# Agregar los que fallaron en repos oficiales
aur_packages+=("${failed_pkgs[@]}")

for pkg in "${aur_packages[@]}"; do
    echo -e "$INFO  → $pkg (AUR)"
    if $AUR_HELPER -S --needed --noconfirm "$pkg" 2>/dev/null; then
        echo -e "$OK $pkg"
    else
        echo -e "$WARN $pkg falló en AUR (se continúa de todos modos)"
    fi
done

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
echo -e "\e[32m║  → Si usas Garuda: el tema ya está listo                 ║\e[0m"
echo -e "\e[32m╚══════════════════════════════════════════════════════════╝\e[0m"
echo ""
