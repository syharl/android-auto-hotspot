#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# install.sh
# Minimal installer — only asks for SSID and password.
# Security defaults to wpa2. Watchdog, schedule, and any later
# changes to SSID/password/security are all handled afterward
# by the interactive settings menu:
#
#   bash menu.sh
#
# Usage:
#   bash install.sh
# ============================================================

set -e

SCRIPT_DIR="$(dirname "$0")"
SRC_MAIN="$SCRIPT_DIR/scripts/autostart-network.sh"
SRC_NOTIFY="$SCRIPT_DIR/scripts/notify-status.sh"
SRC_RESET="$SCRIPT_DIR/scripts/network-reset.sh"
DEST_DIR="/data/adb/service.d"
DEST_MAIN="$DEST_DIR/autostart-network.sh"
DEST_NOTIFY="$DEST_DIR/notify-status.sh"
DEST_RESET="$DEST_DIR/network-reset.sh"
DEST_CONFIG="$DEST_DIR/hotspot-config.sh"

if [ ! -f "$SRC_MAIN" ]; then
    echo "[!] scripts/autostart-network.sh not found. Run this from the repo root."
    exit 1
fi

echo "=== Hotspot autostart setup ==="
read -p "SSID: " SSID
read -s -p "Password: " PASSWORD
echo
SECURITY="wpa2"

echo
echo "[*] This will copy files into $DEST_DIR (needs root)."
read -p "Continue? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

su -c "mkdir -p $DEST_DIR"

# --- write config (SSID/password live here, not in the scripts) ---
CONFIG_TMP="$(mktemp)"
cat > "$CONFIG_TMP" <<EOF
SSID="$SSID"
PASSWORD="$PASSWORD"
SECURITY="$SECURITY"
EOF
cat "$CONFIG_TMP" | su -c "cat > $DEST_CONFIG"
rm -f "$CONFIG_TMP"
su -c "chmod 700 $DEST_CONFIG"
echo "[*] Wrote $DEST_CONFIG"

# --- install main autostart script + always-safe helpers ---
cat "$SRC_MAIN" | su -c "cat > $DEST_MAIN"
su -c "chmod 700 $DEST_MAIN"
cat "$SRC_NOTIFY" | su -c "cat > $DEST_NOTIFY"
su -c "chmod 700 $DEST_NOTIFY"
cat "$SRC_RESET" | su -c "cat > $DEST_RESET"
su -c "chmod 700 $DEST_RESET"
echo "[*] Installed $DEST_MAIN"

echo
echo "[*] Done. Security defaults to wpa2. Reboot to test:"
echo "    su -c /system/bin/reboot"
echo "[*] After reboot, check logs with:"
echo "    su -c 'cat /data/local/tmp/autostart-network.log'"
echo
echo "[*] Want to change SSID/password/security later, enable the"
echo "    idle-timeout watchdog, or set a daily off/on schedule?"
echo "    bash menu.sh"
