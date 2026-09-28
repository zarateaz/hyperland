#!/bin/bash
# /* ---- 💫 https://github.com/JaKooLit 💫 ---- */  ##

# Copied from Discord post. Thanks to @Zorg


# Get id of an active window
if command -v jq >/dev/null 2>&1; then
    active_pid=$(hyprctl -j activewindow 2>/dev/null | jq -r '.pid // empty')
else
    active_pid=$(hyprctl activewindow 2>/dev/null | grep -o 'pid: [0-9]*' | cut -d' ' -f2)
fi

# Close active window
if [[ -n "$active_pid" && "$active_pid" =~ ^[0-9]+$ && "$active_pid" -gt 0 ]]; then
    kill "$active_pid" 2>/dev/null || true
fi