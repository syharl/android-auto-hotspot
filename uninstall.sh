#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# uninstall.sh
# Removes everything install.sh put in /data/adb/service.d,
# so the hotspot stops auto-starting on boot.
#
# Usage:
#   bash uninstall.sh
# ============================================================

set -e

DEST_DIR="/data/adb/service.d"
TARGETS="$DEST_DIR/autostart-network.sh $DEST_DIR/hotspot-watchdog.sh $DEST_DIR/hotspot-scheduler.sh $DEST_DIR/connectivity-watchdog.sh $DEST_DIR/notify-status.sh $DEST_DIR/network-reset.sh $DEST_DIR/hotspot-config.sh"
LOG=/data/local/tmp/autostart-network.log
WATCHDOG_LOG=/data/local/tmp/hotspot-watchdog.log
SCHEDULER_LOG=/data/local/tmp/hotspot-scheduler.log
RESET_LOG=/data/local/tmp/network-reset.log
CONN_WATCHDOG_LOG=/data/local/tmp/connectivity-watchdog.log

echo "[*] This will remove:"
for f in $TARGETS; do
    echo "    $f"
done
read -p "Continue? [y/N] " CONFIRM
if [ "$CONFIRM" != "y" ] && [ "$CONFIRM" != "Y" ]; then
    echo "Cancelled."
    exit 0
fi

for f in $TARGETS; do
    su -c "rm -f $f"
done
su -c "pkill -f hotspot-watchdog.sh" 2>/dev/null || true
su -c "pkill -f hotspot-scheduler.sh" 2>/dev/null || true
su -c "pkill -f connectivity-watchdog.sh" 2>/dev/null || true
pkill -f "reset-listener.sh" 2>/dev/null || true
rm -f "$HOME/.termux/boot/reset-listener.sh" 2>/dev/null
echo "[*] Removed installed scripts and config."

read -p "Also delete log files (they may contain your SSID)? [y/N] " RMLOG
if [ "$RMLOG" = "y" ] || [ "$RMLOG" = "Y" ]; then
    su -c "rm -f $LOG $WATCHDOG_LOG $SCHEDULER_LOG $RESET_LOG $CONN_WATCHDOG_LOG"
    rm -f "$HOME/reset-listener.log" 2>/dev/null
    echo "[*] Logs removed."
fi

echo
echo "[*] Done. The hotspot will no longer auto-start (or auto-restart) on boot."
echo "[*] Any hotspot running right now stays on until you turn it off yourself."
