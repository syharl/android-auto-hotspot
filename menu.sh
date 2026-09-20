#!/data/data/com.termux/files/usr/bin/bash
# ============================================================
# menu.sh
# Interactive settings menu — change SSID/password/security,
# toggle the idle-timeout watchdog, and set/clear the daily
# off/on schedule, any time after install.sh has run once.
#
# Usage:
#   bash menu.sh
# ============================================================

SCRIPT_DIR="$(dirname "$0")"
DEST_DIR="/data/adb/service.d"
DEST_CONFIG="$DEST_DIR/hotspot-config.sh"
DEST_WATCHDOG="$DEST_DIR/hotspot-watchdog.sh"
DEST_SCHEDULER="$DEST_DIR/hotspot-scheduler.sh"
SRC_WATCHDOG="$SCRIPT_DIR/scripts/hotspot-watchdog.sh"
SRC_SCHEDULER="$SCRIPT_DIR/scripts/hotspot-scheduler.sh"

if ! su -c "[ -f $DEST_CONFIG ]"; then
    echo "[!] Belum ada instalasi. Jalankan 'bash install.sh' dulu."
    exit 1
fi

load_config() {
    CONFIG_TMP="$(mktemp)"
    su -c "cat $DEST_CONFIG" > "$CONFIG_TMP"
    OFF_HOUR=""
    ON_HOUR=""
    # shellcheck source=/dev/null
    . "$CONFIG_TMP"
    rm -f "$CONFIG_TMP"
}

save_config() {
    CONFIG_TMP="$(mktemp)"
    {
        echo "SSID=\"$SSID\""
        echo "PASSWORD=\"$PASSWORD\""
        echo "SECURITY=\"$SECURITY\""
        if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ]; then
            echo "OFF_HOUR=$OFF_HOUR"
            echo "ON_HOUR=$ON_HOUR"
        fi
    } > "$CONFIG_TMP"
    cat "$CONFIG_TMP" | su -c "cat > $DEST_CONFIG"
    rm -f "$CONFIG_TMP"
    su -c "chmod 700 $DEST_CONFIG"
}

mask() {
    printf '%s' "$1" | sed 's/./*/g'
}

show_status() {
    echo "-----------------------------------------------"
    echo "SSID      : $SSID"
    echo "Password  : $(mask "$PASSWORD")"
    echo "Security  : $SECURITY"
    if su -c "[ -f $DEST_WATCHDOG ]"; then
        echo "Watchdog  : AKTIF (auto-restart saat idle timeout)"
    else
        echo "Watchdog  : nonaktif"
    fi
    if [ -n "$OFF_HOUR" ] && [ -n "$ON_HOUR" ] && su -c "[ -f $DEST_SCHEDULER ]"; then
        echo "Jadwal    : mati jam $OFF_HOUR:00, nyala jam $ON_HOUR:00"
    else
        echo "Jadwal    : nonaktif"
    fi
    echo "-----------------------------------------------"
}

load_config

while true; do
    echo
    echo "=== android-auto-hotspot: Menu Pengaturan ==="
    show_status
    echo "1) Ganti SSID"
    echo "2) Ganti Password"
    echo "3) Ganti Security (wpa2/wpa3/open)"
    echo "4) Aktif/Nonaktifkan Watchdog (auto-restart idle timeout)"
    echo "5) Atur Jadwal Off/On harian"
    echo "6) Nonaktifkan Jadwal"
    echo "0) Keluar"
    read -p "Pilih: " CHOICE

    case "$CHOICE" in
        1)
            read -p "SSID baru: " NEW_VAL
            [ -n "$NEW_VAL" ] && SSID="$NEW_VAL"
            save_config
            echo "[*] SSID diperbarui. Reboot atau tekan 'Reset Jaringan' di notifikasi agar berlaku."
            ;;
        2)
            read -s -p "Password baru: " NEW_VAL
            echo
            [ -n "$NEW_VAL" ] && PASSWORD="$NEW_VAL"
            save_config
            echo "[*] Password diperbarui. Reboot atau tekan 'Reset Jaringan' di notifikasi agar berlaku."
            ;;
        3)
            read -p "Security [wpa2/wpa3/open]: " NEW_VAL
            [ -n "$NEW_VAL" ] && SECURITY="$NEW_VAL"
            save_config
            echo "[*] Security diperbarui. Reboot atau tekan 'Reset Jaringan' di notifikasi agar berlaku."
            ;;
        4)
            if su -c "[ -f $DEST_WATCHDOG ]"; then
                su -c "rm -f $DEST_WATCHDOG"
                echo "[*] Watchdog dinonaktifkan."
            else
                if [ ! -f "$SRC_WATCHDOG" ]; then
                    echo "[!] scripts/hotspot-watchdog.sh tidak ditemukan di repo ini."
                else
                    cat "$SRC_WATCHDOG" | su -c "cat > $DEST_WATCHDOG"
                    su -c "chmod 700 $DEST_WATCHDOG"
                    echo "[*] Watchdog diaktifkan."
                fi
            fi
            echo "[*] Reboot agar perubahan berlaku."
            ;;
        5)
            read -p "  Matikan jam berapa (0-23): " OFF_HOUR
            read -p "  Nyalakan jam berapa (0-23): " ON_HOUR
            save_config
            if [ ! -f "$SRC_SCHEDULER" ]; then
                echo "[!] scripts/hotspot-scheduler.sh tidak ditemukan di repo ini."
            else
                cat "$SRC_SCHEDULER" | su -c "cat > $DEST_SCHEDULER"
                su -c "chmod 700 $DEST_SCHEDULER"
                echo "[*] Jadwal diatur: mati $OFF_HOUR:00, nyala $ON_HOUR:00 setiap hari."
            fi
            echo "[*] Reboot agar jadwal mulai berjalan."
            ;;
        6)
            su -c "rm -f $DEST_SCHEDULER"
            OFF_HOUR=""
            ON_HOUR=""
            save_config
            echo "[*] Jadwal dinonaktifkan."
            ;;
        0)
            echo "Selesai."
            break
            ;;
        *)
            echo "Pilihan tidak dikenal."
            ;;
    esac
done
