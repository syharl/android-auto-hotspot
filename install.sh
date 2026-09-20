#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# install.sh
# Interactive installer. Prompts for your hotspot SSID/password
# and (optionally) enables the idle-timeout watchdog.
# Safe to re-run any time you want to change SSID/password/
# security or toggle the watchdog — no nano needed.
#
# Usage:
#   bash install.sh
# ============================================================

set -e

SCRIPT_DIR="$(dirname "$0")"
SRC_MAIN="$SCRIPT_DIR/scripts/autostart-network.sh"
SRC_WATCHDOG="$SCRIPT_DIR/scripts/hotspot-watchdog.sh"
SRC_SCHEDULER="$SCRIPT_DIR/scripts/hotspot-scheduler.sh"
SRC_NOTIFY="$SCRIPT_DIR/scripts/notify-status.sh"
SRC_RESET="$SCRIPT_DIR/scripts/network-reset.sh"
DEST_DIR="/data/adb/service.d"
DEST_MAIN="$DEST_DIR/autostart-network.sh"
DEST_WATCHDOG="$DEST_DIR/hotspot-watchdog.sh"
DEST_SCHEDULER="$DEST_DIR/hotspot-scheduler.sh"
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
read -p "Security [wpa2/wpa3/open] (default: wpa2): " SECURITY
SECURITY=${SECURITY:-wpa2}
echo
read -p "Auto-restart hotspot if it turns itself off from idle timeout? [y/N] " WANT_WATCHDOG
echo
read -p "Schedule automatic off/on at fixed hours each day? [y/N] " WANT_SCHEDULE
if [ "$WANT_SCHEDULE" = "y" ] || [ "$WANT_SCHEDULE" = "Y" ]; then
    read -p "  Turn OFF at hour (0-23): " OFF_HOUR
    read -p "  Turn back ON at hour (0-23): " ON_HOUR
fi

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
if [ "$WANT_SCHEDULE" = "y" ] || [ "$WANT_SCHEDULE" = "Y" ]; then
    {
        echo "OFF_HOUR=$OFF_HOUR"
        echo "ON_HOUR=$ON_HOUR"
    } >> "$CONFIG_TMP"
fi
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

# --- install or remove the watchdog ---
if [ "$WANT_WATCHDOG" = "y" ] || [ "$WANT_WATCHDOG" = "Y" ]; then
    if [ ! -f "$SRC_WATCHDOG" ]; then
        echo "[!] scripts/hotspot-watchdog.sh not found — skipping watchdog install."
    else
        cat "$SRC_WATCHDOG" | su -c "cat > $DEST_WATCHDOG"
        su -c "chmod 700 $DEST_WATCHDOG"
        echo "[*] Installed $DEST_WATCHDOG (auto-restart on idle timeout enabled)"
    fi
else
    su -c "rm -f $DEST_WATCHDOG" 2>/dev/null || true
    echo "[*] Watchdog not enabled (removed if previously installed)."
fi

# --- install or remove the scheduler ---
if [ "$WANT_SCHEDULE" = "y" ] || [ "$WANT_SCHEDULE" = "Y" ]; then
    if [ ! -f "$SRC_SCHEDULER" ]; then
        echo "[!] scripts/hotspot-scheduler.sh not found — skipping scheduler install."
    else
        cat "$SRC_SCHEDULER" | su -c "cat > $DEST_SCHEDULER"
        su -c "chmod 700 $DEST_SCHEDULER"
        echo "[*] Installed $DEST_SCHEDULER (off at $OFF_HOUR:00, on at $ON_HOUR:00 daily)"
    fi
else
    su -c "rm -f $DEST_SCHEDULER" 2>/dev/null || true
fi

echo
echo "[*] Done. Reboot to test:"
echo "    su -c /system/bin/reboot"
echo "[*] After reboot, check logs with:"
echo "    su -c 'cat /data/local/tmp/autostart-network.log'"
[ -f "$SRC_WATCHDOG" ] && echo "    su -c 'cat /data/local/tmp/hotspot-watchdog.log'"
