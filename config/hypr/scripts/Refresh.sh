#!/bin/bash
# ══════════════════════════════════════════════════════════════════════
#  Refresh.sh - Reinicio limpio y confiable de Waybar, SwayNC y menús
# ══════════════════════════════════════════════════════════════════════

# 1. Terminar instancias anteriores
killall -9 waybar 2>/dev/null || true
pkill -9 rofi 2>/dev/null || true
pkill -9 swaync 2>/dev/null || true

sleep 0.3

# 2. Iniciar Waybar a través de Hyprland para que sea un proceso independiente permanente
if command -v hyprctl &>/dev/null; then
    hyprctl dispatch exec waybar >/dev/null 2>&1
    hyprctl dispatch exec swaync >/dev/null 2>&1
else
    nohup waybar >/dev/null 2>&1 &
    nohup swaync >/dev/null 2>&1 &
fi

sleep 0.3
swaync-client --reload-config 2>/dev/null || true

exit 0