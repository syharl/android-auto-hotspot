#!/system/bin/sh
# ============================================================
# restart-hotspot.sh
# Called by the "Restart Hotspot" notification button (via su).
# Re-reads current SSID/password/security and starts the AP.
# ============================================================

DIR="$(dirname "$0")"
CONFIG="$DIR/hotspot-config.sh"

[ -f "$CONFIG" ] || exit 1
# shellcheck source=/dev/null
. "$CONFIG"

/system/bin/cmd wifi start-softap "$SSID" "$SECURITY" "$PASSWORD"
