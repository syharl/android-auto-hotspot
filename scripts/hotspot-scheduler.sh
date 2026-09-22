#!/system/bin/sh
# ============================================================
# hotspot-scheduler.sh
# Optional. Turns the hotspot off at OFF_HOUR and back on at
# ON_HOUR every day (24h values, e.g. OFF_HOUR=2 ON_HOUR=6).
# Set by install.sh into hotspot-config.sh. If both are unset,
# this script does nothing.
# ============================================================

DIR="$(dirname "$0")"
CONFIG="$DIR/hotspot-config.sh"
LOG=/data/local/tmp/hotspot-scheduler.log
CHECK_INTERVAL=60   # seconds

[ -f "$CONFIG" ] || exit 1
# shellcheck source=/dev/null
. "$CONFIG"

[ -z "$OFF_HOUR" ] && exit 0
[ -z "$ON_HOUR" ] && exit 0

start_hotspot() {
    if [ -n "$BAND" ]; then
        /system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD" -b "$BAND"
    else
        /system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"
    fi
}

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 40   # let autostart-network.sh finish first

{
    echo "scheduler started: $(date), OFF_HOUR=$OFF_HOUR ON_HOUR=$ON_HOUR"
    last_action=""

    while true; do
        hour="$(date +%H | sed 's/^0//')"
        [ -z "$hour" ] && hour=0

        if [ "$hour" = "$OFF_HOUR" ] && [ "$last_action" != "off-$hour" ]; then
            echo "$(date): scheduled OFF"
            /system/bin/cmd wifi stop-softap
            /system/bin/svc data disable
            "$DIR/notify-status.sh" "Hotspot Terjadwal" "Hotspot & data dimatikan sesuai jadwal (jam $OFF_HOUR)." 2>/dev/null
            last_action="off-$hour"
        fi

        if [ "$hour" = "$ON_HOUR" ] && [ "$last_action" != "on-$hour" ]; then
            echo "$(date): scheduled ON"
            /system/bin/svc data enable
            sleep 3
            start_hotspot
            "$DIR/notify-status.sh" "Hotspot Terjadwal" "Data & hotspot dinyalakan sesuai jadwal (jam $ON_HOUR)." 2>/dev/null
            last_action="on-$hour"
        fi

        sleep "$CHECK_INTERVAL"
    done
} >> "$LOG" 2>&1
