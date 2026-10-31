#!/usr/bin/env python3
"""
patch-rtl8821cu.py
-------------------
Reproduces the in-tree patches that make the D-Link DWA-171 (RTL8811CU)
driver 'morrownr/8821cu-20210916' build cleanly as a *built-in* driver inside
the zero-kernel / LineageOS 4.4 kernel tree, with working packet injection.

Usage:
    python3 patch-rtl8821cu.py <driver_dir> <kernel_realtek_dir>

Example:
    python3 patch-rtl8821cu.py \
        /zero_build/rtl8821cu \
        /zero_build/android_kernel_oneplus_msm8998/drivers/net/wireless/realtek

  <driver_dir>        = the morrownr/8821cu-20210916 source dir (as cloned)
  <kernel_realtek_dir> = the kernel's drivers/net/wireless/realtek dir

What it does:
  1. Patch the driver's Makefile:
     - enable built-in (in-tree) build: export CONFIG_RTL8821CU = y
     - suppress clang warning-options promoted to -Werror:
         typedef-redefinition, parentheses-equality, pointer-bool-conversion,
         constant-conversion, enum-conversion
     - drop GCC-only warning options clang does not understand:
         -Wno-enum-int-mismatch, -Wno-stringop-overread
     - supply the band enum constants clang can not resolve on 4.4:
         IEEE80211_BAND_2GHZ=0, IEEE80211_BAND_5GHZ=1, IEEE80211_NUM_BANDS=3
       (these MUST match the kernel's enum ieee80211_band; see source)
  2. Enable the driver in the kernel: append 'obj-y += rtl8821cu/' to
     <kernel_realtek_dir>/Makefile
  3. Ensure the driver is copied to the right place:
     (the caller / builder is expected to ucopy the driver source to
      <kernel_realtek_dir>/rtl8821cu first)

Important:
  - The band values (0,1,3) must match include/net/cfg80211.h in your kernel.
  - Do NOT use (1,2,4) like the original builder workaround - that corrupts
    wiphy->bands[] and panics the kernel on adapter bind.
  - Incremental / idempotent: re-running on an already-patched Makefile is safe
    enough (the replacements are string-based).
"""

import sys
from pathlib import Path

def patch_driver_makefile(driver_dir: Path) -> None:
    makefile = driver_dir / "Makefile"
    if not makefile.exists():
        raise SystemExit(f"Makefile not found: {makefile}")
    content = makefile.read_text(encoding="utf-8")

    anchor = "ccflags-y += $(USER_EXTRA_CFLAGS)"
    injection = (
        anchor + "\n"
        "export CONFIG_RTL8821CU = y\n"
        "ccflags-y += -Wno-error=typedef-redefinition\n"
        "ccflags-y += -Wno-error=parentheses-equality\n"
        "ccflags-y += -Wno-error=pointer-bool-conversion\n"
        "ccflags-y += -Wno-error=constant-conversion\n"
        "ccflags-y += -Wno-error=enum-conversion\n"
        "ccflags-y += -DIEEE80211_BAND_2GHZ=0\n"
        "ccflags-y += -DIEEE80211_BAND_5GHZ=1\n"
        "ccflags-y += -DIEEE80211_NUM_BANDS=3"
    )
    content = content.replace(anchor, injection, 1)

    # strip GCC-only warning options that clang does not support
    content = content.replace("ccflags-y += -Wno-enum-int-mismatch\n", "")
    content = content.replace("ccflags-y += -Wno-stringop-overread\n", "")

    makefile.write_text(content, encoding="utf-8")
    print(f"[+] patched {makefile}")


def enable_in_kernel_build(kernel_realtek_dir: Path) -> None:
    makefile = kernel_realtek_dir / "Makefile"
    if not makefile.exists():
        raise SystemExit(f"Makefile not found: {makefile}")
    with open(makefile, "a", encoding="utf-8") as f:
        f.write("obj-y += rtl8821cu/\n")
    print(f"[+] appended 'obj-y += rtl8821cu/' to {makefile}")

def main() -> None:
    if len(sys.argv) != 3:
        print(__doc__)
        sys.exit(1)
    driver_dir = Path(sys.argv[1]).resolve()
    kernel_realtek_dir = Path(sys.argv[2]).resolve()
    if not driver_dir.exists():
        raise SystemExit(f"driver dir missing: {driver_dir}")
    if not kernel_realtek_dir.exists():
        raise SystemExit(f"kernel realtek dir missing: {kernel_realtek_dir}")
    patch_driver_makefile(driver_dir)
    enable_in_kernel_build(kernel_realtek_dir)
    print("[+] done - the driver is now wired as a built-in (obj-y) with injection support")

if __name__ == "__main__":
    main()
