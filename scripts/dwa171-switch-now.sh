#!/system/bin/sh
# =========================================================================
# dwa171-switch-now.sh — one-shot: switch D-Link DWA-171 out of storage mode
# Run manually: sh /data/local/tmp/dwa171-switch-now.sh  (Android shell, root)
# or: adb shell su -c 'sh /data/local/tmp/dwa171-switch-now.sh'
# =========================================================================

# detection
STORAGE="0" REALTEK_SG="" 
for dev in /sys/bus/usb/devices/*; do
    vid=$(cat "$dev/idVendor" 2>/dev/null)
    pid=$(cat "$dev/idProduct" 2>/dev/null)
    [ "$vid" = "0bda" ] && [ "$pid" = "1a2b" ] && STORAGE=1
done

# find Realtek sg (Direct-Access storage "Driver Storage", not Samsung internal)
for f in /sys/class/scsi_generic/sg[0-9]*; do
    [ -f "$f/device/vendor" ] || continue
    v=$(tr -d ' ' < "$f/device/vendor" 2>/dev/null)
    m=$(tr -d ' ' < "$f/device/model" 2>/dev/null)
    if [ "$v" = "Realtek" ] && [ "$m" = "DriverStorage" ]; then
        REALTEK_SG="${f##*/}"
        break
    fi
done

if [ -z "$REALTEK_SG" ]; then
    # fallback: first Realtek vendor sg
    for f in /sys/class/scsi_generic/sg[0-9]*; do
        [ -f "$f/device/vendor" ] || continue
        v=$(tr -d ' ' < "$f/device/vendor" 2>/dev/null)
        if [ "$v" = "Realtek" ]; then REALTEK_SG="${f##*/}"; break; fi
    done
fi

if [ "$REALTEK_SG" = "" ]; then
    echo "[-] Realtek adapter sg device not found"
    exit 1
fi

echo "[+] Ejecting /dev/$REALTEK_SG (Realtek storage) to switch mode"
K=/data/local/nhsystem/kali-arm64
# ensure chroot is mounted
[ -d "$K/proc" ] || mount -o bind /proc "$K/proc" 2>/dev/null
[ -d "$K/sys" ]  || mount -o bind /sys "$K/sys" 2>/dev/null
[ -d "$K/dev" ]  || mount -o bind /dev "$K/dev" 2>/dev/null

su -c "chroot $K /usr/bin/python3 /root/sgeject.py /dev/$REALTEK_SG" 2>&1

sleep 4
echo "[+] After switch:"
lsusb 2>/dev/null | grep -iE '0bda|2001|realtek|d-link' || echo "(no matching USB device yet)"
echo "---"
ls /sys/class/ieee80211/ 2>/dev/null
iw dev 2>/dev/null | grep -A2 'phy#' | head
EOF