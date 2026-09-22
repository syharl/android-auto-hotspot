#!/system/bin/sh
# ============================================================
# connectivity-watchdog.sh
# Optional. Different from hotspot-watchdog.sh — this one checks
# actual internet reachability (a real ping), not just whether
# the hotspot radio is on. Fixes the case where the hotspot stays
# connected but mobile data silently stops passing traffic (a
# flaky-signal issue), without needing anyone to touch a screen.
#
# If pings fail FAIL_THRESHOLD times in a row, it runs the full
# network-reset.sh automatically, then cools down before checking
# again so it doesn't loop resets back-to-back if the outage is
# longer than expected. The cooldown escalates: 3 minutes after the
# first reset in a streak, 10 minutes for every reset after that
# (until internet is confirmed working again) — since retrying every
# 3 minutes is pointless if the problem is upstream (e.g. a real
# outage) rather than something a local reset can fix.
#
# IMPORTANT: if a daily schedule (OFF_HOUR/ON_HOUR) is also active,
# this watchdog pauses itself during the scheduled-off window —
# otherwise it would "fix" the deliberate off period within about a
# minute and defeat the schedule entirely.
# ============================================================

DIR="$(dirname "$0")"
CONFIG="$DIR/hotspot-config.sh"
RESET_SCRIPT="$DIR/network-reset.sh"
NOTIFY="$DIR/notify-status.sh"
LOG=/data/local/tmp/connectivity-watchdog.log
CHECK_INTERVAL=20        # seconds between checks
FAIL_THRESHOLD=3         # consecutive failed checks before triggering a reset
COOLDOWN_FIRST=180       # 3 minutes after the first reset in a streak
COOLDOWN_SUBSEQUENT=600  # 10 minutes after every reset after that

[ -f "$CONFIG" ] || exit 1
# shellcheck source=/dev/null
. "$CONFIG"

in_scheduled_off_window() {
    [ -z "$OFF_HOUR" ] && return 1
    [ -z "$ON_HOUR" ] && return 1
    hour="$(date +%H | sed 's/^0//')"
    [ -z "$hour" ] && hour=0
    if [ "$OFF_HOUR" -lt "$ON_HOUR" ]; then
        [ "$hour" -ge "$OFF_HOUR" ] && [ "$hour" -lt "$ON_HOUR" ]
    else
        [ "$hour" -ge "$OFF_HOUR" ] || [ "$hour" -lt "$ON_HOUR" ]
    fi
}

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
sleep 40   # let autostart-network.sh finish first

check_internet() {
    /system/bin/ping -c 1 -W 3 8.8.8.8 > /dev/null 2>&1
}

{
    echo "connectivity watchdog started: $(date)"
    fail_count=0
    reset_streak=0

    while true; do
        sleep "$CHECK_INTERVAL"

        if in_scheduled_off_window; then
            fail_count=0
            reset_streak=0
            continue
        fi

        if check_internet; then
            fail_count=0
            reset_streak=0
        else
            fail_count=$((fail_count + 1))
            echo "$(date): ping gagal ($fail_count/$FAIL_THRESHOLD)"
            if [ "$fail_count" -ge "$FAIL_THRESHOLD" ]; then
                reset_streak=$((reset_streak + 1))
                echo "$(date): internet dianggap mati, menjalankan reset jaringan otomatis (percobaan ke-$reset_streak)"
                "$NOTIFY" "Internet Terputus" "Terdeteksi mati, menjalankan Reset Jaringan otomatis (percobaan ke-$reset_streak)..." 2>/dev/null
                /system/bin/sh "$RESET_SCRIPT"
                fail_count=0
                if [ "$reset_streak" -le 1 ]; then
                    cooldown="$COOLDOWN_FIRST"
                else
                    cooldown="$COOLDOWN_SUBSEQUENT"
                fi
                echo "$(date): reset otomatis selesai, cooldown ${cooldown}s sebelum cek lagi"
                sleep "$cooldown"
            fi
        fi
    done
} >> "$LOG" 2>&1
