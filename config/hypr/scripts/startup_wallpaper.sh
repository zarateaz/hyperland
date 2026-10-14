#!/bin/bash
# startup_wallpaper.sh - Ensures swww/awww starts correctly without black screens

export PATH="$HOME/.local/bin:$PATH"

SCRIPTS_DIR="$HOME/.config/hypr/scripts"
WALL_CURRENT="$HOME/.config/hypr/wallpaper_effects/.wallpaper_current"
PICS_DIR=$(xdg-user-dir PICTURES 2>/dev/null || echo "$HOME/Pictures")

# Detect swww or awww
SWWW_CMD="swww"
SWWW_DAEMON="swww-daemon"
if ! command -v swww &>/dev/null && command -v awww &>/dev/null; then
    SWWW_CMD="awww"
fi
if ! command -v swww-daemon &>/dev/null && command -v awww-daemon &>/dev/null; then
    SWWW_DAEMON="awww-daemon"
fi

# Find a dynamic default wallpaper from user Pictures or bundled wallpapers
DEFAULT_WALL=$(find "$PICS_DIR/wallpapers" "$HOME/Pictures/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1)
if [[ -z "$DEFAULT_WALL" || ! -f "$DEFAULT_WALL" ]]; then
    DEFAULT_WALL=$(find "$HOME/.config/quickshell/caelestia/wallpapers" -type f \( -iname "*.jpg" -o -iname "*.jpeg" -o -iname "*.png" -o -iname "*.webp" \) 2>/dev/null | head -n 1)
fi

# 1. Start wallpaper daemon if not already responding
if ! $SWWW_CMD query > /dev/null 2>&1 && ! pgrep -x "swww-daemon" >/dev/null && ! pgrep -x "awww-daemon" >/dev/null; then
    $SWWW_DAEMON --format xrgb &
    # Wait for the socket to be available
    for i in {1..50}; do
        if $SWWW_CMD query > /dev/null 2>&1; then
            break
        fi
        sleep 0.1
    done
fi

# 2. Determine which wallpaper to load
WALL=""
if [ -f "$WALL_CURRENT" ]; then
    if file "$WALL_CURRENT" 2>/dev/null | grep -qiE 'image|bitmap'; then
        WALL="$WALL_CURRENT"
    else
        CANDIDATE=$(cat "$WALL_CURRENT" 2>/dev/null || true)
        if [[ -n "$CANDIDATE" && -f "$CANDIDATE" ]]; then
            WALL="$CANDIDATE"
        else
            WALL="$WALL_CURRENT"
        fi
    fi
fi

if [[ -z "$WALL" || ! -f "$WALL" ]]; then
    WALL="$DEFAULT_WALL"
fi

# 3. Apply the wallpaper
if [[ -n "$WALL" && -f "$WALL" ]]; then
    echo "Applying startup wallpaper: $WALL"
    $SWWW_CMD img "$WALL" --transition-type none || true
    
    # 4. Trigger a full sync in the background to ensure colors and SDDM match
    if [ -f "$SCRIPTS_DIR/WallustSwww.sh" ]; then
        bash "$SCRIPTS_DIR/WallustSwww.sh" "$WALL" &
    fi
else
    echo "Notice: No wallpaper found to apply at startup."
fi
