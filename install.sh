#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# install.sh
# Run this from Termux (with root/Magisk already set up) to
# install autostart-network.sh into Magisk's service.d.
#
# Usage:
#   bash install.sh
# ============================================================

set -e

SRC="$(dirname "$0")/scripts/autostart-network.sh"
DEST="/data/adb/service.d/autostart-network.sh"

if [ ! -f "$SRC" ]; then
    echo "[!] scripts/autostart-network.sh not found. Run this from the repo root."
    exit 1
fi

echo "[*] This will copy the script to $DEST (needs root)."
echo "[*] Edit scripts/autostart-network.sh FIRST to set your SSID/PASSWORD"
echo "    if you haven't already."
read -p "Continue? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

su -c "mkdir -p /data/adb/service.d"
cat "$SRC" | su -c "cat > $DEST"
su -c "chmod 755 $DEST"

echo "[*] Installed. Reboot your device to test."
echo "[*] After reboot, check the log with:"
echo "    su -c 'cat /data/local/tmp/autostart-network.log'"
