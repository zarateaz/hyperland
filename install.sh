#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  🌌 CELESTIAL + HYPRLAND - Instalador para Garuda Linux / Arch Linux
#  https://github.com/zarateaz/hyperland
#
#  Uso (un solo comando / un solo click, como usuario normal):
#    bash <(curl -fsSL https://raw.githubusercontent.com/zarateaz/hyperland/main/install.sh)
#  o bien:
#    git clone --depth=1 https://github.com/zarateaz/hyperland.git && cd hyperland && ./install.sh
#
#  Opciones:
#    --quick / --dots-only  Solo despliega los dotfiles y permisos (rápido, sin pacman).
#    --dry-run              No toca el sistema (sin sudo/pacman/systemctl); solo simula.
#    --no-update            No ejecuta la actualización completa del sistema (pacman -Syu).
# ══════════════════════════════════════════════════════════════════════

# Si se ejecuta mediante curl ... | bash, reconectar stdin a la terminal interactiva
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

# ─────────────────────────────────────────
# Opciones
# ─────────────────────────────────────────
DRY_RUN=0
DO_UPDATE=1
DOTS_ONLY=0

for arg in "$@"; do
    case "$arg" in
        --dry-run)            DRY_RUN=1 ;;
        --no-update)          DO_UPDATE=0 ;;
        --quick|--dots-only)  DOTS_ONLY=1 ;;
        -h|--help)            sed -n '2,17p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null; exit 0 ;;
        *)                    echo "Opción desconocida: $arg"; exit 1 ;;
    esac
done

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
TOTAL_STEPS=12

step() { echo -e "\n$STEP $1/$TOTAL_STEPS $2"; }

run_safe() {
    "$@" || { echo -e "$WARN  Continuando tras fallo no crítico: $*"; return 0; }
}

as_root() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "\e[90m  [dry-run] sudo $*\e[0m"
        return 0
    fi
    sudo "$@"
}

sys_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "\e[90m  [dry-run] $*\e[0m"
        return 0
    fi
    "$@"
}

# ─────────────────────────────────────────
# Comprobación de Usuario (No root)
# ─────────────────────────────────────────
if [ "$EUID" -eq 0 ]; then
    echo -e "$ERROR NO ejecutes este instalador como root ni con sudo."
    echo -e "$INFO  Ejecútalo como tu usuario normal: ./install.sh"
    exit 1
fi

REAL_USER="$(id -un)"
REAL_HOME="$HOME"
export PATH="$REAL_HOME/.local/bin:$REAL_HOME/.config/bin:$PATH"

SCRIPT_PATH="${BASH_SOURCE[0]:-}"
if [ -n "$SCRIPT_PATH" ] && [ -f "$SCRIPT_PATH" ]; then
    BASE_DIR="$(cd "$(dirname "$SCRIPT_PATH")" && pwd)"
else
    BASE_DIR="$PWD"
fi

TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$REAL_HOME/.hyperland-backups/$TIMESTAMP"
LOG_FILE="$REAL_HOME/hyperland-install-$TIMESTAMP.log"

mkdir -p "$(dirname "$LOG_FILE")"
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${TITLE}   🌌 CELESTIAL & HYPRLAND - INSTALADOR AUTOMÁTICO             ${NC}"
echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "$INFO Usuario: $REAL_USER  |  HOME: $REAL_HOME"
echo -e "$INFO Log: $LOG_FILE"
[ "$DRY_RUN" -eq 1 ] && echo -e "$WARN MODO --dry-run: no se modificará el sistema, solo \$HOME"
[ "$DOTS_ONLY" -eq 1 ] && echo -e "$INFO MODO --quick: solo desplegando dotfiles y configuraciones"

# ─────────────────────────────────────────
# Comprobación de distribución
# ─────────────────────────────────────────
if ! command -v pacman &>/dev/null; then
    echo -e "$ERROR Este instalador es para Arch Linux o derivados (Garuda, EndeavourOS, CachyOS)."
    exit 1
fi
DISTRO_ID="$(. /etc/os-release 2>/dev/null; echo "${ID:-arch}")"
echo -e "$INFO Distribución detectada: $DISTRO_ID"

# ─────────────────────────────────────────
# Auto-clonado / sincronización limpia si se ejecuta vía curl o fuera de la carpeta
# ─────────────────────────────────────────
TARGET_REPO="$REAL_HOME/hyperland"
if [[ ! -d "$BASE_DIR/config/hypr" ]] || [[ ! -f "$BASE_DIR/zshrc" ]]; then
    command -v git &>/dev/null || as_root pacman -S --needed --noconfirm git
    echo -e "$INFO Preparando repositorio en $TARGET_REPO ..."
    if [ -d "$TARGET_REPO/.git" ]; then
        echo -e "$INFO Repositorio existente encontrado: sincronizando limpiamente con origin/main..."
        git -C "$TARGET_REPO" fetch origin main --depth=1 2>/dev/null || git -C "$TARGET_REPO" fetch --all 2>/dev/null || true
        git -C "$TARGET_REPO" reset --hard origin/main 2>/dev/null || true
        git -C "$TARGET_REPO" clean -fd 2>/dev/null || true
    else
        rm -rf "$TARGET_REPO"
        git clone --depth=1 https://github.com/zarateaz/hyperland.git "$TARGET_REPO"
    fi
    BASE_DIR="$TARGET_REPO"
    echo -e "$OK Repositorio listo en $BASE_DIR"
fi
echo -e "$INFO Directorio base: $BASE_DIR"

# ─────────────────────────────────────────
# FUNCIÓN DE DESPLIEGUE DE DOTFILES (Ultra Limpio)
# ─────────────────────────────────────────
deploy_dotfiles() {
    echo -e "\n$INFO ─── Desplegando dotfiles y configuraciones limpias ───"
    mkdir -p "$REAL_HOME/.config" "$BACKUP_DIR/config" "$REAL_HOME/.local/bin"

    # Se excluye 'pulse' (cookie de autenticación propia de cada máquina)
    EXCLUDE_CONFIG=(pulse)
    for src in "$BASE_DIR"/config/*; do
        name="$(basename "$src")"
        [[ " ${EXCLUDE_CONFIG[*]} " == *" $name "* ]] && continue
        dst="$REAL_HOME/.config/$name"
        if [ -e "$dst" ] || [ -L "$dst" ]; then
            mkdir -p "$BACKUP_DIR/config"
            cp -a "$dst" "$BACKUP_DIR/config/$name" 2>/dev/null || true
        fi
        if [ -d "$src" ]; then
            mkdir -p "$dst"
            rsync -a --delete "$src/" "$dst/"
        else
            cp -a "$src" "$dst"
        fi
        echo -e "$INFO  → .config/$name sincronizado limpiamente"
    done

    # Forzar eliminación de marca de primer inicio para que initial-boot.sh configure wallpapers y estilos
    rm -f "$REAL_HOME/.config/hypr/.initial_startup_done"

    # Caelestia Shell (Quickshell QML)
    if [ -d "$BASE_DIR/shell" ] && [ -n "$(ls -A "$BASE_DIR/shell" 2>/dev/null)" ]; then
        mkdir -p "$REAL_HOME/.config/quickshell/caelestia"
        rsync -a --delete --exclude=".git" "$BASE_DIR/shell/" "$REAL_HOME/.config/quickshell/caelestia/" 2>/dev/null || true
        echo -e "$OK Caelestia Shell copiado en ~/.config/quickshell/caelestia"
    fi

    # Wallpapers
    PICS_XDG="$(xdg-user-dir PICTURES 2>/dev/null || echo "$REAL_HOME/Pictures")"
    if [ ! -e "$REAL_HOME/Pictures" ]; then
        if [ "$PICS_XDG" != "$REAL_HOME/Pictures" ] && [ "$PICS_XDG" != "$REAL_HOME" ] && [ -d "$PICS_XDG" ]; then
            ln -s "$PICS_XDG" "$REAL_HOME/Pictures"
        else
            mkdir -p "$REAL_HOME/Pictures"
        fi
    fi
    WALL_DIR="$REAL_HOME/Pictures/wallpapers"
    mkdir -p "$WALL_DIR"
    if [ -d "$BASE_DIR/wallpapers" ]; then
        rsync -a --ignore-existing "$BASE_DIR/wallpapers/" "$WALL_DIR/" 2>/dev/null || cp -rn "$BASE_DIR/wallpapers/"* "$WALL_DIR/" 2>/dev/null || true
        echo -e "$OK Wallpapers instalados en $WALL_DIR"
    fi

    if [ -f "$REAL_HOME/.config/waypaper/config.ini" ]; then
        sed -i "s|^folder = .*|folder = $WALL_DIR|" "$REAL_HOME/.config/waypaper/config.ini" 2>/dev/null || true
        sed -i "s|^stylesheet = .*|stylesheet = $REAL_HOME/.config/waypaper/style.css|" "$REAL_HOME/.config/waypaper/config.ini" 2>/dev/null || true
    fi

    # Zsh dotfiles
    mkdir -p "$BACKUP_DIR"
    for f in .zshrc .p10k.zsh; do
        [ -f "$REAL_HOME/$f" ] && cp -a "$REAL_HOME/$f" "$BACKUP_DIR/" 2>/dev/null || true
    done
    cp -f "$BASE_DIR/zshrc" "$REAL_HOME/.zshrc"
    [ -f "$BASE_DIR/.p10k.zsh" ] && cp -f "$BASE_DIR/.p10k.zsh" "$REAL_HOME/.p10k.zsh"
    echo -e "$OK .zshrc y .p10k.zsh desplegados"

    # Detección de Touchpad para laptops
    LAPTOPS_CONF="$REAL_HOME/.config/hypr/UserConfigs/Laptops.conf"
    TP_RAW="$( (grep -iE '^N: Name=.*touchpad' /proc/bus/input/devices 2>/dev/null || true) | sed -nE 's/^N: Name="(.*)"$/\1/p' | head -n1 || true)"
    if [ -n "$TP_RAW" ] && [ -f "$LAPTOPS_CONF" ]; then
        TP_NAME="$(echo "$TP_RAW" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
        sed -i "s|^\$Touchpad_Device=.*|\$Touchpad_Device=$TP_NAME|" "$LAPTOPS_CONF" 2>/dev/null || true
        echo -e "$OK Touchpad configurado: $TP_NAME"
    fi

    # Asignar permisos ejecutables a todos los scripts
    for d in "$REAL_HOME/.config/hypr/scripts" "$REAL_HOME/.config/hypr/UserScripts" "$REAL_HOME/.config/bin" \
             "$REAL_HOME/.config/hypr/initial-boot.sh"; do
        [ -e "$d" ] || continue
        find "$d" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} + 2>/dev/null || true
    done
    for f in settarget setports target ports; do
        [ -f "$REAL_HOME/.config/bin/$f" ] && chmod +x "$REAL_HOME/.config/bin/$f" 2>/dev/null || true
    done

    # Enlaces de compatibilidad swww <-> awww (evitando enlaces circulares)
    SYS_AWWW="$(PATH="/usr/bin:/usr/local/bin:/bin" which awww 2>/dev/null || true)"
    SYS_SWWW="$(PATH="/usr/bin:/usr/local/bin:/bin" which swww 2>/dev/null || true)"
    ACTIVE_BIN="${SYS_AWWW:-$SYS_SWWW}"

    SYS_AWWW_DAEMON="$(PATH="/usr/bin:/usr/local/bin:/bin" which awww-daemon 2>/dev/null || true)"
    SYS_SWWW_DAEMON="$(PATH="/usr/bin:/usr/local/bin:/bin" which swww-daemon 2>/dev/null || true)"
    ACTIVE_DAEMON="${SYS_AWWW_DAEMON:-$SYS_SWWW_DAEMON}"

    if [ -n "$ACTIVE_BIN" ] && [ -x "$ACTIVE_BIN" ]; then
        rm -f "$REAL_HOME/.local/bin/swww" "$REAL_HOME/.local/bin/awww"
        ln -sf "$ACTIVE_BIN" "$REAL_HOME/.local/bin/swww"
        ln -sf "$ACTIVE_BIN" "$REAL_HOME/.local/bin/awww"
        if sudo -n true 2>/dev/null; then
            sudo ln -sf "$ACTIVE_BIN" /usr/local/bin/swww 2>/dev/null || true
            sudo ln -sf "$ACTIVE_BIN" /usr/local/bin/awww 2>/dev/null || true
        fi
        echo -e "$OK Enlaces swww/awww listos -> $ACTIVE_BIN"
    fi

    if [ -n "$ACTIVE_DAEMON" ] && [ -x "$ACTIVE_DAEMON" ]; then
        rm -f "$REAL_HOME/.local/bin/swww-daemon" "$REAL_HOME/.local/bin/awww-daemon"
        ln -sf "$ACTIVE_DAEMON" "$REAL_HOME/.local/bin/swww-daemon"
        ln -sf "$ACTIVE_DAEMON" "$REAL_HOME/.local/bin/awww-daemon"
        if sudo -n true 2>/dev/null; then
            sudo ln -sf "$ACTIVE_DAEMON" /usr/local/bin/swww-daemon 2>/dev/null || true
            sudo ln -sf "$ACTIVE_DAEMON" /usr/local/bin/awww-daemon 2>/dev/null || true
        fi
    fi

    # Enlaces de brillo y volumen
    if [ -f "$REAL_HOME/.config/bin/brillo.py" ]; then
        chmod +x "$REAL_HOME/.config/bin/brillo.py"
        ln -sf "$REAL_HOME/.config/bin/brillo.py" "$REAL_HOME/.local/bin/brillo" 2>/dev/null || true
        if sudo -n true 2>/dev/null; then
            sudo ln -sf "$REAL_HOME/.config/bin/brillo.py" /usr/local/bin/brillo 2>/dev/null || true
        fi
    fi
    if [ -f "$REAL_HOME/.config/bin/volumen.py" ]; then
        chmod +x "$REAL_HOME/.config/bin/volumen.py"
        ln -sf "$REAL_HOME/.config/bin/volumen.py" "$REAL_HOME/.local/bin/volumen" 2>/dev/null || true
        if sudo -n true 2>/dev/null; then
            sudo ln -sf "$REAL_HOME/.config/bin/volumen.py" /usr/local/bin/volumen 2>/dev/null || true
        fi
    fi

    # Crear lanzador de escritorio "Instalar / Reparar Hyperland"
    DESKTOP_DIR="$(xdg-user-dir DESKTOP 2>/dev/null || echo "$REAL_HOME/Desktop")"
    [ -d "$REAL_HOME/Escritorio" ] && DESKTOP_DIR="$REAL_HOME/Escritorio"
    if [ -d "$DESKTOP_DIR" ]; then
        cat << 'EOF' > "$DESKTOP_DIR/Instalar-Hyperland.desktop"
[Desktop Entry]
Version=1.0
Type=Application
Name=Instalar Hyperland Celestial
Comment=Instalador o reparador automático para Hyperland
Exec=bash -c "if [ -f \"$HOME/hyperland/install.sh\" ]; then bash \"$HOME/hyperland/install.sh\"; else bash <(curl -fsSL https://raw.githubusercontent.com/zarateaz/hyperland/main/install.sh); fi; echo 'Presiona Enter para cerrar...'; read"
Icon=preferences-desktop-theme
Terminal=true
Categories=System;Settings;
EOF
        chmod +x "$DESKTOP_DIR/Instalar-Hyperland.desktop" 2>/dev/null || true
    fi

    echo -e "$OK Despliegue de dotfiles completado al 100%"
}

# Si solo se pidieron los dotfiles (--quick / --dots-only), desplegar y salir
if [ "$DOTS_ONLY" -eq 1 ]; then
    deploy_dotfiles
    echo -e "\n${OK}  🌌 ¡DOTFILES INSTALADOS / REPARADOS CON ÉXITO!"
    exit 0
fi

# ─────────────────────────────────────────
# Verificación de conexión y sudo persistente
# ─────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
    echo -e "$INFO Verificando permisos sudo..."
    sudo -v || { echo -e "$ERROR Permisos sudo requeridos."; exit 1; }
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true' EXIT
fi

# ═════════════════════════════════════════
# PASO 1: Keyrings y Actualización del sistema
# ═════════════════════════════════════════
step 1 "Sincronizando repositorios y asegurando llaves pacman..."
for _ in $(seq 1 30); do
    [ -f /var/lib/pacman/db.lck ] || break
    echo -e "$INFO pacman está ocupado, esperando..."; sleep 3
done

# Reparar llaves para evitar errores de firma PGP corrupta
echo -e "$INFO Actualizando archlinux-keyring..."
run_safe as_root pacman -Sy --needed --noconfirm archlinux-keyring

if [ "$DO_UPDATE" -eq 1 ]; then
    echo -e "$INFO Ejecutando pacman -Syu..."
    run_safe as_root pacman -Syu --noconfirm
fi
echo -e "$OK Repositorios listos"

# ═════════════════════════════════════════
# PASO 2: Herramientas base
# ═════════════════════════════════════════
step 2 "Instalando herramientas base..."
as_root pacman -S --needed --noconfirm base-devel git curl wget jq rsync xdg-user-dirs xdg-utils
run_safe xdg-user-dirs-update
echo -e "$OK Herramientas base instaladas"

# ═════════════════════════════════════════
# PASO 3: AUR helper (paru / yay)
# ═════════════════════════════════════════
step 3 "Verificando AUR helper..."
AUR_HELPER=""
if command -v paru &>/dev/null; then
    AUR_HELPER="paru"
elif command -v yay &>/dev/null; then
    AUR_HELPER="yay"
else
    echo -e "$INFO Instalando 'yay-bin' desde AUR..."
    if [ "$DRY_RUN" -eq 0 ]; then
        TMP_YAY="$(mktemp -d)"
        git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY/yay-bin" 2>/dev/null || true
        if [ -d "$TMP_YAY/yay-bin" ]; then
            (cd "$TMP_YAY/yay-bin" && makepkg -si --noconfirm) || true
        fi
        rm -rf "$TMP_YAY"
    fi
    command -v yay &>/dev/null && AUR_HELPER="yay"
fi

if [ -n "$AUR_HELPER" ]; then
    case "$AUR_HELPER" in
        paru) AUR_FLAGS=(--needed --noconfirm --skipreview) ;;
        yay)  AUR_FLAGS=(--needed --noconfirm --answerdiff None --answerclean None --removemake) ;;
    esac
    echo -e "$OK AUR helper: $AUR_HELPER"
else
    echo -e "$WARN No se pudo configurar yay/paru automáticamente; se continuará con paquetes oficiales."
fi

# ═════════════════════════════════════════
# PASO 4: Resolución de conflictos conocidos
# ═════════════════════════════════════════
step 4 "Resolviendo conflictos de paquetes conocidos..."
is_installed() { pacman -Qq "$1" &>/dev/null; }

for pair in \
    "quickshell:quickshell-git" \
    "pipewire-media-session:wireplumber" \
    "pulseaudio:pipewire-pulse"; do
    old="${pair%%:*}"; new="${pair##*:}"
    if is_installed "$old" && ! is_installed "$new"; then
        echo -e "$INFO Reemplazando '$old' por '$new'..."
        run_safe as_root pacman -Rdd --noconfirm "$old"
        [ "$old" = "pulseaudio" ] && run_safe as_root pacman -Rdd --noconfirm pulseaudio-bluetooth pulseaudio-alsa
    fi
done
echo -e "$OK Conflictos resueltos"

# ═════════════════════════════════════════
# PASO 5: Paquetes de los repositorios oficiales
# ═════════════════════════════════════════
step 5 "Instalando paquetes oficiales de Hyprland..."
official_packages=(
    # Hyprland y Wayland
    hyprland hypridle hyprlock hyprsunset hyprpolkitagent polkit-gnome
    xdg-desktop-portal-hyprland xdg-desktop-portal-gtk xorg-xwayland qt5-wayland qt6-wayland
    # Barra, notificaciones y menús
    waybar swaync rofi yad qalculate-gtk libnotify
    # Fondos y theming
    awww imagemagick bc kvantum qt5ct qt6ct nwg-look
    # Terminal y consola
    kitty alacritty fastfetch btop fzf bat eza lsd mpv mpv-mpris yt-dlp vim
    # Archivos
    nautilus thunar thunar-archive-plugin thunar-volman tumbler ffmpegthumbnailer gvfs xarchiver
    # Audio y multimedia
    pipewire pipewire-pulse pipewire-alsa wireplumber pamixer pavucontrol playerctl cava libpulse alsa-utils
    # Capturas, cursor y portapapeles
    grim slurp swappy wl-clipboard cliphist brightnessctl hyprcursor
    # Red, VPN y Bluetooth
    networkmanager network-manager-applet nm-connection-editor blueman bluez bluez-utils socat openvpn
    # Fuentes
    ttf-jetbrains-mono-nerd ttf-victor-mono-nerd noto-fonts noto-fonts-cjk noto-fonts-emoji
    # Zsh
    zsh zsh-autosuggestions zsh-syntax-highlighting
    # Python (scripts)
    python python-requests
)

FAILED_PKGS=()
if ! as_root pacman -S --needed --noconfirm "${official_packages[@]}"; then
    echo -e "$WARN La instalación en bloque falló, instalando paquete por paquete..."
    for pkg in "${official_packages[@]}"; do
        if ! as_root pacman -S --needed --noconfirm "$pkg" 2>/dev/null; then
            echo -e "$WARN $pkg no se pudo instalar desde repos oficiales."
            FAILED_PKGS+=("$pkg")
        fi
    done
fi
echo -e "$OK Paquetes oficiales procesados"

# ═════════════════════════════════════════
# PASO 6: Paquetes AUR (o Chaotic-AUR en Garuda)
# ═════════════════════════════════════════
step 6 "Instalando paquetes complementarios (Wallust, Waypaper, Wlogout)..."
aur_packages=(
    "wallust:wallust"
    "waypaper:waypaper"
    "wlogout:wlogout"
    "bibata-cursor-theme:"
    "pokemon-colorscripts-git:pokemon-colorscripts"
    "zsh-sudo:"
    "caelestia-cli:caelestia"
    "quickshell-git:quickshell"
)
for pkg in "${FAILED_PKGS[@]}"; do aur_packages+=("$pkg:"); done

AUR_FAILED=()
if [ -n "$AUR_HELPER" ]; then
    for entry in "${aur_packages[@]}"; do
        pkg="${entry%%:*}"; cmd="${entry#*:}"
        if [ -n "$cmd" ] && command -v "$cmd" &>/dev/null; then
            echo -e "$OK $pkg (ya disponible: $cmd)"; continue
        fi
        if is_installed "$pkg"; then echo -e "$OK $pkg (ya instalado)"; continue; fi
        echo -e "$INFO  → $pkg"
        if ! sys_cmd "$AUR_HELPER" -S "${AUR_FLAGS[@]}" "$pkg" 2>/dev/null; then
            echo -e "$WARN $pkg falló o se canceló (se continúa)"
            AUR_FAILED+=("$pkg")
        fi
    done
fi

# Utilidades ASUS solo en laptops ASUS
if grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null && [ -n "$AUR_HELPER" ]; then
    echo -e "$INFO Laptop ASUS detectada: instalando asusctl (opcional)"
    run_safe sys_cmd "$AUR_HELPER" -S "${AUR_FLAGS[@]}" asusctl
fi

# ═════════════════════════════════════════
# PASO 7: Servicios
# ═════════════════════════════════════════
step 7 "Activando servicios (red, bluetooth, audio)..."
run_safe as_root systemctl enable --now NetworkManager.service
run_safe as_root systemctl enable --now bluetooth.service
for svc in pipewire.socket pipewire-pulse.socket wireplumber.service; do
    run_safe sys_cmd systemctl --user enable --now "$svc"
done
echo -e "$OK Servicios activos"

# ═════════════════════════════════════════
# PASO 8: Zsh + Oh My Zsh + Powerlevel10k
# ═════════════════════════════════════════
step 8 "Configurando Zsh + Oh My Zsh + Powerlevel10k..."
export RUNZSH=no CHSH=no KEEP_ZSHRC=yes
OMZ="$REAL_HOME/.oh-my-zsh"

if [ ! -f "$OMZ/oh-my-zsh.sh" ]; then
    rm -rf "$OMZ"
    run_safe git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ"
    echo -e "$OK Oh My Zsh instalado"
else
    echo -e "$OK Oh My Zsh ya existe"
fi

clone_if_missing() {
    if [ -d "$2" ] && [ -n "$(ls -A "$2" 2>/dev/null)" ]; then
        return 0
    fi
    rm -rf "$2"
    run_safe git clone --depth=1 "$1" "$2"
}
clone_if_missing https://github.com/romkatv/powerlevel10k.git "$OMZ/custom/themes/powerlevel10k"
clone_if_missing https://github.com/zsh-users/zsh-autosuggestions "$OMZ/custom/plugins/zsh-autosuggestions"
clone_if_missing https://github.com/zsh-users/zsh-syntax-highlighting "$OMZ/custom/plugins/zsh-syntax-highlighting"
clone_if_missing https://github.com/Aloxaf/fzf-tab "$OMZ/custom/plugins/fzf-tab"

# Zsh como shell por defecto del usuario
ZSH_BIN="$(command -v zsh || echo /usr/bin/zsh)"
if [ "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "$ZSH_BIN" ]; then
    grep -qx "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | as_root tee -a /etc/shells >/dev/null
    run_safe as_root chsh -s "$ZSH_BIN" "$REAL_USER"
    echo -e "$OK Zsh es ahora el shell por defecto de $REAL_USER"
fi

# Root Oh My Zsh
if [ -f "$BASE_DIR/zshrcroot" ]; then
    run_safe as_root rsync -a --delete "$OMZ/" /root/.oh-my-zsh/
    run_safe as_root cp -f "$BASE_DIR/zshrcroot" /root/.zshrc
    [ -f "$BASE_DIR/p10k.zshroot" ] && run_safe as_root cp -f "$BASE_DIR/p10k.zshroot" /root/.p10k.zsh
    run_safe as_root chsh -s "$ZSH_BIN" root
    echo -e "$OK Zsh configurado también para root"
fi

# ═════════════════════════════════════════
# PASO 9: Despliegue de Dotfiles
# ═════════════════════════════════════════
step 9 "Desplegando configuraciones completas de Hyprland..."
deploy_dotfiles

# ═════════════════════════════════════════
# PASO 10: Pantalla de login + sincronización SDDM
# ═════════════════════════════════════════
step 10 "Configurando pantalla de inicio de sesión..."
if [ -L /etc/systemd/system/display-manager.service ]; then
    DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    echo -e "$OK Gestor de login existente: $DM (no se modifica). Elige 'Hyprland' al iniciar sesión."
else
    echo -e "$INFO No hay gestor de login activo: instalando y activando SDDM"
    run_safe as_root pacman -S --needed --noconfirm sddm
    run_safe as_root systemctl enable sddm.service
    echo -e "$OK SDDM activado"
fi

SDDM_HELPER="$REAL_HOME/.config/hypr/scripts/sddm_root_helper.sh"
if [ -f "$SDDM_HELPER" ]; then
    as_root install -m 755 -o root -g root "$SDDM_HELPER" /usr/local/bin/sddm_root_helper
    SUDOERS_TMP="$(mktemp)"
    {
        echo "$REAL_USER ALL=(root) NOPASSWD: /usr/local/bin/sddm_root_helper"
        echo "$REAL_USER ALL=(root) NOPASSWD: /usr/local/bin/vpnhtb"
        echo "$REAL_USER ALL=(root) NOPASSWD: /usr/bin/openvpn"
    } > "$SUDOERS_TMP"
    if [ "$DRY_RUN" -eq 1 ] || sudo visudo -cf "$SUDOERS_TMP" >/dev/null 2>&1; then
        as_root install -m 440 -o root -g root "$SUDOERS_TMP" /etc/sudoers.d/90-hyperland-sddm
        echo -e "$OK Helper SDDM, vpnhtb y regla sudoers instalados"
    fi
    rm -f "$SUDOERS_TMP"
fi

# ═════════════════════════════════════════
# PASO 11: Permisos y sincronización de Wallust
# ═════════════════════════════════════════
step 11 "Sincronizando paleta inicial con Wallust..."
FIRST_WALL="$(find -L "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)"
[ -z "$FIRST_WALL" ] && FIRST_WALL="$(find -L "$BASE_DIR/wallpapers" -type f 2>/dev/null | head -n1 || true)"
if [ -n "$FIRST_WALL" ] && command -v wallust &>/dev/null; then
    run_safe wallust run -s "$FIRST_WALL" >/dev/null 2>&1
fi
echo -e "$OK Paleta sincronizada"

# ═════════════════════════════════════════
# PASO 12: Verificación final
# ═════════════════════════════════════════
step 12 "Verificando instalación..."
MISSING=()
for f in hypr/hyprland.conf hypr/UserConfigs/UserKeybinds.conf hypr/UserConfigs/Startup_Apps.conf waybar/config swaync/config.json rofi/config.rasi kitty/kitty.conf; do
    [ -f "$REAL_HOME/.config/$f" ] || MISSING+=("~/.config/$f")
done

echo ""
if [ ${#MISSING[@]} -eq 0 ]; then
    echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${OK}  🌌 ¡INSTALACIÓN COMPLETADA EXITOSAMENTE!"
    echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
else
    echo -e "$WARN Faltan los siguientes archivos: ${MISSING[*]}"
fi

echo -e "$INFO Copia de seguridad en: $BACKUP_DIR"
echo -e "$INFO Log completo guardado en: $LOG_FILE"
echo ""
echo -e "${INFO}Atajos principales garantizados:${NC}"
echo -e "  • ${TITLE}SUPER + Q${NC}       -> Cerrar ventana activa"
echo -e "  • ${TITLE}SUPER + Return${NC}  -> Abrir terminal (Kitty)"
echo -e "  • ${TITLE}SUPER + D${NC}       -> Menú de aplicaciones (Rofi)"
echo -e "  • ${TITLE}SUPER + E${NC}       -> Explorador de archivos"
echo -e "  • ${TITLE}SUPER + W${NC}       -> Selector de fondos de pantalla"
echo ""
echo -e "${INFO}Siguientes pasos:${NC}"
echo -e "  1. Reinicia el equipo o cierra sesión."
echo -e "  2. En el inicio de sesión selecciona ${TITLE}Hyprland${NC}."
echo -e "  3. ¡Disfruta tu entorno!"
echo ""
exit 0
