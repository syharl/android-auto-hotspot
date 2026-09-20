#!/system/bin/sh
# ============================================================
# hotspot-watchdog.sh
# Optional. Watches for the hotspot turning off by itself
# (Android's "turn off hotspot automatically" idle timer) and
# restarts it — WITHOUT restarting it if you turn it off
# yourself via Settings / quick-settings tile.
#
# HOW IT DECIDES "idle timeout" vs "manual":
# When the hotspot state flips from on->off, this script scans
# recent logcat for lines that look like the system's own
# idle-timeout message (matches "softap"/"wifiap" + "timeout"
# or "idle"). If found -> treat as auto-shutoff, restart it.
# If not found -> assume you turned it off on purpose, leave
# it off. This is a best-effort heuristic — the exact log
# wording can differ by ROM/Android version. If it doesn't
# behave correctly on your device, run:
#   logcat -d | grep -i softap
# right after an idle auto-shutoff to find the real message,
# then adjust the grep pattern below.
# ============================================================

DIR="$(dirname "$0")"
CONFIG="$DIR/hotspot-config.sh"
LOG=/data/local/tmp/hotspot-watchdog.log
POLL_INTERVAL=15   # seconds between checks

if [ ! -f "$CONFIG" ]; then
    echo "$(date): hotspot-config.sh not found, exiting" > "$LOG"
    exit 1
fi
# shellcheck source=/dev/null
. "$CONFIG"

while [ "$(getprop sys.boot_completed)" != "1" ]; do
    sleep 2
done
# let autostart-network.sh finish its own boot sequence first
sleep 40

{
    echo "watchdog started: $(date)"
    was_on=1   # autostart-network.sh should have just turned it on

    while true; do
        sleep "$POLL_INTERVAL"

        state="$(dumpsys wifi 2>/dev/null | grep -i "Wifi AP state" | head -n1)"
        is_on=0
        echo "$state" | grep -qi "enabled" && is_on=1

        if [ "$was_on" = "1" ] && [ "$is_on" = "0" ]; then
            reason="$(logcat -d -t 400 2>/dev/null | grep -iE "softap|wifiap" | grep -iE "timeout|idle" | tail -n1)"
            if [ -n "$reason" ]; then
                echo "$(date): idle auto-shutoff detected, restarting hotspot"
                echo "  matched log line: $reason"
                sleep 3
                /system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"
                "$DIR/notify-status.sh" "Hotspot Auto-Restart" "$SSID mati sendiri (idle timeout), sudah dinyalakan ulang otomatis." 2>/dev/null
            else
                echo "$(date): hotspot turned off, no idle-timeout signature in recent logs — assuming manual, not restarting"
            fi
        fi

        was_on="$is_on"
    done
} >> "$LOG" 2>&1
