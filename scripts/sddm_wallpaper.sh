#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */
# SDDM Wallpaper and Wallust Colors Setter

# for the upcoming changes on the simple_sddm_theme

# variables
terminal=kitty
wallDIR="$HOME/Pictures/wallpapers"
SCRIPTSDIR="$HOME/.config/hypr/scripts"
wallpaper_current="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
wallpaper_modified="$HOME/.config/hypr/wallpaper_effects/.wallpaper_modified"
# Resolve SDDM themes directory (standard paths and NixOS path)
sddm_themes_dir="/usr/share/sddm/themes"
if [ ! -d "$sddm_themes_dir" ] && [ -d "/run/current-system/sw/share/sddm/themes" ]; then
    sddm_themes_dir="/run/current-system/sw/share/sddm/themes"
fi
sddm_simple="$sddm_themes_dir/simple_sddm_2"

# rofi-wallust-sddm colors path
rofi_wallust="$HOME/.config/rofi/wallust/colors-rofi.rasi"
sddm_theme_conf="$sddm_simple/theme.conf"

# Directory for swaync
iDIR="$HOME/.config/swaync/images"
iDIRi="$HOME/.config/swaync/icons"

# Parse arguments
mode="normal" # default as requested: ORIGINAL
passed_wallpaper=""

while [[ $# -gt 0 ]]; do
    case "$1" in
        --normal) mode="normal"; shift ;;
        --effects) mode="effects"; shift ;;
        *) passed_wallpaper="$1"; shift ;;
    esac
done

# Extract colors from rofi wallust config
if [[ -f "$rofi_wallust" ]]; then
    color0=$(grep -oP 'color1:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
    color1=$(grep -oP 'color0:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
    color7=$(grep -oP 'color14:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
    color10=$(grep -oP 'color10:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
    color12=$(grep -oP 'color12:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
    color13=$(grep -oP 'color13:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
    foreground=$(grep -oP 'foreground:\s*\K#[A-Fa-f0-9]+' "$rofi_wallust")
else
    # Fallback to some generic colors if wallust hasn't run
    color1="#1e1e2e"; color7="#cdd6f4"; color10="#a6e3a1"; color12="#89b4fa"; color13="#f5c2e7"
fi

# wallpaper to use
if [[ -n "$passed_wallpaper" && -f "$passed_wallpaper" ]]; then
    wallpaper_path=$(realpath "$passed_wallpaper")
elif [[ "$mode" == "normal" ]]; then
    wallpaper_path=$(cat "$wallpaper_current" 2>/dev/null || echo "")
else
    wallpaper_path="$wallpaper_modified"
fi

# Check if a dedicated SDDM wallpaper folder exists and has content
DedicatedSddmWall="$HOME/Pictures/wallpapers/sddm"
if [[ -d "$DedicatedSddmWall" ]]; then
    # Pick the first image found (supports png, jpg, jpeg)
    FirstImg=$(find "$DedicatedSddmWall" -maxdepth 1 -type f \( -iname "*.png" -o -iname "*.jpg" -o -iname "*.jpeg" \) | head -n 1)
    if [[ -n "$FirstImg" ]]; then
        wallpaper_path="$FirstImg"
        echo "$(date): Using dedicated SDDM wallpaper from $DedicatedSddmWall" >> /tmp/sddm_sync.log
    fi
fi

# Ensure wallpaper_path is not empty and exists
if [[ -z "$wallpaper_path" || ! -f "$wallpaper_path" ]]; then
    # Final fallback: use what swww/awww is currently showing
    # Handle the "image: " prefix if present
    wallpaper_path=$(swww query | grep "currently displaying" | awk -F 'image: ' '{print $2}' | xargs || swww query | grep "currently displaying" | awk '{print $NF}' | xargs || echo "")
fi

if [[ -z "$wallpaper_path" || ! -f "$wallpaper_path" ]]; then
    exit 1
fi

# Execute root helper silently
# Check if sudo can run without a password. 
# If it requires one, we skip to avoid hanging the background process.
if sudo -n true 2>/dev/null; then
    sudo /usr/local/bin/sddm_root_helper "$wallpaper_path" "$color1,$color7,$color10,$color12,$color13"
else
    echo "$(date): Sudo requires a password. Skipping SDDM update." >> /tmp/sddm_sync.log
    # This message will be visible in /tmp/sddm_update_last.log
    echo "NOTICE: SDDM update skipped because sudo requires a password."
    echo "To fix: add a NOPASSWD rule in /etc/sudoers for sddm_root_helper.sh"
fi
