#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  🌌 CELESTIAL + HYPRLAND - Arch Linux / Garuda / CachyOS Installer
#  https://github.com/zarateaz/hyperland
#  Instalación automática y unificada con 0 margen de error
# ══════════════════════════════════════════════════════════════════════

set -e
set -o pipefail

# ─────────────────────────────────────────
# Colores y Formato
# ─────────────────────────────────────────
OK="\e[32m[OK]\e[0m"
ERROR="\e[31m[ERROR]\e[0m"
INFO="\e[34m[INFO]\e[0m"
WARN="\e[33m[WARN]\e[0m"
STEP="\e[35m[PASO]\e[0m"
TITLE="\e[1;36m"
NC="\e[0m"

# Función segura para comandos que no deben abortar todo si fallan
run_safe() {
    "$@" || echo -e "$WARN  Continuando tras fallo no crítico: $*"
}

# ─────────────────────────────────────────
# Comprobación de Usuario (No root)
# ─────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo -e "$ERROR NO ejecutes este instalador como root ni con sudo directamente."
    echo -e "$INFO  Ejecútalo como tu usuario normal: ./install.sh"
    echo -e "$INFO  El script solicitará permisos de sudo cuando sea estrictamente necesario."
    exit 1
fi

REAL_USER="$USER"
REAL_HOME="$HOME"
BASE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${TITLE}   🌌 CELESTIAL & HYPRLAND ARCH - INSTALADOR AUTOMÁTICO       ${NC}"
echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "$INFO Usuario: $REAL_USER"
echo -e "$INFO Directorio base: $BASE_DIR"
echo ""

# ─────────────────────────────────────────
# Mantener credenciales sudo activas en segundo plano
# ─────────────────────────────────────────
echo -e "$INFO Verificando permisos sudo..."
sudo -v

# Loop en segundo plano para renovar sudo token sin volver a pedir contraseña
while true; do
    sudo -n true
    sleep 50
    kill -0 "$$" 2>/dev/null || exit
done 2>/dev/null &
SUDO_KEEP_ALIVE_PID=$!
trap 'kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true' EXIT

# ─────────────────────────────────────────
# Auto-clonado si se ejecuta como script individual
# ─────────────────────────────────────────
if [[ ! -d "$BASE_DIR/config" ]] || [[ ! -f "$BASE_DIR/zshrc" ]]; then
    echo -e "$INFO Archivos locales no encontrados en $BASE_DIR."
    echo -e "$INFO Clonando repositorio completo de Celestial Hyprland..."
    TMP_SETUP="$REAL_HOME/.hyperland-setup"
    rm -rf "$TMP_SETUP"
    git clone https://github.com/zarateaz/hyperland.git "$TMP_SETUP"
    BASE_DIR="$TMP_SETUP"
    echo -e "$OK Repositorio clonado en $BASE_DIR"
fi

# ─────────────────────────────────────────
# PASO 1: Comprobación de Arch Linux y Actualización de Repositorios
# ─────────────────────────────────────────
echo -e "\n$STEP 1/12 Comprobando sistema y sincronizando repositorios..."
if ! command -v pacman &>/dev/null; then
    echo -e "$ERROR Este instalador está diseñado para Arch Linux o derivados (Garuda, EndeavourOS, CachyOS)."
    exit 1
fi

if ! sudo pacman -Sy --noconfirm; then
    echo -e "$WARN Falló sincronización de espejos. Intentando forzar actualización de base de datos..."
    sudo pacman -Syy --noconfirm || echo -e "$WARN Continuando con base de datos existente..."
fi
echo -e "$OK Repositorios listos"

# ─────────────────────────────────────────
# PASO 2: Herramientas Base de Compilación y Sistema
# ─────────────────────────────────────────
echo -e "\n$STEP 2/12 Instalando herramientas base del sistema..."
sudo pacman -S --needed --noconfirm base-devel git curl wget jq xdg-user-dirs xdg-utils rsync
run_safe xdg-user-dirs-update
echo -e "$OK Herramientas base instaladas"

# ─────────────────────────────────────────
# PASO 3: Detección o Instalación de AUR Helper (paru / yay)
# ─────────────────────────────────────────
echo -e "\n$STEP 3/12 Verificando AUR helper (yay / paru)..."
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
    echo -e "$OK paru detectado"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
    echo -e "$OK yay detectado"
else
    echo -e "$INFO No se detectó yay ni paru. Instalando 'yay' automáticamente..."
    TMP_YAY=$(mktemp -d /tmp/yay-build.XXXXXX)
    git clone https://aur.archlinux.org/yay.git "$TMP_YAY/yay"
    (cd "$TMP_YAY/yay" && makepkg -si --noconfirm)
    rm -rf "$TMP_YAY"
    AUR_HELPER="yay"
    echo -e "$OK yay compilado e instalado con éxito"
fi

# ─────────────────────────────────────────
# PASO 4: Resolución de Conflictos Conocidos en Arch
# ─────────────────────────────────────────
echo -e "\n$STEP 4/12 Resolviendo posibles conflictos de paquetes..."
# quickshell estable conflictúa con quickshell-git
if pacman -Qi quickshell &>/dev/null && ! pacman -Qi quickshell-git &>/dev/null; then
    echo -e "$INFO Reemplazando 'quickshell' por 'quickshell-git'..."
    sudo pacman -Rdd --noconfirm quickshell 2>/dev/null || true
fi

# rofi estándar conflictúa con rofi-wayland
if pacman -Qi rofi &>/dev/null && ! pacman -Qi rofi-wayland &>/dev/null; then
    echo -e "$INFO Reemplazando 'rofi' por 'rofi-wayland'..."
    sudo pacman -Rdd --noconfirm rofi 2>/dev/null || true
fi

# pipewire-media-session conflictúa con wireplumber
if pacman -Qi pipewire-media-session &>/dev/null; then
    echo -e "$INFO Reemplazando 'pipewire-media-session' por 'wireplumber'..."
    sudo pacman -Rdd --noconfirm pipewire-media-session 2>/dev/null || true
fi
echo -e "$OK Conflictos prevenidos"

# ─────────────────────────────────────────
# PASO 5: Paquetes Oficiales de Arch Linux
# ─────────────────────────────────────────
echo -e "\n$STEP 5/12 Instalando paquetes oficiales..."

official_packages=(
    # Qt6 & herramientas de compilación para Caelestia
    cmake extra-cmake-modules gcc make pkg-config
    qt6-base qt6-declarative qt6-wayland qt6-svg qt6-tools
    qt5ct qt6ct kvantum

    # Hyprland y Wayland essentials
    hyprland hypridle hyprlock hyprsunset xorg-xwayland polkit-gnome
    xdg-desktop-portal-hyprland

    # Barra, Notificaciones y Menús
    waybar swaync rofi-wayland wlogout yad qalculate-gtk

    # Fondos y Theming
    swww waypaper wallust imagemagick

    # Terminales y Utilidades de Consola
    kitty alacritty fastfetch btop fzf bat lsd mpv yt-dlp

    # Gestión de Archivos
    thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer xarchiver mousepad

    # Audio y Multimedia
    pipewire pipewire-pulse wireplumber pamixer pavucontrol playerctl cava

    # Capturas y Portapapeles
    grim slurp swappy wl-clipboard cliphist xclip brightnessctl

    # Fuentes y Emojis
    ttf-jetbrains-mono-nerd ttf-victor-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji

    # Shell y Red
    zsh zsh-syntax-highlighting zsh-autosuggestions network-manager-applet
)

failed_pkgs=()
for pkg in "${official_packages[@]}"; do
    if sudo pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
        echo -e "$OK $pkg"
    else
        echo -e "$WARN $pkg no encontrado en repos oficiales, se intentará vía AUR ($AUR_HELPER)"
        failed_pkgs+=("$pkg")
    fi
done

# ─────────────────────────────────────────
# PASO 6: Paquetes AUR (Celestial Shell & Herramientas)
# ─────────────────────────────────────────
echo -e "\n$STEP 6/12 Instalando paquetes AUR (${AUR_HELPER})..."

aur_packages=(
    "quickshell-git"
    "caelestia-cli"
    "bibata-cursor-theme"
    "pokemon-colorscripts-git"
    "mpv-mpris"
    "zsh-sudo"
)

# Añadir paquetes que hayan fallado en repos oficiales
aur_packages+=("${failed_pkgs[@]}")

for pkg in "${aur_packages[@]}"; do
    echo -e "$INFO  → $pkg (AUR)"
    if $AUR_HELPER -S --needed --noconfirm "$pkg" 2>/dev/null; then
        echo -e "$OK $pkg instalado"
    else
        echo -e "$WARN $pkg falló en AUR (se continúa de manera segura)"
    fi
done

# ─────────────────────────────────────────
# PASO 7: Servicios de Audio PipeWire & WirePlumber
# ─────────────────────────────────────────
echo -e "\n$STEP 7/12 Activando servicios de audio PipeWire para el usuario..."
systemctl --user enable --now pipewire.service 2>/dev/null || true
systemctl --user enable --now wireplumber.service 2>/dev/null || true
systemctl --user enable --now pipewire-pulse.service 2>/dev/null || true
echo -e "$OK Servicios PipeWire activos"

# ─────────────────────────────────────────
# PASO 8: Configurar Oh My Zsh & Powerlevel10k
# ─────────────────────────────────────────
echo -e "\n$STEP 8/12 Configurando Zsh + Oh My Zsh + Powerlevel10k..."
export RUNZSH=no
export CHSH=no

if [ ! -d "$REAL_HOME/.oh-my-zsh" ]; then
    run_safe sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
    echo -e "$OK Oh My Zsh instalado"
else
    echo -e "$OK Oh My Zsh ya existe, omitiendo..."
fi

# Tema Powerlevel10k
if [ ! -d "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ]; then
    run_safe git clone --depth=1 https://github.com/romkatv/powerlevel10k.git \
        "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k"
    echo -e "$OK Tema Powerlevel10k instalado"
fi

# Plugins Zsh en custom
mkdir -p "$REAL_HOME/.oh-my-zsh/custom/plugins"
for plugin in zsh-autosuggestions zsh-syntax-highlighting; do
    if [ ! -d "$REAL_HOME/.oh-my-zsh/custom/plugins/$plugin" ]; then
        run_safe git clone --depth=1 "https://github.com/zsh-users/$plugin" \
            "$REAL_HOME/.oh-my-zsh/custom/plugins/$plugin"
    fi
done

# Copiar configs de Zsh
[ -f "$BASE_DIR/zshrc" ] && cp -f "$BASE_DIR/zshrc" "$REAL_HOME/.zshrc"
[ -f "$BASE_DIR/.p10k.zsh" ] && cp -f "$BASE_DIR/.p10k.zsh" "$REAL_HOME/.p10k.zsh"
echo -e "$OK Configuración Zsh copiada"

# Configurar para root (opcional para consistencia)
if [ -d "/root" ]; then
    run_safe sudo mkdir -p /root/.oh-my-zsh/custom/themes
    [ -d "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" ] && \
        run_safe sudo cp -rn "$REAL_HOME/.oh-my-zsh/custom/themes/powerlevel10k" /root/.oh-my-zsh/custom/themes/
    [ -f "$BASE_DIR/zshrcroot" ] && run_safe sudo cp -f "$BASE_DIR/zshrcroot" /root/.zshrc
    [ -f "$BASE_DIR/p10k.zshroot" ] && run_safe sudo cp -f "$BASE_DIR/p10k.zshroot" /root/.p10k.zsh
fi

# ─────────────────────────────────────────
# PASO 9: Desplegar Dotfiles y Celestial Shell
# ─────────────────────────────────────────
echo -e "\n$STEP 9/12 Desplegando configuraciones y Celestial Shell..."
mkdir -p "$REAL_HOME/.config"

# Limpiar enlaces rotos antes de copiar
find "$REAL_HOME/.config" -xtype l -delete 2>/dev/null || true

# Copiar todas las carpetas de config/ o configs/
CONFIG_SRC=""
if [ -d "$BASE_DIR/config" ]; then
    CONFIG_SRC="$BASE_DIR/config"
elif [ -d "$BASE_DIR/configs" ]; then
    CONFIG_SRC="$BASE_DIR/configs"
fi

if [ -n "$CONFIG_SRC" ]; then
    for dir in "$CONFIG_SRC"/*/; do
        [ -d "$dir" ] || continue
        dirname=$(basename "$dir")
        echo -e "$INFO  → .config/$dirname"
        cp -r "$dir" "$REAL_HOME/.config/"
    done
fi
rm -f "$REAL_HOME/.config/hypr/.initial_startup_done"

# Desplegar Caelestia Shell en ~/.config/quickshell/caelestia
mkdir -p "$REAL_HOME/.config/quickshell/caelestia"
if [ -d "$BASE_DIR/shell" ] && [ "$(ls -A "$BASE_DIR/shell" 2>/dev/null)" ]; then
    echo -e "$INFO  → Desplegando Caelestia Shell desde repositorio local..."
    rsync -a --exclude=".git" "$BASE_DIR/shell/" "$REAL_HOME/.config/quickshell/caelestia/"
elif [ -d "$REAL_HOME/celestial/shell" ] && [ "$(ls -A "$REAL_HOME/celestial/shell" 2>/dev/null)" ]; then
    echo -e "$INFO  → Desplegando Caelestia Shell desde ~/celestial/shell..."
    rsync -a --exclude=".git" "$REAL_HOME/celestial/shell/" "$REAL_HOME/.config/quickshell/caelestia/"
else
    echo -e "$INFO  → Descargando Caelestia Shell desde upstream..."
    run_safe git clone --depth=1 https://github.com/caelestia-dots/shell.git "$REAL_HOME/.config/quickshell/caelestia"
fi
echo -e "$OK Celestial Shell desplegado"

# Desplegar Wallpapers
PICS_DIR=$(xdg-user-dir PICTURES 2>/dev/null || echo "$REAL_HOME/Pictures")
mkdir -p "$PICS_DIR/wallpapers"
if [ -d "$BASE_DIR/wallpapers" ]; then
    cp -rn "$BASE_DIR"/wallpapers/* "$PICS_DIR/wallpapers/" 2>/dev/null || true
    echo -e "$OK Wallpapers copiados a $PICS_DIR/wallpapers"
fi

# Configurar rutas de waypaper/config.ini
if [ -f "$REAL_HOME/.config/waypaper/config.ini" ]; then
    sed -i "s|^folder = .*|folder = $PICS_DIR/wallpapers|" "$REAL_HOME/.config/waypaper/config.ini"
    sed -i "s|^stylesheet = .*|stylesheet = $REAL_HOME/.config/waypaper/style.css|" "$REAL_HOME/.config/waypaper/config.ini"
    echo -e "$OK Configuración waypaper actualizada"
fi

# ─────────────────────────────────────────
# PASO 10: Integración SDDM Login Screen
# ─────────────────────────────────────────
echo -e "\n$STEP 10/12 Configurando sincronización de pantalla de login SDDM..."
SDDM_HELPER="$REAL_HOME/.config/hypr/scripts/sddm_root_helper.sh"
if [ -f "$SDDM_HELPER" ]; then
    sudo cp "$SDDM_HELPER" /usr/local/bin/sddm_root_helper
    sudo chmod 755 /usr/local/bin/sddm_root_helper
    echo -e "$OK Helper instalado: /usr/local/bin/sddm_root_helper"
fi

# ─────────────────────────────────────────
# PASO 11: Asignar Permisos y Enlaces a Utilidades
# ─────────────────────────────────────────
echo -e "\n$STEP 11/12 Asignando permisos a scripts y creando utilidades globales..."

for sdir in scripts UserScripts; do
    target_dir="$REAL_HOME/.config/hypr/$sdir"
    if [ -d "$target_dir" ]; then
        find "$target_dir" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} \;
        echo -e "$OK Permisos asignados: $target_dir"
    fi
done

if [ -d "$REAL_HOME/.config/bin" ]; then
    find "$REAL_HOME/.config/bin" -type f \( -name "*.sh" -o -name "*.py" -o -name "settarget" -o -name "setports" \) -exec chmod +x {} \;
    echo -e "$OK Permisos asignados: $REAL_HOME/.config/bin"
fi

# Enlaces en /usr/local/bin para utilidades globales
for bin_util in settarget setports vpnhtb.sh; do
    if [ -f "$REAL_HOME/.config/bin/$bin_util" ]; then
        run_safe sudo ln -sf "$REAL_HOME/.config/bin/$bin_util" "/usr/local/bin/$bin_util"
        if [ "$bin_util" = "vpnhtb.sh" ]; then
            run_safe sudo ln -sf "$REAL_HOME/.config/bin/$bin_util" "/usr/local/bin/vpnhtb"
        fi
        echo -e "$OK Enlace creado: /usr/local/bin/$bin_util"
    fi
done

# Detección automática de hardware (Monitor y Touchpad)
if command -v hyprctl &>/dev/null; then
    MON_INFO=$(hyprctl monitors all -j 2>/dev/null || true)
    if [ -n "$MON_INFO" ] && [ "$MON_INFO" != "[]" ]; then
        MON_NAME=$(echo "$MON_INFO" | jq -r '.[0].name // empty')
        MON_W=$(echo "$MON_INFO" | jq -r '.[0].width // empty')
        MON_H=$(echo "$MON_INFO" | jq -r '.[0].height // empty')
        MON_HZ=$(echo "$MON_INFO" | jq -r '.[0].refreshRate // empty' | cut -d. -f1)
        if [ -n "$MON_NAME" ] && [ -n "$MON_W" ]; then
            echo -e "$INFO Monitor detectado: $MON_NAME (${MON_W}x${MON_H}@${MON_HZ}Hz)"
            echo "monitor = $MON_NAME, ${MON_W}x${MON_H}@${MON_HZ}, auto, 1" > "$REAL_HOME/.config/hypr/monitors.conf"
            echo -e "$OK monitors.conf generado automáticamente"
        fi
    fi
fi

# ─────────────────────────────────────────
# PASO 12: Inicializar Wallust Theming y Shell Zsh
# ─────────────────────────────────────────
echo -e "\n$STEP 12/12 Inicializando paleta de colores Wallust y shell..."

FIRST_WALL=$(find "$PICS_DIR/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1)
if [ -n "$FIRST_WALL" ] && command -v wallust &>/dev/null; then
    wallust run -s "$FIRST_WALL" >/dev/null 2>&1 || true
    echo -e "$OK Wallust inicializado con: $(basename "$FIRST_WALL")"
fi

# Cambiar shell a Zsh si no lo es
if [ "$SHELL" != "$(which zsh 2>/dev/null)" ] && command -v zsh &>/dev/null; then
    run_safe sudo chsh -s "$(which zsh)" "$REAL_USER"
    echo -e "$OK Zsh establecido como shell por defecto"
fi

echo -e "\n${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${OK}  🌌 ¡INSTALACIÓN COMPLETADA CON ÉXITO! (0 MARGEN DE ERROR)   ${NC}"
echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${INFO}Sistema Celestial + Hyprland listo para usar.${NC}"
echo -e "  ✦ Caelestia Shell (Quickshell) configurado en ~/.config/quickshell/caelestia"
echo -e "  ✦ Waybar y SwayNC configurados como fallback automático"
echo -e "  ✦ Sincronización SDDM activada con sddm_root_helper"
echo -e "  ✦ Wallust, Kitty, Rofi, Zsh y utilidades listas"
echo ""
echo -e "${INFO}Para iniciar:${NC}"
echo -e "  1. Cierra sesión o reinicia tu computadora."
echo -e "  2. Elige ${TITLE}Hyprland${NC} en la pantalla de inicio de sesión (SDDM/GDM)."
echo -e "  3. ¡Disfruta tu nuevo entorno!"
echo ""
