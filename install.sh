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
    "pyprland"
    "wallust"
    "quickshell-git"
    "mpv-mpris"
    "zsh-sudo"
    "waypaper"
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
    sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo -e "$OK Oh My Zsh instalado"
else
    echo -e "$OK Oh My Zsh ya existe, omitiendo..."
fi

if [ ! -d "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
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
    sudo bash -c 'RUNZSH=no CHSH=no sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended'
    sudo git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
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

sudo cp -fv "$BASE_DIR/zshrcroot"   /root/.zshrc
sudo cp -fv "$BASE_DIR/p10k.zshroot" /root/.p10k.zsh

echo -e "$OK Configuración Zsh copiada"

# ─────────────────────────────────────────
# PASO 10: Copiar dotfiles / configuración
# ─────────────────────────────────────────
echo -e "$STEP 10/12 Copiando dotfiles..."

mkdir -p "$REAL_HOME/.config"

for dir in "$BASE_DIR"/config/*/; do
    dirname=$(basename "$dir")
    echo -e "$INFO  → .config/$dirname"
    cp -r "$dir" "$REAL_HOME/.config/"
done

# Wallpapers
mkdir -p "$REAL_HOME/Pictures"
if [ -d "$BASE_DIR/wallpapers" ]; then
    cp -r "$BASE_DIR/wallpapers" "$REAL_HOME/Pictures/"
    echo -e "$OK Wallpapers copiados"
fi

# Archivos extra en home (zsh_historyroot → ~/.zsh_historyroot)
for f in zsh_historyroot; do
    if [ -f "$BASE_DIR/$f" ]; then
        cp -v "$BASE_DIR/$f" "$REAL_HOME/.${f}"
        echo -e "$OK $f copiado a ~/.$f"
    fi
done

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
    sudo chsh -s "$ZSH_PATH" root
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
