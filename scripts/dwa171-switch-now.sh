#!/system/bin/sh
# =========================================================================
# dwa171-switch-now.sh -- RUN ON THE PHONE AS ROOT (Magisk)
# One-shot: switch D-Link DWA-171 (0bda:1a2b) storage -> 2001:331d via SG_IO.
# Run:  su -c 'sh /data/local/tmp/dwa171-switch-now.sh'
# =========================================================================

echo "[1] Looking for the Realtek storage-mode sg device..."
REAL=""

# Step 1: find sg device whose vendor == "Realtek"
for f in /sys/class/scsi_generic/sg0 /sys/class/scsi_generic/sg1 /sys/class/scsi_generic/sg2 /sys/class/scsi_generic/sg3 /sys/class/scsi_generic/sg4 /sys/class/scsi_generic/sg5 /sys/class/scsi_generic/sg6 /sys/class/scsi_generic/sg7 /sys/class/scsi_generic/sg8 /sys/class/scsi_generic/sg9; do
    [ -f "$f/device/vendor" ] || continue
    v=$(cat "$f/device/vendor" 2>/dev/null)
    # trim spaces
    case "$v" in
        *"Realtek"*)
            REAL="${f##*/}"
            break
            ;;
    esac
done

if [ -z "$REAL" ]; then
    echo "[-] No Realtek SCSI-generic device found."
    echo "    Is the DWA-171 plugged in? (status below)"
    lsusb | grep -i '0bda\|2001\|realtek\|d-link' || echo "    (no matching USB device in /sys)"
    exit 1
fi
echo "  found: $REAL"

echo "[2] Sending SCSI START-STOP (eject) via SG_IO for /dev/$REAL ..."
K=/data/local/nhsystem/kali-arm64
KALIRET=$(chroot "$K" /usr/bin/python3 /root/sgeject.py "/dev/$REAL" 2>&1)
echo "$KALIRET"

echo "[3] Verifying mode switch (5s wait) ..."
sleep 5
echo "  lsusb:"
lsusb | grep -i '0bda\|2001\|realtek\|d-link' || echo "    (none listed)"
echo "  wlan physis/interfaces:"
ls /sys/class/ieee80211/ 2>/dev/null | tr '\n' ' '
echo
iw dev 2>/dev/null | grep -iE 'Interface|type' | tr '\n' ',' || echo "    (iw unavailable)"
echo
echo "[4] Done. New mode should appear as 2001:331d (wifi) and a new phy (phy1/wlan2)."