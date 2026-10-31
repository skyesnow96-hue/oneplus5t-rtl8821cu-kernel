#!/system/bin/sh
# =========================================================================
# Magisk service.d script: continuously watch for D-Link DWA-171 in USB
# storage mode (0bda:1a2b) and switch it to Wi-Fi mode (2001:331d) via a
# SCSI START STOP (eject) on its sg device. Installed at:
#     /data/adb/service.d/dwa171-autoswitch.sh
# Magisk launches service.d scripts after boot as long as they are executable.
# =========================================================================
set -e

# log
LOG=/data/local/tmp/dwa171-autoswitch.log
exec 9>>"$LOG"
echo "=== dwa171-autoswitch started $(date) ===" >&9

# sleep at boot to let Wi-Fi/adb come up
sleep 30

# path constants
KALI=/data/local/nhsystem/kali-arm64
SGEJECT="$KALI/root/sgeject.py"
MOUNTED_FLAG=/data/local/tmp/dwa171-mounts.done

ensure_mounts() {
    if [ -f "$MOUNTED_FLAG" ]; then return 0; fi
    [ -d "$KALI/proc" ] || mount -o bind /proc "$KALI/proc" 2>/dev/null
    [ -d "$KALI/sys"  ] || mount -o bind /sys  "$KALI/sys"  2>/dev/null
    [ -d "$KALI/dev"  ] || mount -o bind /dev  "$KALI/dev"  2>/dev/null
    touch "$MOUNTED_FLAG"
}

find_realtek_sg() {
    for f in /sys/class/scsi_generic/sg[0-9]*; do
        [ -f "$f/device/vendor" ] || continue
        v=$(tr -d ' ' < "$f/device/vendor" 2>/dev/null)
        m=$(tr -d ' ' < "$f/device/model" 2>/dev/null)
        if [ "$v" = "Realtek" ] && [ "$m" = "DriverStorage" ]; then
            echo "${f##*/}"; return 0
        fi
    done
    # fallback: any Realtek sg
    for f in /sys/class/scsi_generic/sg[0-9]*; do
        [ -f "$f/device/vendor" ] || continue
        v=$(tr -d ' ' < "$f/device/vendor" 2>/dev/null)
        if [ "$v" = "Realtek" ]; then echo "${f##*/}"; return 0; fi
    done
    return 1
}

storage_present() {
    for dev in /sys/bus/usb/devices/*; do
        vid=$(cat "$dev/idVendor" 2>/dev/null)
        pid=$(cat "$dev/idProduct" 2>/dev/null)
        [ "$vid" = "0bda" ] && [ "$pid" = "1a2b" ] && return 0
    done
    return 1
}

wifi_present() {
    for dev in /sys/bus/usb/devices/*; do
        vid=$(cat "$dev/idVendor" 2>/dev/null)
        pid=$(cat "$dev/idProduct" 2>/dev/null)
        [ "$vid" = "2001" ] && [ "$pid" = "331d" ] && return 0
    done
    return 1
}

# Ensure sgeject exists
if [ ! -f "$SGEJECT" ]; then
    echo "[-] sgeject.py missing at $SGEJECT" >&9
fi

ensure_mounts

# Main loop
SWITCHED_FLAG=/data/local/tmp/dwa171-switched.flag
while true; do
    if storage_present && ! wifi_present; then
        echo "$(date) storage-mode adapter detected" >&9
        SG=$(find_realtek_sg)
        if [ -n "$SG" ] && [ -f "$SGEJECT" ]; then
            # ensure no stale switched flag from a previous enumeration
            rm -f "$SWITCHED_FLAG" 2>/dev/null
            echo "$(date) ejecting /dev/$SG" >&9
            su -c "K=/data/local/nhsystem/kali-arm64; chroot \$K /usr/bin/python3 /root/sgeject.py /dev/$SG" >>"$LOG" 2>&1
            sleep 8
            if wifi_present; then
                echo "$(date) switch OK: adapter now in Wi-Fi mode (2001:331d)" >&9
                touch "$SWITCHED_FLAG"
            else
                echo "$(date) switch did not happen; will retry" >&9
            fi
        fi
    fi
    sleep 5
done
EOF