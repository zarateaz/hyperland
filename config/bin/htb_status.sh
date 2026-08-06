#!/bin/bash

HTB_ICON="❖"
THM_ICON="♰"
VPN_ICON="X"
DISCONNECTED_ICON="✗"

get_vpn_iface() {
    ip -o link show 2>/dev/null | awk -F': ' 'BEGIN{IGNORECASE=1} $2 ~ /^(tun|utun|wg|tap|vpn)/ {print $2; exit}'
}

get_ip() {
    ip -4 addr show "$1" 2>/dev/null | awk '/inet / {print $2}' | cut -d/ -f1
}

get_psiphon_ip() {
    local services=(
        "https://api.ipify.org"
        "https://icanhazip.com"
        "https://ifconfig.me"
    )
    for service in "${services[@]}"; do
        local ip
        ip=$(curl -s --socks5-hostname 127.0.0.1:1081 --connect-timeout 2 --max-time 3 "$service" 2>/dev/null)
        if [[ "$ip" =~ ^[0-9]+\.[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
            echo "$ip"
            return 0
        fi
    done
    return 1
}

VPN_IF=$(get_vpn_iface)

if [ -n "$VPN_IF" ]; then
    VPN_IP=$(get_ip "$VPN_IF")
    if pgrep -a openvpn | grep -Eiq 'htb|hackthebox'; then
        echo "$HTB_ICON $VPN_IP"
    elif pgrep -a openvpn | grep -Eiq 'tryhackme|thm'; then
        echo "$THM_ICON $VPN_IP"
    else
        echo "$VPN_ICON $VPN_IP"
    fi
    exit 0
fi

# Check if Psiphon is running
if pgrep -f psiphon-tunnel-core >/dev/null || pgrep -x psiphonlinuxgui >/dev/null; then
    PSIPHON_IP=$(get_psiphon_ip)
    if [ -n "$PSIPHON_IP" ]; then
        echo "$VPN_ICON $PSIPHON_IP"
        exit 0
    fi
fi

echo "$DISCONNECTED_ICON sin vpn"

