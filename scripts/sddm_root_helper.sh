#!/bin/bash
# sddm_root_helper.sh - Helper to update SDDM without password prompts
# Usage: ./sddm_root_helper.sh [wallpaper_path] [color1,color7,color10,color12,color13]

if [ "$#" -lt 2 ]; then
    echo "Usage: $0 [wallpaper_path] [colors_comma_separated]"
    exit 1
fi

WALLPAPER_PATH="$1"
COLORS="$2"
LOG_FILE="/tmp/sddm_sync.log"

echo "$(date): Starting SDDM sync with $WALLPAPER_PATH" > "$LOG_FILE"
chmod 666 "$LOG_FILE" || true # Ensure the user can also write/read for status checks

# Parse colors
IFS=',' read -r color1 color7 color10 color12 color13 <<< "$COLORS"

SDDM_THEMES_ROOT="/usr/share/sddm/themes"
# List of themes to sync
THEMES=("simple_sddm_2" "Dr460nized" "Sweet" "Dr460nized-Sugar-Candy")

# 1. Optimize wallpaper for SDDM (1080p or 1440p is usually enough for login)
# This prevents "black screen" or lag in SDDM due to 8K images
SDDM_TEMP_WALL="/tmp/sddm_wallpaper_optimized.jpg"
if command -v magick >/dev/null 2>&1; then
    magick "$WALLPAPER_PATH" -resize 2560x1440\> "$SDDM_TEMP_WALL"
else
    cp "$WALLPAPER_PATH" "$SDDM_TEMP_WALL"
fi

for TEMA in "${THEMES[@]}"; do
    SDDM_THEME_CONF="$SDDM_THEMES_ROOT/$TEMA/theme.conf"
    SDDM_BG_DIR="$SDDM_THEMES_ROOT/$TEMA/Backgrounds"
    
    if [ ! -d "$SDDM_THEMES_ROOT/$TEMA" ]; then
        continue
    fi

    echo "Sincronizando tema: $TEMA" >> "$LOG_FILE"
    
    # Ensure dir exists
    mkdir -p "$SDDM_BG_DIR"

    # Copy new wallpaper
    EXT="jpg"
    NEW_WALL="default.$EXT"
    cp -f "$SDDM_TEMP_WALL" "$SDDM_BG_DIR/$NEW_WALL"
    chmod 644 "$SDDM_BG_DIR/$NEW_WALL"

    # Update theme.conf
    if [ -f "$SDDM_THEME_CONF" ]; then
        # Update Colors (specific to simple_sddm_2 style, but harmless for others)
        sed -i "s/HeaderTextColor=\"#.*\"/HeaderTextColor=\"$color13\"/" "$SDDM_THEME_CONF" 2>/dev/null || true
        sed -i "s/DateTextColor=\"#.*\"/DateTextColor=\"$color13\"/" "$SDDM_THEME_CONF" 2>/dev/null || true
        sed -i "s/HighlightBackgroundColor=\"#.*\"/HighlightBackgroundColor=\"$color12\"/" "$SDDM_THEME_CONF" 2>/dev/null || true
        
        # Update Background path
        if grep -qE "^[[:space:]]*Background[[:space:]]*=" "$SDDM_THEME_CONF"; then
            sed -i "s|^[[:space:]]*Background[[:space:]]*=.*|Background=\"Backgrounds/$NEW_WALL\"|" "$SDDM_THEME_CONF"
        else
            sed -i "/\[General\]/a Background=\"Backgrounds/$NEW_WALL\"" "$SDDM_THEME_CONF" 2>/dev/null || echo "Background=\"Backgrounds/$NEW_WALL\"" >> "$SDDM_THEME_CONF"
        fi
    fi
done

rm -f "$SDDM_TEMP_WALL"
echo "$(date): SDDM update complete for all detected themes." >> "$LOG_FILE"
