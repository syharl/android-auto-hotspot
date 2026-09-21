#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# reset-listener.sh
# Runs continuously as a normal Termux process (started via
# Termux:Boot, no need to open Termux or unlock the screen).
# Listens on a TCP port; when hit with the right URL + token,
# it triggers network-reset.sh with root — from another phone,
# over the hotspot's own local network, without touching x3nfc.
#
# Requires: `pkg install nmap` (for `ncat`), Termux:Boot app.
# Enable/disable this via `bash menu.sh` -> Pengaturan -> option 7.
# ============================================================

CONFIG=/data/adb/service.d/hotspot-config.sh
HANDLER="$(dirname "$0")/reset-handler.sh"
LOG="$HOME/reset-listener.log"

termux-wake-lock 2>/dev/null

CONFIG_TMP="$(mktemp)"
su -c "cat $CONFIG" > "$CONFIG_TMP" 2>/dev/null
RESET_LISTENER_PORT=8091
RESET_LISTENER_TOKEN=""
# shellcheck source=/dev/null
. "$CONFIG_TMP"
rm -f "$CONFIG_TMP"

if [ -z "$RESET_LISTENER_TOKEN" ]; then
    echo "$(date): RESET_LISTENER_TOKEN kosong — listener tidak dijalankan. Atur lewat menu.sh." >> "$LOG"
    exit 1
fi

if ! command -v ncat > /dev/null 2>&1; then
    echo "$(date): 'ncat' tidak ditemukan. Jalankan: pkg install nmap" >> "$LOG"
    exit 1
fi

export RESET_LISTENER_TOKEN
export RESET_SCRIPT_PATH=/data/adb/service.d/network-reset.sh

echo "$(date): listener started on port $RESET_LISTENER_PORT" >> "$LOG"
exec ncat -lk -p "$RESET_LISTENER_PORT" -e "$HANDLER" >> "$LOG" 2>&1
