#!/system/bin/sh
# ============================================================
# network-reset.sh
# Fast, fixed-timing network reset — finishes in ~10 seconds.
# No polling/waiting for confirmation at each step; just a fixed
# schedule of sleeps between commands:
#   t=1s  : disable mobile data
#   t=2s  : stop hotspot
#   t=3s  : airplane mode ON
#   t=6s  : airplane mode OFF   (3s in airplane mode)
#   t=9s  : re-enable mobile data
#   t=10s : start hotspot again
#
# This trades the previous adaptive-polling approach (which could
# take up to ~45s waiting for confirmations) for a short, fixed
# schedule. If your device's radio needs more time than this to
# actually reconnect, the hotspot will still start on schedule —
# actual internet may take a few extra seconds to catch up in the
# background, which is normal and not something this script blocks on.
# ============================================================

DIR="$(dirname "$0")"
CONFIG="$DIR/hotspot-config.sh"
NOTIFY="$DIR/notify-status.sh"
LOG=/data/local/tmp/network-reset.log

[ -f "$CONFIG" ] || exit 1
# shellcheck source=/dev/null
. "$CONFIG"

{
    echo "reset start: $(date)"
    "$NOTIFY" "Reset Jaringan" "Sedang reset jaringan (~10 detik)..." 2>/dev/null &

    sleep 1
    /system/bin/svc data disable
    echo "t=1s: mobile data disabled"

    sleep 1
    /system/bin/cmd wifi stop-softap
    echo "t=2s: hotspot stopped"

    sleep 1
    settings put global airplane_mode_on 1
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true > /dev/null 2>&1
    echo "t=3s: airplane mode ON"

    sleep 3
    settings put global airplane_mode_on 0
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false > /dev/null 2>&1
    echo "t=6s: airplane mode OFF"

    sleep 3
    /system/bin/svc data enable
    echo "t=9s: mobile data re-enabled"

    sleep 1
    /system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"
    echo "t=10s: hotspot restarted"

    "$NOTIFY" "Reset Jaringan Selesai" "$SSID sudah nyala lagi." 2>/dev/null &

    echo "reset done: $(date)"
} >> "$LOG" 2>&1
