#!/usr/bin/env bash
# ══════════════════════════════════════════════════════════════════════
#  🌌 CELESTIAL + HYPRLAND - Instalador para Garuda Linux / Arch Linux
#  https://github.com/zarateaz/hyperland
#
#  Uso (un solo comando, como usuario normal):
#    bash <(curl -fsSL https://raw.githubusercontent.com/zarateaz/hyperland/main/install.sh)
#  o bien:
#    git clone --depth=1 https://github.com/zarateaz/hyperland.git && cd hyperland && ./install.sh
#
#  Opciones:
#    --dry-run   No toca el sistema (sin sudo/pacman/systemctl); solo despliega
#                los dotfiles en $HOME. Útil para probar con HOME=/ruta/temporal.
#    --no-update No ejecuta la actualización completa del sistema (pacman -Syu).
# ══════════════════════════════════════════════════════════════════════

# Si se ejecuta mediante curl ... | bash, reconectar stdin a la terminal interactiva
if [ ! -t 0 ] && [ -e /dev/tty ]; then
    exec < /dev/tty
fi

set -Eeo pipefail

# ─────────────────────────────────────────
# Opciones
# ─────────────────────────────────────────
DRY_RUN=0
DO_UPDATE=1
for arg in "$@"; do
    case "$arg" in
        --dry-run)   DRY_RUN=1 ;;
        --no-update) DO_UPDATE=0 ;;
        -h|--help)   sed -n '2,16p' "${BASH_SOURCE[0]:-$0}" 2>/dev/null; exit 0 ;;
        *) echo "Opción desconocida: $arg"; exit 1 ;;
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

# Comandos no críticos: si fallan se avisa y se continúa
run_safe() {
    "$@" || { echo -e "$WARN  Continuando tras fallo no crítico: $*"; return 0; }
}

# Comandos que modifican el sistema (sudo). En --dry-run solo se muestran.
as_root() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "\e[90m  [dry-run] sudo $*\e[0m"
        return 0
    fi
    sudo "$@"
}

# Comandos de sistema sin sudo (AUR helper, systemctl --user, makepkg...)
sys_cmd() {
    if [ "$DRY_RUN" -eq 1 ]; then
        echo -e "\e[90m  [dry-run] $*\e[0m"
        return 0
    fi
    "$@"
}

on_error() {
    local code=$? line=$1
    echo -e "\n$ERROR Falló la línea $line (código $code): $BASH_COMMAND"
    echo -e "$INFO  Revisa el log completo en: $LOG_FILE"
    echo -e "$INFO  Puedes volver a ejecutar el instalador; es seguro repetirlo."
}
trap 'on_error $LINENO' ERR

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
    BASE_DIR="$PWD"   # ejecutado vía 'bash <(curl ...)' o 'curl | bash'
fi
TIMESTAMP="$(date +%Y%m%d-%H%M%S)"
BACKUP_DIR="$REAL_HOME/.hyperland-backups/$TIMESTAMP"
LOG_FILE="$REAL_HOME/hyperland-install-$TIMESTAMP.log"

# Asegurar que el directorio del log exista antes de tee
mkdir -p "$(dirname "$LOG_FILE")"

# Todo lo que se muestre en pantalla también queda en el log
exec > >(tee -a "$LOG_FILE") 2>&1

echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "${TITLE}   🌌 CELESTIAL & HYPRLAND - INSTALADOR AUTOMÁTICO             ${NC}"
echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
echo -e "$INFO Usuario: $REAL_USER  |  HOME: $REAL_HOME"
echo -e "$INFO Log: $LOG_FILE"
[ "$DRY_RUN" -eq 1 ] && echo -e "$WARN MODO --dry-run: no se modificará el sistema, solo \$HOME"

# ─────────────────────────────────────────
# Comprobación de distribución
# ─────────────────────────────────────────
if ! command -v pacman &>/dev/null; then
    echo -e "$ERROR Este instalador es para Arch Linux o derivados (Garuda, EndeavourOS, CachyOS)."
    exit 1
fi
DISTRO_ID="$(. /etc/os-release 2>/dev/null; echo "${ID:-arch}")"
echo -e "$INFO Distribución detectada: $DISTRO_ID"

if ! ping -c1 -W3 archlinux.org &>/dev/null && ! curl -fsS --max-time 5 https://archlinux.org -o /dev/null; then
    echo -e "$ERROR Sin conexión a Internet. Conéctate y vuelve a intentarlo."
    exit 1
fi

# ─────────────────────────────────────────
# Credenciales sudo persistentes durante la instalación
# ─────────────────────────────────────────
if [ "$DRY_RUN" -eq 0 ]; then
    echo -e "$INFO Verificando permisos sudo..."
    sudo -v
    ( while true; do sudo -n true; sleep 50; kill -0 "$$" 2>/dev/null || exit; done ) 2>/dev/null &
    SUDO_KEEP_ALIVE_PID=$!
    trap 'kill "$SUDO_KEEP_ALIVE_PID" 2>/dev/null || true' EXIT
fi

# ─────────────────────────────────────────
# Auto-clonado si se ejecuta como script suelto (curl)
# ─────────────────────────────────────────
if [[ ! -d "$BASE_DIR/config/hypr" ]] || [[ ! -f "$BASE_DIR/zshrc" ]]; then
    command -v git &>/dev/null || as_root pacman -S --needed --noconfirm git
    TARGET_REPO="$REAL_HOME/hyperland"
    echo -e "$INFO Archivos del repositorio no encontrados. Preparando $TARGET_REPO ..."
    if [ -d "$TARGET_REPO/.git" ]; then
        echo -e "$INFO Repositorio encontrado en $TARGET_REPO, actualizando..."
        git -C "$TARGET_REPO" pull --ff-only || true
    else
        rm -rf "$TARGET_REPO"
        git clone --depth=1 https://github.com/zarateaz/hyperland.git "$TARGET_REPO"
    fi
    BASE_DIR="$TARGET_REPO"
    echo -e "$OK Repositorio listo en $BASE_DIR"
fi
echo -e "$INFO Directorio base: $BASE_DIR"

# ═════════════════════════════════════════
# PASO 1: Actualización completa del sistema
# ═════════════════════════════════════════
step 1 "Sincronizando repositorios y actualizando el sistema..."
# Esperar si otro pacman está en uso (p. ej. actualizador automático de Garuda)
for _ in $(seq 1 60); do
    [ -f /var/lib/pacman/db.lck ] || break
    echo -e "$INFO pacman está ocupado, esperando..."; sleep 5
done
if [ "$DO_UPDATE" -eq 1 ]; then
    # -Syu (nunca solo -Sy): evita actualizaciones parciales que rompen Arch
    as_root pacman -Syu --noconfirm
else
    as_root pacman -Sy --noconfirm
fi
echo -e "$OK Sistema actualizado"

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
        git clone --depth=1 https://aur.archlinux.org/yay-bin.git "$TMP_YAY/yay-bin"
        (cd "$TMP_YAY/yay-bin" && makepkg -si --noconfirm)
        rm -rf "$TMP_YAY"
    fi
    AUR_HELPER="yay"
fi
case "$AUR_HELPER" in
    paru) AUR_FLAGS=(--needed --noconfirm --skipreview) ;;
    yay)  AUR_FLAGS=(--needed --noconfirm --answerdiff None --answerclean None --removemake) ;;
esac
echo -e "$OK AUR helper: $AUR_HELPER"

# ═════════════════════════════════════════
# PASO 4: Resolución de conflictos conocidos
# ═════════════════════════════════════════
step 4 "Resolviendo conflictos de paquetes conocidos..."
is_installed() { pacman -Qq "$1" &>/dev/null; }
# formato: "paquete_a_quitar:paquete_que_lo_reemplaza"
for pair in \
    "rofi-wayland:rofi" \
    "swww:awww" \
    "quickshell:quickshell-git" \
    "pipewire-media-session:wireplumber" \
    "pulseaudio:pipewire-pulse"; do
    old="${pair%%:*}"; new="${pair##*:}"
    if is_installed "$old" && ! is_installed "$new"; then
        echo -e "$INFO Reemplazando '$old' por '$new'..."
        as_root pacman -Rdd --noconfirm "$old" || true
        [ "$old" = "pulseaudio" ] && as_root pacman -Rdd --noconfirm pulseaudio-bluetooth pulseaudio-alsa 2>/dev/null || true
    fi
done
echo -e "$OK Conflictos resueltos"

# ═════════════════════════════════════════
# PASO 5: Paquetes de los repositorios oficiales
# ═════════════════════════════════════════
step 5 "Instalando paquetes oficiales..."
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
    # Python (scripts de clima/brillo/volumen)
    python python-requests
)

FAILED_PKGS=()
# Primero en una sola transacción (rápido); si falla, paquete por paquete
if ! as_root pacman -S --needed --noconfirm "${official_packages[@]}"; then
    echo -e "$WARN La instalación en bloque falló, reintentando paquete por paquete..."
    for pkg in "${official_packages[@]}"; do
        if as_root pacman -S --needed --noconfirm "$pkg"; then
            echo -e "$OK $pkg"
        else
            echo -e "$WARN $pkg no se pudo instalar desde repos, se intentará con $AUR_HELPER"
            FAILED_PKGS+=("$pkg")
        fi
    done
fi
echo -e "$OK Paquetes oficiales procesados"

# ═════════════════════════════════════════
# PASO 6: Paquetes AUR (o Chaotic-AUR en Garuda)
# ═════════════════════════════════════════
step 6 "Instalando paquetes AUR con $AUR_HELPER..."
# formato: "paquete:comando_que_provee" (se omite si el comando ya existe, p. ej. wallust-git)
aur_packages=(
    "wallust:wallust"
    "waypaper:waypaper"
    "wlogout:wlogout"
    "bibata-cursor-theme:"
    "pokemon-colorscripts-git:pokemon-colorscripts"
    "zsh-sudo:"
    "quickshell-git:quickshell"
    "caelestia-cli:caelestia"
)
for pkg in "${FAILED_PKGS[@]}"; do aur_packages+=("$pkg:"); done

AUR_FAILED=()
for entry in "${aur_packages[@]}"; do
    pkg="${entry%%:*}"; cmd="${entry#*:}"
    if [ -n "$cmd" ] && command -v "$cmd" &>/dev/null; then
        echo -e "$OK $pkg (ya disponible: $cmd)"; continue
    fi
    if is_installed "$pkg"; then echo -e "$OK $pkg (ya instalado)"; continue; fi
    echo -e "$INFO  → $pkg"
    if sys_cmd "$AUR_HELPER" -S "${AUR_FLAGS[@]}" "$pkg"; then
        echo -e "$OK $pkg instalado"
    else
        echo -e "$WARN $pkg falló (se continúa)"
        AUR_FAILED+=("$pkg")
    fi
done

# Utilidades ASUS solo en laptops ASUS (teclas Fn de Laptops.conf)
if grep -qi "asus" /sys/class/dmi/id/sys_vendor 2>/dev/null; then
    echo -e "$INFO Laptop ASUS detectada: instalando asusctl / rog-control-center (opcional)"
    run_safe sys_cmd "$AUR_HELPER" -S "${AUR_FLAGS[@]}" asusctl rog-control-center
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
    git clone --depth=1 https://github.com/ohmyzsh/ohmyzsh.git "$OMZ"
    echo -e "$OK Oh My Zsh instalado"
else
    echo -e "$OK Oh My Zsh ya existe"
fi

clone_if_missing() {  # url destino
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

mkdir -p "$BACKUP_DIR"
for f in .zshrc .p10k.zsh; do
    [ -f "$REAL_HOME/$f" ] && cp -a "$REAL_HOME/$f" "$BACKUP_DIR/" || true
done
cp -f "$BASE_DIR/zshrc" "$REAL_HOME/.zshrc"
[ -f "$BASE_DIR/.p10k.zsh" ] && cp -f "$BASE_DIR/.p10k.zsh" "$REAL_HOME/.p10k.zsh"
echo -e "$OK .zshrc y .p10k.zsh copiados"

# Zsh como shell por defecto del usuario
ZSH_BIN="$(command -v zsh || echo /usr/bin/zsh)"
if [ "$(getent passwd "$REAL_USER" | cut -d: -f7)" != "$ZSH_BIN" ]; then
    grep -qx "$ZSH_BIN" /etc/shells || echo "$ZSH_BIN" | as_root tee -a /etc/shells >/dev/null
    run_safe as_root chsh -s "$ZSH_BIN" "$REAL_USER"
    echo -e "$OK Zsh es ahora el shell por defecto de $REAL_USER"
fi

# Root: copia completa de Oh My Zsh (si no, /root/.zshrc falla al no encontrar oh-my-zsh.sh)
if [ -f "$BASE_DIR/zshrcroot" ]; then
    run_safe as_root rsync -a --delete "$OMZ/" /root/.oh-my-zsh/
    run_safe as_root cp -f "$BASE_DIR/zshrcroot" /root/.zshrc
    [ -f "$BASE_DIR/p10k.zshroot" ] && run_safe as_root cp -f "$BASE_DIR/p10k.zshroot" /root/.p10k.zsh
    run_safe as_root chsh -s "$ZSH_BIN" root
    echo -e "$OK Zsh configurado también para root"
fi

# Compatibilidad: los scripts usan 'swww', el paquete actual se llama 'awww'
mkdir -p "$REAL_HOME/.local/bin"
if command -v awww &>/dev/null && ! command -v swww &>/dev/null; then
    ln -sf "$(command -v awww)" "$REAL_HOME/.local/bin/swww"
    ln -sf "$(command -v awww-daemon)" "$REAL_HOME/.local/bin/swww-daemon"
    echo -e "$OK Enlaces swww → awww creados"
fi

# ═════════════════════════════════════════
# PASO 9: Dotfiles (con copia de seguridad)
# ═════════════════════════════════════════
step 9 "Desplegando configuraciones (backup en $BACKUP_DIR)..."
mkdir -p "$REAL_HOME/.config" "$BACKUP_DIR/config"
find "$REAL_HOME/.config" -maxdepth 1 -xtype l -delete 2>/dev/null || true

# Se excluye 'pulse' (cookie de autenticación propia de cada máquina)
EXCLUDE_CONFIG=(pulse)
for src in "$BASE_DIR"/config/*; do
    name="$(basename "$src")"
    [[ " ${EXCLUDE_CONFIG[*]} " == *" $name "* ]] && continue
    dst="$REAL_HOME/.config/$name"
    if [ -e "$dst" ] || [ -L "$dst" ]; then
        mv "$dst" "$BACKUP_DIR/config/"
    fi
    cp -a "$src" "$dst"
    echo -e "$INFO  → .config/$name"
done
rm -f "$REAL_HOME/.config/hypr/.initial_startup_done"

# Caelestia Shell (se copia sin compilar; Waybar + SwayNC son la barra principal)
if [ -d "$BASE_DIR/shell" ] && [ -n "$(ls -A "$BASE_DIR/shell" 2>/dev/null)" ]; then
    mkdir -p "$REAL_HOME/.config/quickshell/caelestia"
    rsync -a --exclude=".git" "$BASE_DIR/shell/" "$REAL_HOME/.config/quickshell/caelestia/"
    echo -e "$OK Caelestia Shell copiado en ~/.config/quickshell/caelestia"
fi

# Wallpapers: los scripts usan la ruta fija ~/Pictures/wallpapers
PICS_XDG="$(xdg-user-dir PICTURES 2>/dev/null || echo "$REAL_HOME/Pictures")"
if [ ! -e "$REAL_HOME/Pictures" ]; then
    if [ "$PICS_XDG" != "$REAL_HOME/Pictures" ] && [ "$PICS_XDG" != "$REAL_HOME" ] && [ -d "$PICS_XDG" ]; then
        ln -s "$PICS_XDG" "$REAL_HOME/Pictures"   # p. ej. ~/Imágenes en sistemas en español
    else
        mkdir -p "$REAL_HOME/Pictures"
    fi
fi
WALL_DIR="$REAL_HOME/Pictures/wallpapers"
mkdir -p "$WALL_DIR"
if [ -d "$BASE_DIR/wallpapers" ]; then
    rsync -a --ignore-existing "$BASE_DIR/wallpapers/" "$WALL_DIR/"
    echo -e "$OK Wallpapers en $WALL_DIR"
fi

if [ -f "$REAL_HOME/.config/waypaper/config.ini" ]; then
    sed -i "s|^folder = .*|folder = $WALL_DIR|" "$REAL_HOME/.config/waypaper/config.ini"
    sed -i "s|^stylesheet = .*|stylesheet = $REAL_HOME/.config/waypaper/style.css|" "$REAL_HOME/.config/waypaper/config.ini"
    echo -e "$OK waypaper configurado"
fi

# Touchpad: detectar el nombre real del dispositivo (formato de Hyprland)
LAPTOPS_CONF="$REAL_HOME/.config/hypr/UserConfigs/Laptops.conf"
TP_RAW="$( (grep -iE '^N: Name=.*touchpad' /proc/bus/input/devices 2>/dev/null || true) | sed -nE 's/^N: Name="(.*)"$/\1/p' | head -n1 || true)"
if [ -n "$TP_RAW" ] && [ -f "$LAPTOPS_CONF" ]; then
    TP_NAME="$(echo "$TP_RAW" | tr '[:upper:]' '[:lower:]' | tr ' ' '-')"
    sed -i "s|^\$Touchpad_Device=.*|\$Touchpad_Device=$TP_NAME|" "$LAPTOPS_CONF"
    echo -e "$OK Touchpad detectado: $TP_NAME"
fi

# ═════════════════════════════════════════
# PASO 10: Pantalla de login + sincronización SDDM
# ═════════════════════════════════════════
step 10 "Configurando pantalla de inicio de sesión..."
if [ -L /etc/systemd/system/display-manager.service ]; then
    DM="$(basename "$(readlink -f /etc/systemd/system/display-manager.service)" .service)"
    echo -e "$OK Gestor de login existente: $DM (no se modifica). Elige 'Hyprland' al iniciar sesión."
else
    echo -e "$INFO No hay gestor de login activo: instalando y activando SDDM"
    as_root pacman -S --needed --noconfirm sddm
    as_root systemctl enable sddm.service
    echo -e "$OK SDDM activado"
fi

SDDM_HELPER="$REAL_HOME/.config/hypr/scripts/sddm_root_helper.sh"
if [ -f "$SDDM_HELPER" ]; then
    as_root install -m 755 -o root -g root "$SDDM_HELPER" /usr/local/bin/sddm_root_helper
    # Permitir que el cambio de fondo sincronice SDDM sin pedir contraseña
    SUDOERS_TMP="$(mktemp)"
    {
        echo "$REAL_USER ALL=(root) NOPASSWD: /usr/local/bin/sddm_root_helper"
        echo "$REAL_USER ALL=(root) NOPASSWD: /usr/local/bin/vpnhtb"
        echo "$REAL_USER ALL=(root) NOPASSWD: /usr/bin/openvpn"
    } > "$SUDOERS_TMP"
    if [ "$DRY_RUN" -eq 1 ] || sudo visudo -cf "$SUDOERS_TMP" >/dev/null; then
        as_root install -m 440 -o root -g root "$SUDOERS_TMP" /etc/sudoers.d/90-hyperland-sddm
        echo -e "$OK Helper SDDM, vpnhtb y regla sudoers instalados"
    else
        echo -e "$WARN Regla sudoers inválida, se omite"
    fi
    rm -f "$SUDOERS_TMP"
fi

# ═════════════════════════════════════════
# PASO 11: Permisos y utilidades globales
# ═════════════════════════════════════════
step 11 "Asignando permisos a scripts..."
for d in "$REAL_HOME/.config/hypr/scripts" "$REAL_HOME/.config/hypr/UserScripts" "$REAL_HOME/.config/bin" \
         "$REAL_HOME/.config/hypr/initial-boot.sh"; do
    [ -e "$d" ] || continue
    find "$d" -type f \( -name "*.sh" -o -name "*.py" \) -exec chmod +x {} +
done
for f in settarget setports target ports; do
    [ -f "$REAL_HOME/.config/bin/$f" ] && chmod +x "$REAL_HOME/.config/bin/$f"
done
for bin_util in settarget setports vpnhtb.sh; do
    if [ -f "$REAL_HOME/.config/bin/$bin_util" ]; then
        run_safe as_root ln -sf "$REAL_HOME/.config/bin/$bin_util" "/usr/local/bin/$bin_util"
    fi
done
[ -f "$REAL_HOME/.config/bin/vpnhtb.sh" ] && run_safe as_root ln -sf "$REAL_HOME/.config/bin/vpnhtb.sh" /usr/local/bin/vpnhtb
if [ -f "$REAL_HOME/.config/bin/brillo.py" ]; then
    chmod +x "$REAL_HOME/.config/bin/brillo.py"
    ln -sf "$REAL_HOME/.config/bin/brillo.py" "$REAL_HOME/.config/bin/brillo"
    run_safe as_root ln -sf "$REAL_HOME/.config/bin/brillo.py" /usr/local/bin/brillo
fi
if [ -f "$REAL_HOME/.config/bin/volumen.py" ]; then
    chmod +x "$REAL_HOME/.config/bin/volumen.py"
    ln -sf "$REAL_HOME/.config/bin/volumen.py" "$REAL_HOME/.config/bin/volumen"
    run_safe as_root ln -sf "$REAL_HOME/.config/bin/volumen.py" /usr/local/bin/volumen
fi
echo -e "$OK Permisos asignados"

# ═════════════════════════════════════════
# PASO 12: Verificación final
# ═════════════════════════════════════════
step 12 "Verificando instalación..."
FIRST_WALL="$(find -L "$WALL_DIR" -type f \( -iname '*.jpg' -o -iname '*.jpeg' -o -iname '*.png' -o -iname '*.webp' \) -print -quit 2>/dev/null || true)"
[ -z "$FIRST_WALL" ] && FIRST_WALL="$(find -L "$WALL_DIR" -type f 2>/dev/null | head -n1 || true)"
if [ -n "$FIRST_WALL" ] && command -v wallust &>/dev/null; then
    run_safe wallust run -s "$FIRST_WALL" >/dev/null 2>&1
fi

MISSING=()
if [ "$DRY_RUN" -eq 0 ]; then
    for c in Hyprland hyprctl hypridle hyprlock waybar swaync rofi kitty wallust waypaper \
             wlogout grim slurp swappy wl-paste cliphist pamixer playerctl brightnessctl nm-applet \
             blueman-applet nautilus zsh jq magick python3; do
        command -v "$c" &>/dev/null || MISSING+=("$c")
    done
    command -v swww &>/dev/null || command -v awww &>/dev/null || MISSING+=("swww/awww")
    python3 -c "import requests" 2>/dev/null || MISSING+=("python-requests")
fi
for f in hypr/hyprland.conf hypr/UserConfigs/Startup_Apps.conf waybar/config swaync/config.json rofi/config.rasi kitty/kitty.conf; do
    [ -f "$REAL_HOME/.config/$f" ] || MISSING+=("~/.config/$f")
done
[ -f "$OMZ/oh-my-zsh.sh" ] || MISSING+=("oh-my-zsh")
[ -d "$OMZ/custom/themes/powerlevel10k" ] || MISSING+=("powerlevel10k")

echo ""
if [ ${#MISSING[@]} -eq 0 ]; then
    echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
    echo -e "${OK}  🌌 ¡INSTALACIÓN COMPLETADA SIN ERRORES!"
    echo -e "${TITLE}══════════════════════════════════════════════════════════════${NC}"
else
    echo -e "$WARN Instalación terminada, pero faltan: ${MISSING[*]}"
    echo -e "$INFO Vuelve a ejecutar ./install.sh o instálalos manualmente."
fi
[ ${#AUR_FAILED[@]} -gt 0 ] && echo -e "$WARN Paquetes AUR que fallaron: ${AUR_FAILED[*]}"
echo -e "$INFO Copia de seguridad de tu configuración anterior: $BACKUP_DIR"
echo -e "$INFO Log completo: $LOG_FILE"
echo ""
echo -e "${INFO}Siguiente paso:${NC}"
echo -e "  1. Reinicia la computadora."
echo -e "  2. En la pantalla de login elige ${TITLE}Hyprland${NC}."
echo -e "  3. ¡Disfruta tu entorno!"
echo ""
[ ${#MISSING[@]} -eq 0 ] || exit 2
