#!/system/bin/sh
# ============================================================
# network-reset.sh
# Called by the "Reset Jaringan" notification button (via su).
# A harder reset than just restarting the hotspot — mimics what
# happens on a normal reboot's radio init sequence:
#   1. Stop the hotspot
#   2. Disable mobile data
#   3. Turn airplane mode ON
#   4. Turn airplane mode OFF
#   5. Enable mobile data
#   6. Start the hotspot again
#
# Every wait below polls an actual condition instead of a fixed
# `sleep`, same philosophy as autostart-network.sh.
# ============================================================

DIR="$(dirname "$0")"
CONFIG="$DIR/hotspot-config.sh"
NOTIFY="$DIR/notify-status.sh"
LOG=/data/local/tmp/network-reset.log

[ -f "$CONFIG" ] || exit 1
# shellcheck source=/dev/null
. "$CONFIG"

wait_for() {
    # $1 = description (for the log)
    # $2 = shell condition to eval; loops until it's true
    # $3 = retry limit (default 15 => up to 30s)
    desc="$1"
    cond="$2"
    limit="${3:-15}"
    i=0
    while ! eval "$cond"; do
        sleep 2
        i=$((i + 1))
        if [ "$i" -ge "$limit" ]; then
            echo "   WARNING: '$desc' not confirmed after $((limit * 2))s — proceeding anyway"
            return 1
        fi
    done
    return 0
}

{
    echo "1. reset start: $(date)"
    "$NOTIFY" "Reset Jaringan" "Sedang reset jaringan, mohon tunggu..." 2>/dev/null

    /system/bin/cmd wifi stop-softap
    echo "2. hotspot stopped: $(date)"

    /system/bin/svc data disable
    echo "3. mobile data disabled: $(date)"

    settings put global airplane_mode_on 1
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state true > /dev/null 2>&1
    wait_for "airplane mode on" '[ "$(settings get global airplane_mode_on)" = "1" ]'
    echo "4. airplane mode ON confirmed: $(date)"

    settings put global airplane_mode_on 0
    am broadcast -a android.intent.action.AIRPLANE_MODE --ez state false > /dev/null 2>&1
    wait_for "airplane mode off" '[ "$(settings get global airplane_mode_on)" = "0" ]'
    echo "5. airplane mode OFF confirmed: $(date)"

    # Give the modem a moment to come back and re-register the SIM
    # before touching data/hotspot again.
    wait_for "sim/radio back up" '
        state="$(getprop gsm.sim.state)"
        [ "$state" = "LOADED" ] || [ "$state" = "READY" ]
    ' 30
    echo "6. radio state: $(getprop gsm.sim.state) - $(date)"

    /system/bin/svc data enable
    echo "7. mobile data re-enabled: $(date)"

    wait_for "wifi service" '/system/bin/service check wifi | grep -q found'
    /system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"
    echo "8. hotspot restarted: $(date)"

    "$NOTIFY" "Reset Jaringan Selesai" "$SSID sudah nyala lagi setelah reset jaringan penuh." 2>/dev/null

} >> "$LOG" 2>&1
