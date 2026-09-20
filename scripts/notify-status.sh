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
RESET_SCRIPT="$DIR/network-reset.sh"

TERMUX_PREFIX=/data/data/com.termux/files/usr
TERMUX_HOME=/data/data/com.termux/files/home
TERMUX_NOTIFICATION="$TERMUX_PREFIX/bin/termux-notification"

TITLE="$1"
MESSAGE="$2"

[ -x "$TERMUX_NOTIFICATION" ] || exit 0

# Running from Magisk's root context, so none of Termux's own
# environment variables are set — termux-notification's internal
# ResultReturner callback needs them to find its socket/tmp dir,
# otherwise it fails with "Error in ResultReturner".
export HOME="$TERMUX_HOME"
export PREFIX="$TERMUX_PREFIX"
export TMPDIR="$TERMUX_PREFIX/tmp"
export LD_LIBRARY_PATH="$TERMUX_PREFIX/lib"
export PATH="$TERMUX_PREFIX/bin:$PATH"

"$TERMUX_NOTIFICATION" \
    --id hotspot-status \
    --title "$TITLE" \
    --content "$MESSAGE" \
    --button1 "Reset Jaringan" \
    --button1-action "su -c '/system/bin/sh $RESET_SCRIPT'" \
    --priority high 2>/dev/null
