#!/system/bin/sh
# ============================================================
# autostart-network.sh
# Auto-enable mobile data + Wi-Fi hotspot right after boot,
# on rooted Android (Magisk service.d).
#
# WHY THIS EXISTS:
# Android doesn't expose a toggle for "turn hotspot on at every
# boot". This script waits for the actual system services
# (telephony, wifi) to be ready — not a blind sleep — then
# enables data and starts the hotspot using the SoftAp config
# you provide below.
# ============================================================

# --- EDIT THESE TWO LINES -----------------------------------
SSID="YourHotspotName"
PASSWORD="YourHotspotPassword"
# Security type: wpa2 | wpa3 | open
SECURITY="wpa2"
# --------------------------------------------------------------

LOG=/data/local/tmp/autostart-network.log

{
    echo "1. start: $(date)"

    # Wait for full boot completion
    while [ "$(getprop sys.boot_completed)" != "1" ]; do
        sleep 2
    done
    echo "2. boot_completed: $(date)"

    # Wait for the telephony ('phone') service to be registered
    i=0
    while ! /system/bin/service check phone | grep -q found; do
        sleep 2
        i=$((i + 1))
        [ "$i" -ge 30 ] && break
    done
    echo "3. phone service: $(/system/bin/service check phone) - $(date)"

    /system/bin/svc data enable
    echo "4. mobile data enabled: $(date)"

    # Wait for the wifi service to be registered
    i=0
    while ! /system/bin/service check wifi | grep -q found; do
        sleep 2
        i=$((i + 1))
        [ "$i" -ge 30 ] && break
    done
    echo "5. wifi service: $(/system/bin/service check wifi) - $(date)"

    sleep 5
    /system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"
    echo "6. hotspot command sent: $(date)"

} > "$LOG" 2>&1
