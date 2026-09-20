#!/system/bin/sh
# ============================================================
# notify-status.sh
# Optional helper: sends an Android notification with a
# "Restart Hotspot" button, via Termux:API.
#
# Requires (on the phone):
#   - Termux:API app installed (separate from Termux itself)
#   - `pkg install termux-api` run once inside Termux
# If either is missing, this script exits quietly and does
# nothing — it never blocks the boot sequence.
#
# Usage: notify-status.sh "<title>" "<message>"
# ============================================================

DIR="$(dirname "$0")"
RESTART_SCRIPT="$DIR/restart-hotspot.sh"
TERMUX_NOTIFICATION=/data/data/com.termux/files/usr/bin/termux-notification

TITLE="$1"
MESSAGE="$2"

[ -x "$TERMUX_NOTIFICATION" ] || exit 0

"$TERMUX_NOTIFICATION" \
    --id hotspot-status \
    --title "$TITLE" \
    --content "$MESSAGE" \
    --button1 "Restart Hotspot" \
    --button1-action "su -c '/system/bin/sh $RESTART_SCRIPT'" \
    --priority high 2>/dev/null
