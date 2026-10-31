# OnePlus 5T (OnePlus A5010) — Kali NetHunter kernel with RTL8811CU (DWA-171) packet injection

This repository documents a working build of the **D-Link DWA-171 (RTL8811CU)** USB Wi-Fi adapter as an **in-tree, built-in driver** inside the **LineageOS 22.2 / Kali NetHunter** kernel for the **OnePlus 5T**, with **monitor mode + packet injection verified working**.

## Result

| Test | Result |
|---|---|
| Driver binds on adapter plug-in | ✅ (no kernel panic) |
| Monitor mode (`iw dev wlan2 set monitor none`) | ✅ RX works |
| Packet injection (TX) | ✅ `aireplay-ng --test` = **100%**, TX counter > 0 |
| `airodump-ng` sniffing | ✅ 17+ networks discovered |

## Why this is non-trivial

Stock `brektrou/rtl8821CU` (v5.4.1) built only gives monitor **RX**; **TX/injection is broken** (`tx_packets = 0`). Switching to `morrownr/8821cu-20210916` (v5.12.0.4, explicitly injection-capable) plus fixing several kernel-compatibility and band-enum bugs resolves it.

## What's in this repo

- `patch-rtl8821cu.py` — standalone script that applies all in-tree patches (reproducible)
- `patch-rtl8821cu.py` is extracted from the zero-kernel builder's `prepare_rtl8821cu` method
- `README.md` (this file) — full documentation

## The hard parts we fixed

### 1. Band-enum values (the panic bug)
The driver references `IEEE80211_BAND_2GHZ`, `IEEE80211_BAND_5GHZ`, `IEEE80211_NUM_BANDS`, which are undeclared on the 4.4 kernel in this driver's compilation unit. The builder's earlier workaround forced **wrong** values:

| Constant | Wrong (crashed) | Correct (Linux 4.4 enum) |
|---|---|---|
| `IEEE80211_BAND_2GHZ` | 1 | **0** |
| `IEEE80211_BAND_5GHZ` | 2 | **1** |
| `IEEE80211_NUM_BANDS` | 4 | **3** |

Wrong indices corrupted `wiphy->bands[]` registration → kernel panic on adapter bind every time. The corrected values (0/1/3) fix the panic.

Source: `include/net/cfg80211.h` `enum ieee80211_band` in `torvalds/linux` `v4.4`.

### 2. clang-only build (kernel uses clang 15)
The morrownr driver's Makefile includes GCC-only flags that clang does not recognize (and `-Werror` turns them into errors):

- `-Wno-enum-int-mismatch` ← removed
- `-Wno-stringop-overread` ← removed

The remaining flags are clang-supported.

### 3. Built-in (in-tree) switch
The morrownr Makefile is intentionally designed for in-tree builds:
```
# export CONFIG_RTL8821CU=y to build driver in tree
ifeq ($(CONFIG_RTL8821CU), y)
    obj-y := $(MODULE_NAME).o
else
    obj-m := $(MODULE_NAME).o
endif
```
So we set `export CONFIG_RTL8821CU = y` and append `obj-y += rtl8821cu/` to `drivers/net/wireless/realtek/Makefile`.

### 4. Mode-switch (storage → Wi-Fi)
The DWA-171 enumerates as `0bda:1a2b` (storage) on power-up; the driver binds to `2001:331d` (Wi-Fi). The usual `usb_modeswitch -K` is unreliable in the chroot (libusb "unable to initialize usb spec"), so we use a direct **SCSI eject (SG_IO START STOP) on the adapter's sg device** — see `sgeject.py` (SG_IO ioctl on `/dev/sg9`).

### 5. Proper `boot.img` (raw dd mistake)
Flashing the raw `Image.gz-dtb` directly to the boot partition (`dd`) leaves it without the Android `ANDROID!` header → unbootable. Fix: **`magiskboot repack`** the kernel into a proper `boot.img` against the original boot image header, then `fastboot flash boot`.

## Prerequisites

- OnePlus 5T (OnePlus A5010), Magisk-rooted LineageOS 22.2 + NetHunter (kernel `4.4.302-perf+`)
- [seppzer0/zero-kernel](https://github.com/seppzer0/zero_kernel) v0.6.4 builder (`dumpling`, `los`, `4.4`)
- docker + clang (provided by the builder)
- `morrownr/8821cu-20210916` (default branch, commit `main`)
- `magiskboot` (in `/tmp/opencode/zkb-unpack/tools/` after clone)
- D-Link DWA-171 USB adapter, switched to Wi-Fi mode (`2001:331d`)

## How to apply these patches

1. Edit `zkb/manifests/tools.json`:
   ```json
   "rtl8821cu": {
       "type": "git",
       "path": "rtl8821cu",
       "url": "https://github.com/morrownr/8821cu-20210916",
       "branch": "main",
       "commit": ""
   }
   ```

2. Patch the builder's `prepare_rtl8821cu` method in `zkb/core/kernel_builder.py` using the script:
   ```bash
   python3 patch-rtl8821cu.py /path/to/kernel/src/drivers/net/wireless/realtek/rtl8821cu \
                            /path/to/kernel/src/drivers/net/wireless/realtek
   ```

3. Build:
   ```bash
   docker build -f Dockerfile -t zero-kernel-image .
   uv run --python 3.12 zkb kernel --build-env=docker --base=los --codename=dumpling --lkv=4.4
   ```

4. Repack + flash:
   ```bash
   # Extract Image.gz-dtb from the produced ZIP
   # Repack into a proper boot.img
   cd /tmp/opencode/boot-repack
   ./magiskboot unpack orig.img     # orig = pre-nethunter-lineage-magisk-boot.img
   cp /path/to/new/Image.gz-dtb kernel
   : > kernel_dtb
   ./magiskboot repack orig.img new_boot.img
   # Flash
   fastboot flash boot new_boot.img
   fastboot reboot
   ```

5. Test injection:
   ```bash
   airmon-ng start wlan2
   aireplay-ng --test wlan2        # should report 30/30: 100%
   airodump-ng wlan2               # sniff (should show APs)
   ```

## Build environment notes

- Kernel: `4.4.302-perf+`, toolchain clang 15.0.1, `LLVM=1`, target `arm64`
- Driver options in its Makefile: `CONFIG_RTL8821C = y`, `CONFIG_USB_HCI = y`
- The driver's other `CONFIG_PLATFORM_*` and `CONFIG_*` defaults are fine for in-tree builds
- `CONFIG_RTL8821CU = y` (export) is the trigger for the built-in `obj-y` path

## Automation scripts

- `scripts/dwa171-switch-now.sh` — one-shot: switches the adapter out of storage mode (run on the phone as root)
- `scripts/dwa171-service.d.sh` — Magisk `service.d` auto-switch (install into `/data/adb/service.d/dwa171-autoswitch.sh`, chmod 755; runs at boot, polls every 5 s, performs the mode switch automatically on adapter insertion)
- `scripts/sgeject.py` — direct SG_IO SCSI-eject helper (bypasses libusb)

## Acknowledgments

- seppzer0/zero_kernel builder (https://github.com/seppzer0/zero_kernel)
- morrownr/8821cu-20210916 (https://github.com/morrownr/8821cu-20210916)
- LineageOS + Kali NetHunter for the base

---

Licensed under GPL-2.0 (matching the driver/zero-kernel licenses).
