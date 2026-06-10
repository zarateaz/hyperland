#!/bin/bash
# Script to compile Dynamic-Cursor using hyprcursor-util and apply it

set -euo pipefail

CURSOR_SRC="$HOME/.config/hypr/cursor-source"
ICONS_DIR="$HOME/.local/share/icons"

# Remove any old .toml files to avoid parsing issues or conflicts
find "$CURSOR_SRC" -name "*.toml" -type f -delete 2>/dev/null || true

# Verify that source folder exists and has manifest
if [ ! -d "$CURSOR_SRC" ] || [ ! -f "$CURSOR_SRC/manifest.hl" ]; then
    echo "Cursor source or manifest not found. Skipping compilation."
    exit 0
fi

echo "Compiling Dynamic-Cursor theme..."
# Clean target folder first to prevent hyprcursor-util confirmation prompt
rm -rf "$ICONS_DIR/theme_Dynamic-Cursor"
# Compiling theme
mkdir -p "$ICONS_DIR"
hyprcursor-util --create "$CURSOR_SRC" -o "$ICONS_DIR"

# hyprcursor-util compiled output directory handling:
# With newer versions, compiling creates a directory named `create_<foldername>` or `theme_<manifestname>` inside the output path.
if [ -d "$ICONS_DIR/create_cursor-source" ]; then
    rm -rf "$ICONS_DIR/Dynamic-Cursor"
    mv "$ICONS_DIR/create_cursor-source" "$ICONS_DIR/Dynamic-Cursor"
elif [ -d "$ICONS_DIR/theme_Dynamic-Cursor" ]; then
    rm -rf "$ICONS_DIR/Dynamic-Cursor"
    mv "$ICONS_DIR/theme_Dynamic-Cursor" "$ICONS_DIR/Dynamic-Cursor"
fi

# Ensure that the theme name folder is correctly named Dynamic-Cursor
# (just in case it compiles directly to a folder with another name, we look for it)
if [ -d "$ICONS_DIR/Dynamic-Cursor" ]; then
    echo "Dynamic-Cursor theme compiled successfully."
    
    # Apply theme via hyprctl (Wayland)
    hyprctl setcursor Dynamic-Cursor 24
    
    # Apply theme via gsettings (GTK)
    gsettings set org.gnome.desktop.interface cursor-theme 'Dynamic-Cursor'
    
    # Also notify theme change
    notify-send -t 2000 "Cursor Actualizado" "El cursor se ha adaptado a los colores del fondo de pantalla" -i "$HOME/.config/swaync/icons/theme.png" || true
    
    echo "Dynamic-Cursor applied!"
else
    echo "Error: Dynamic-Cursor compilation output folder not found."
    exit 1
fi
