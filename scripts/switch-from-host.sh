#!/usr/bin/env bash
# =========================================================================
# switch-from-host.sh  (run THIS on your PC terminal)
# 
# Remotely performs the D-Link DWA-171 storage -> Wi-Fi mode switch by:
#   1) resolving the phone via adb (USB or Wi-Fi tcpip 39628)
#   2) verifying the adapter is plugged in and in 0bda:1a2b storage mode
#   3) running the SG_IO SCSI-eject on the phone
# 
# Usage:
#   sh switch-from-host.sh              # uses default adb device
#   ADB=10.0.0.4:39628 sh switch-from-host.sh   # force a specific target
# =========================================================================
set -euo pipefail
ADB_DEV="${ADB:-}"
[ -z "$ADB_DEV" ] && ADB_DEV=$(adb devices | awk '/device$/ && !/List/{print $1; exit}')

if [ -z "$ADB_DEV" ]; then
    echo "[-] No adb device found. Plug the phone in (USB or be on the same network) and retry." >&2
    exit 1
fi
echo "[+] Using adb target: $ADB_DEV"

# Find a Realtek sg device inside the Android kernel
SG=$(adb -s "$ADB_DEV" shell "su -c 'for f in /sys/class/scsi_generic/sg[0-9]*; do [ -f \"\$f/device/vendor\" ] || continue; v=\\\$(cat \"\$f/device/vendor\" 2>/dev/null | tr -d \\\" \\\"\"); m=\\\$(cat \"\$f/device/model\" 2>/dev/null | tr -d \\\" \\\"\"); if [ \"\$v\$m\" = \"RealtekDriverStorage\" ]; then echo \\\${f##*/}; break; fi; done'" | tr -d '\r' | grep -E '^sg[0-9]+$' | head -1)

if [ -z "$SG" ]; then
    # fallback: first Realtek-vendor sg
    SG=$(adb -s "$ADB_DEV" shell "su -c 'for f in /sys/class/scsi_generic/sg[0-9]*; do [ -f \"\$f/device/vendor\" ] || continue; v=\\\$(cat \"\$f/device/vendor\" 2>/dev/null | tr -d \\\" \\\"\"); if [ \"\$v\" = \"Realtek\" ]; then echo \\\${f##*/}; break; fi; done'" | tr -d '\r' | grep -E '^sg[0-9]+$' | head -1)
fi

if [ -z "$SG" ]; then
    echo "[-] Realtek storage device not found."
    echo "    Is the DWA-171 actually plugged in now?  (lsusb should show 0bda:1a2b)"
    adb -s "$ADB_DEV" shell "su -c 'lsusb 2>/dev/null'" | grep -iE '0bda|2001|realtek|d-link' || echo "    (no USB device matching detected)"
    exit 1
fi
echo "[+] Found Realtek sg device: $SG"

# Ensure the sgeject helper is present and executable
adb -s "$ADB_DEV" shell "su -c 'test -x /data/local/nhsystem/kali-arm64/root/sgeject.py || chmod +x /data/local/nhsystem/kali-arm64/root/sgeject.py; ls -l /data/local/nhsystem/kali-arm64/root/sgeject.py'" 2>&1 | tail -1

# Run the eject  (SG_IO START STOP on the storage sg device)
echo "[+] Sending SCSI eject (START STOP UNIT) to /dev/$SG ..."
out=$(adb -s "$ADB_DEV" shell "su -c 'K=/data/local/nhsystem/kali-arm64; chroot \$K /usr/bin/python3 /root/sgeject.py /dev/$SG 2>&1'")
printf '%s\n' "$out"
ret=$(printf '%s\n' "$out" | grep -o 'SG_IO ret=[0-9]*' | head -1)
if [ -z "$ret" ]; then
    echo "[-] eject failed; see output above" >&2
    exit 1
fi
echo "[+] $ret"

# wait for USB re-enumeration
sleep 6

# verify
new=$(adb -s "$ADB_DEV" shell "su -c 'lsusb 2>/dev/null | grep -oE \"2001:331d\"'" | tr -d '\r' | head -1)
if [ -z "$new" ]; then
    echo "[-] Mode switch did not happen; adapter still in storage mode (0bda:1a2b)"
    echo "    Try again, or check dmesg for USB probe errors."
    exit 1
fi
echo "[+] SUCCESS - adapter now in Wi-Fi mode ($new)"
echo "[+] Listen for new wlan interface: phy1 / wlan2"
adb -s "$ADB_DEV" shell "su -c 'ls /sys/class/ieee80211/; echo ---; iw dev 2>/dev/null | grep -iE \"^\\s*Interface|type\"'"
EOF