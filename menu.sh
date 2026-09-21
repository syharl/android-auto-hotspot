#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# menu.sh
# Interactive control panel for android-auto-hotspot.
# Press a number key — no Enter needed for menu navigation.
#
# Usage:
#   bash menu.sh
# ============================================================

SCRIPT_DIR="$(dirname "$0")"
DEST_DIR="/data/adb/service.d"
DEST_MAIN="$DEST_DIR/autostart-network.sh"
DEST_NOTIFY="$DEST_DIR/notify-status.sh"
DEST_RESET="$DEST_DIR/network-reset.sh"
DEST_WATCHDOG="$DEST_DIR/hotspot-watchdog.sh"
DEST_SCHEDULER="$DEST_DIR/hotspot-scheduler.sh"
DEST_CONFIG="$DEST_DIR/hotspot-config.sh"
SRC_MAIN="$SCRIPT_DIR/scripts/autostart-network.sh"
SRC_NOTIFY="$SCRIPT_DIR/scripts/notify-status.sh"
SRC_RESET="$SCRIPT_DIR/scripts/network-reset.sh"
SRC_WATCHDOG="$SCRIPT_DIR/scripts/hotspot-watchdog.sh"
SRC_SCHEDULER="$SCRIPT_DIR/scripts/hotspot-scheduler.sh"
LOG=/data/local/tmp/autostart-network.log
WATCHDOG_LOG=/data/local/tmp/hotspot-watchdog.log
SCHEDULER_LOG=/data/local/tmp/hotspot-scheduler.log
RESET_LOG=/data/local/tmp/network-reset.log

# --- single-keypress read helper ---
press_key() {
    # $1 = prompt text. Reads exactly one character, no Enter needed.
    read -n 1 -r -p "$1" KEY
    echo
}

pause() {
    read -n 1 -r -s -p "Tekan tombol apa saja untuk lanjut..."
    echo
}

mask() {
    printf '%s' "$1" | sed 's/./*/g'
}

config_exists() {
    su -c "[ -f $DEST_CONFIG ]" 2>/dev/null
}

load_config() {
    SSID=""; PASSWORD=""; SECURITY="wpa2"; WATCHDOG_ENABLED=0; OFF_HOUR=""; ON_HOUR=""
    RESET_LISTENER_ENABLED=0; RESET_LISTENER_PORT=8091; RESET_LISTENER_TOKEN=""
    if config_exists; then
        CONFIG_TMP="$(mktemp)"
        su -c "cat $DEST_CONFIG" > "$CONFIG_TMP"
        # shellcheck source=/dev/null
        . "$CONFIG_TMP"
        rm -f "$CONFIG_TMP"
    fi
}

save_config() {
    CONFIG_TMP="$(mktemp)"
    {
        echo "SSID=\"$SSID\""
        echo "PASSWORD=\"$PASSWORD\""
        echo "SECURITY=\"$SECURITY\""
        echo "WATCHDOG_ENABLED=$WATCHDOG_ENABLED"
        if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ]; then
            echo "OFF_HOUR=$OFF_HOUR"
            echo "ON_HOUR=$ON_HOUR"
        fi
        echo "RESET_LISTENER_ENABLED=$RESET_LISTENER_ENABLED"
        echo "RESET_LISTENER_PORT=$RESET_LISTENER_PORT"
        [ -n "$RESET_LISTENER_TOKEN" ] && echo "RESET_LISTENER_TOKEN=$RESET_LISTENER_TOKEN"
    } > "$CONFIG_TMP"
    su -c "mkdir -p $DEST_DIR"
    cat "$CONFIG_TMP" | su -c "cat > $DEST_CONFIG"
    rm -f "$CONFIG_TMP"
    su -c "chmod 700 $DEST_CONFIG"
}

is_autostart_on() {
    su -c "[ -f $DEST_MAIN ]" 2>/dev/null
}

apply_watchdog() {
    # Installs or removes hotspot-watchdog.sh to match WATCHDOG_ENABLED,
    # but only if autostart itself is currently on.
    if ! is_autostart_on; then
        return
    fi
    if [ "$WATCHDOG_ENABLED" = "1" ] && [ -f "$SRC_WATCHDOG" ]; then
        cat "$SRC_WATCHDOG" | su -c "cat > $DEST_WATCHDOG"
        su -c "chmod 700 $DEST_WATCHDOG"
    else
        su -c "rm -f $DEST_WATCHDOG" 2>/dev/null
    fi
}

apply_schedule() {
    # Installs or removes hotspot-scheduler.sh to match OFF_HOUR/ON_HOUR,
    # but only if autostart itself is currently on.
    if ! is_autostart_on; then
        return
    fi
    if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ] && [ -f "$SRC_SCHEDULER" ]; then
        cat "$SRC_SCHEDULER" | su -c "cat > $DEST_SCHEDULER"
        su -c "chmod 700 $DEST_SCHEDULER"
    else
        su -c "rm -f $DEST_SCHEDULER" 2>/dev/null
    fi
}

turn_on() {
    if ! config_exists; then
        echo "Belum ada SSID/password tersimpan. Isi dulu:"
        read -p "SSID: " SSID
        read -s -p "Password: " PASSWORD
        echo
        SECURITY="wpa2"
        WATCHDOG_ENABLED=0
        OFF_HOUR=""
        ON_HOUR=""
        save_config
    fi
    su -c "mkdir -p $DEST_DIR"
    cat "$SRC_MAIN" | su -c "cat > $DEST_MAIN"
    su -c "chmod 700 $DEST_MAIN"
    cat "$SRC_NOTIFY" | su -c "cat > $DEST_NOTIFY"
    su -c "chmod 700 $DEST_NOTIFY"
    cat "$SRC_RESET" | su -c "cat > $DEST_RESET"
    su -c "chmod 700 $DEST_RESET"
    apply_watchdog
    apply_schedule
    echo "[*] Autostart Hotspot: AKTIF. Reboot agar berlaku (su -c /system/bin/reboot)."
}

turn_off() {
    su -c "rm -f $DEST_MAIN $DEST_NOTIFY $DEST_RESET $DEST_WATCHDOG $DEST_SCHEDULER" 2>/dev/null
    echo "[*] Autostart Hotspot: MATI. SSID/password/pengaturan tetap tersimpan."
}

toggle_autostart() {
    if is_autostart_on; then
        turn_off
    else
        turn_on
    fi
}

stop_listener() {
    pkill -f "reset-listener.sh" 2>/dev/null
    rm -f "$HOME/.termux/boot/reset-listener.sh"
}

start_listener_now() {
    nohup bash "$SCRIPT_DIR/scripts/reset-listener.sh" > /dev/null 2>&1 &
}

toggle_reset_listener() {
    if [ "$RESET_LISTENER_ENABLED" = "1" ]; then
        RESET_LISTENER_ENABLED=0
        save_config
        stop_listener
        echo "[*] Remote Reset Listener dimatikan."
        return
    fi

    if ! command -v ncat > /dev/null 2>&1; then
        echo "[!] 'ncat' belum terinstall. Jalankan dulu: pkg install nmap"
        return
    fi

    [ -z "$RESET_LISTENER_TOKEN" ] && RESET_LISTENER_TOKEN="$RANDOM$RANDOM"
    [ -z "$RESET_LISTENER_PORT" ] && RESET_LISTENER_PORT=8091
    RESET_LISTENER_ENABLED=1
    save_config

    pkill -f "reset-listener.sh" 2>/dev/null
    mkdir -p "$HOME/.termux/boot"
    cat > "$HOME/.termux/boot/reset-listener.sh" <<EOF
#!/data/data/com.termux/files/usr/bin/bash
exec bash "$SCRIPT_DIR/scripts/reset-listener.sh"
EOF
    chmod +x "$HOME/.termux/boot/reset-listener.sh"
    start_listener_now

    echo "[*] Remote Reset Listener AKTIF (port $RESET_LISTENER_PORT)."
    echo "    Dari F6 (konek ke hotspot x3nfc), buka di browser:"
    echo "    http://<ip-hotspot-x3nfc>:$RESET_LISTENER_PORT/reset?key=$RESET_LISTENER_TOKEN"
    echo "    Cek IP hotspot lewat: pengaturan WiFi F6 -> detail koneksi -> Gateway"
    echo "    (biasanya 192.168.43.1, tapi cek dulu biar pasti)"
}

settings_menu() {
    while true; do
        load_config
        clear 2>/dev/null
        echo "=== Pengaturan ==="
        echo "SSID      : $SSID"
        echo "Password  : $(mask "$PASSWORD")"
        echo "Security  : $SECURITY"
        [ "$WATCHDOG_ENABLED" = "1" ] && WSTAT="AKTIF" || WSTAT="nonaktif"
        echo "Watchdog  : $WSTAT"
        if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ]; then
            echo "Jadwal    : mati $OFF_HOUR:00, nyala $ON_HOUR:00"
        else
            echo "Jadwal    : nonaktif"
        fi
        if [ "$RESET_LISTENER_ENABLED" = "1" ]; then
            echo "Remote Reset Listener : AKTIF (port $RESET_LISTENER_PORT)"
        else
            echo "Remote Reset Listener : nonaktif"
        fi
        echo
        echo "[1] Ganti SSID"
        echo "[2] Ganti Password"
        echo "[3] Ganti Security (wpa2/wpa3/open)"
        echo "[4] Toggle Watchdog"
        echo "[5] Atur Jadwal Off/On"
        echo "[6] Nonaktifkan Jadwal"
        echo "[7] Toggle Remote Reset Listener (trigger dari HP lain)"
        echo "[0] Kembali"
        press_key "Pilih: "

        case "$KEY" in
            1)
                read -p "SSID baru: " NEW_VAL
                [ -n "$NEW_VAL" ] && SSID="$NEW_VAL"
                save_config
                echo "[*] SSID diperbarui dan langsung diterapkan."
                is_autostart_on && echo "    (tekan 'Reset Jaringan' di notifikasi, atau reboot, untuk memakainya sekarang)"
                pause
                ;;
            2)
                read -s -p "Password baru: " NEW_VAL
                echo
                [ -n "$NEW_VAL" ] && PASSWORD="$NEW_VAL"
                save_config
                echo "[*] Password diperbarui dan langsung diterapkan."
                is_autostart_on && echo "    (tekan 'Reset Jaringan' di notifikasi, atau reboot, untuk memakainya sekarang)"
                pause
                ;;
            3)
                read -p "Security [wpa2/wpa3/open]: " NEW_VAL
                [ -n "$NEW_VAL" ] && SECURITY="$NEW_VAL"
                save_config
                echo "[*] Security diperbarui dan langsung diterapkan."
                pause
                ;;
            4)
                if [ "$WATCHDOG_ENABLED" = "1" ]; then
                    WATCHDOG_ENABLED=0
                else
                    WATCHDOG_ENABLED=1
                fi
                save_config
                apply_watchdog
                if is_autostart_on; then
                    echo "[*] Watchdog diperbarui dan langsung diterapkan."
                else
                    echo "[*] Watchdog disimpan, akan aktif begitu Autostart dinyalakan."
                fi
                pause
                ;;
            5)
                read -p "  Matikan jam berapa (0-23): " OFF_HOUR
                read -p "  Nyalakan jam berapa (0-23): " ON_HOUR
                save_config
                apply_schedule
                if is_autostart_on; then
                    echo "[*] Jadwal diperbarui dan langsung diterapkan."
                else
                    echo "[*] Jadwal disimpan, akan aktif begitu Autostart dinyalakan."
                fi
                pause
                ;;
            6)
                OFF_HOUR=""
                ON_HOUR=""
                save_config
                apply_schedule
                echo "[*] Jadwal dinonaktifkan."
                pause
                ;;
            7)
                toggle_reset_listener
                pause
                ;;
            0)
                return
                ;;
            *)
                echo "Pilihan tidak dikenal."
                pause
                ;;
        esac
    done
}

do_uninstall() {
    echo "Ini akan menghapus SEMUA file & pengaturan (SSID/password ikut terhapus),"
    echo "seperti belum pernah install sama sekali."
    press_key "Yakin? (y/n): "
    if [ "$KEY" != "y" ] && [ "$KEY" != "Y" ]; then
        echo "Dibatalkan."
        pause
        return
    fi
    su -c "rm -f $DEST_MAIN $DEST_NOTIFY $DEST_RESET $DEST_WATCHDOG $DEST_SCHEDULER $DEST_CONFIG" 2>/dev/null
    stop_listener
    press_key "Hapus juga log lama? (y/n): "
    if [ "$KEY" = "y" ] || [ "$KEY" = "Y" ]; then
        su -c "rm -f $LOG $WATCHDOG_LOG $SCHEDULER_LOG $RESET_LOG" 2>/dev/null
        rm -f "$HOME/reset-listener.log" 2>/dev/null
    fi
    echo "[*] Selesai. Semua pengaturan sudah direset seperti awal."
    pause
}

do_reset_now() {
    if ! su -c "[ -f $DEST_RESET ]" 2>/dev/null; then
        echo "[!] network-reset.sh belum terpasang. Aktifkan dulu Autostart Hotspot (opsi 1)."
        pause
        return
    fi
    echo "[*] Menjalankan Reset Jaringan (stop hotspot -> data off -> pesawat on/off -> data on -> hotspot on)..."
    echo "    Mohon tunggu, ini butuh waktu sekitar 1 menit..."
    su -c "/system/bin/sh $DEST_RESET"
    echo "[*] Reset selesai. Log: su -c 'cat /data/local/tmp/network-reset.log'"
    pause
}

do_reboot() {
    echo "Ini akan me-reboot x3nfc sekarang."
    press_key "Yakin? (y/n): "
    if [ "$KEY" != "y" ] && [ "$KEY" != "Y" ]; then
        echo "Dibatalkan."
        pause
        return
    fi
    su -c /system/bin/reboot
}

# --- main loop ---
while true; do
    load_config
    clear 2>/dev/null
    echo "=== android-auto-hotspot ==="
    if is_autostart_on; then
        STATUS="AKTIF"
    else
        STATUS="MATI"
    fi
    echo "Status Autostart Hotspot: $STATUS"
    echo
    echo "[1] Toggle Autostart Hotspot ($STATUS)"
    echo "[2] Pengaturan"
    echo "[3] Reset Jaringan (sekarang)"
    echo "[4] Reboot x3nfc"
    echo "[5] Uninstall (reset total)"
    echo "[0] Keluar"
    press_key "Pilih: "

    case "$KEY" in
        1)
            toggle_autostart
            pause
            ;;
        2)
            settings_menu
            ;;
        3)
            do_reset_now
            ;;
        4)
            do_reboot
            ;;
        5)
            do_uninstall
            ;;
        0)
            echo "Selesai."
            exit 0
            ;;
        *)
            echo "Pilihan tidak dikenal."
            pause
            ;;
    esac
done
