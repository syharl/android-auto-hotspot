#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# reset-handler.sh
# Invoked once per connection by `ncat -e` (see reset-listener.sh).
# Reads the first line of the HTTP request, checks it against
# RESET_LISTENER_TOKEN (inherited from the parent process), and
# triggers network-reset.sh with root if it matches.
# ============================================================

read -r REQUEST_LINE

if echo "$REQUEST_LINE" | grep -q "GET /reset?key=$RESET_LISTENER_TOKEN "; then
    printf 'HTTP/1.1 200 OK\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nReset jaringan dimulai...\n'
    su -c "/system/bin/sh $RESET_SCRIPT_PATH" &
else
    printf 'HTTP/1.1 403 Forbidden\r\nContent-Type: text/plain; charset=utf-8\r\n\r\nInvalid or missing key.\n'
fi
