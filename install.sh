#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# install.sh
# First-time setup. Only asks for SSID/password if no config
# exists yet — if you've installed before, it just reuses your
# saved SSID/password/settings and (re)installs the scripts.
#
# For changing SSID/password/security, or toggling the watchdog
# and schedule, use the control panel instead:
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
SRC_WATCHDOG="$SCRIPT_DIR/scripts/hotspot-watchdog.sh"
SRC_SCHEDULER="$SCRIPT_DIR/scripts/hotspot-scheduler.sh"
DEST_DIR="/data/adb/service.d"
DEST_MAIN="$DEST_DIR/autostart-network.sh"
DEST_NOTIFY="$DEST_DIR/notify-status.sh"
DEST_RESET="$DEST_DIR/network-reset.sh"
DEST_WATCHDOG="$DEST_DIR/hotspot-watchdog.sh"
DEST_SCHEDULER="$DEST_DIR/hotspot-scheduler.sh"
DEST_CONFIG="$DEST_DIR/hotspot-config.sh"

if [ ! -f "$SRC_MAIN" ]; then
    echo "[!] scripts/autostart-network.sh not found. Run this from the repo root."
    exit 1
fi

echo "=== Hotspot autostart setup ==="

if su -c "[ -f $DEST_CONFIG ]" 2>/dev/null; then
    echo "[*] Konfigurasi lama ditemukan — pakai SSID/password yang sudah ada."
    CONFIG_TMP="$(mktemp)"
    su -c "cat $DEST_CONFIG" > "$CONFIG_TMP"
    WATCHDOG_ENABLED=0
    OFF_HOUR=""
    ON_HOUR=""
    # shellcheck source=/dev/null
    . "$CONFIG_TMP"
    rm -f "$CONFIG_TMP"
    echo "    SSID: $SSID"
else
    read -p "SSID: " SSID
    read -s -p "Password: " PASSWORD
    echo
    SECURITY="wpa2"
    WATCHDOG_ENABLED=0
    OFF_HOUR=""
    ON_HOUR=""
fi

echo
echo "[*] This will copy files into $DEST_DIR (needs root)."
read -p "Continue? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

su -c "mkdir -p $DEST_DIR"

# --- write/rewrite config ---
CONFIG_TMP="$(mktemp)"
{
    echo "SSID=\"$SSID\""
    echo "PASSWORD=\"$PASSWORD\""
    echo "SECURITY=\"$SECURITY\""
    echo "WATCHDOG_ENABLED=$WATCHDOG_ENABLED"
    if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ]; then
        echo "OFF_HOUR=$OFF_HOUR"
        echo "ON_HOUR=$ON_HOUR"
    fi
} > "$CONFIG_TMP"
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

# --- restore watchdog/schedule if they were previously enabled ---
if [ "$WATCHDOG_ENABLED" = "1" ] && [ -f "$SRC_WATCHDOG" ]; then
    cat "$SRC_WATCHDOG" | su -c "cat > $DEST_WATCHDOG"
    su -c "chmod 700 $DEST_WATCHDOG"
    echo "[*] Watchdog dipasang ulang (sebelumnya aktif)."
fi
if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ] && [ -f "$SRC_SCHEDULER" ]; then
    cat "$SRC_SCHEDULER" | su -c "cat > $DEST_SCHEDULER"
    su -c "chmod 700 $DEST_SCHEDULER"
    echo "[*] Jadwal dipasang ulang (mati $OFF_HOUR:00, nyala $ON_HOUR:00)."
fi

echo
echo "[*] Done. Reboot to test:"
echo "    su -c /system/bin/reboot"
echo "[*] After reboot, check logs with:"
echo "    su -c 'cat /data/local/tmp/autostart-network.log'"
echo
echo "[*] Untuk ganti SSID/password/security, watchdog, jadwal, atau"
echo "    uninstall — semuanya lewat panel kontrol:"
echo "    bash menu.sh"
