#!/usr/bin/env bash
# =========================================================================
# switch-from-host.sh  (run ON THE PC - ZSH/BASH)
#
# One command that:
#   - finds the Android device (USB first, falls back to Wi-Fi 10.0.0.4:39628)
#   - asks the phone to switch DWA-171 out of storage mode
#
# Usage:
#   sh scripts/switch-from-host.sh
#
# The phone-side helper (installed at /data/local/tmp/dwa171-switch-now.sh) does
# the real work; we just call it over adb with a single quoting layer, which is
# what caused the previous "unexpected 2>" soup when nested redirects were used.
# =========================================================================
set -e
ADR="${1:-}"

if [ -z "$ADR" ]; then
  # prefer a USB-attached device if present
  ADR=$(adb devices | awk '/^[[:alnum:] ].* device$/ {print $1; exit}')
  if [ -z "$ADR" ]; then
    ADR=$(adb devices | awk '/^[[:alnum:] ].* (device|unauthorized|sideload)/ && !/List/ {print $1; exit}')
  fi
  if [ -z "$ADR" ]; then
    # no USB - try wireless
    adb connect 10.0.0.4:39628 >/dev/null 2>&1 || true
    ADR=10.0.0.4:39628
  fi
fi

echo "[+] adb target: $ADR"
echo "[+] invoking phone-side switch (succinct, single-quoted, no nested redirects)..."

# Single-quoted inner command: nothing here is reinterpreted by zsh/bash.
# On the phone it runs as a root script (Magisk grants su to the adb-shell UID).
adb -s "$ADR" shell "su -c 'sh /data/local/tmp/dwa171-switch-now.sh'"

echo "[+] done. Check above output. To verify mode switch: "
echo "    adb shell su -c 'lsusb'  (should now show 2001:331d / DWA-171)"
EOF