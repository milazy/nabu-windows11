# Windows 11 on Xiaomi Pad 5 (nabu) — Windows-only install, camera, charging

Automation and research on top of the community project
[erdilS/Port-Windows-11-Xiaomi-Pad-5](https://github.com/erdilS/Port-Windows-11-Xiaomi-Pad-5)
(drivers/UEFI: [remtrik-stuff/MiPad5-Windows-Releases](https://github.com/remtrik-stuff/MiPad5-Windows-Releases) v2608.03,
recovery: [ArKT-7 mod-win TWRP](https://github.com/ArKT-7/twrp_device_xiaomi_nabu/releases/tag/mod-win),
cameras: [deskcj/xiaomi-pad5-windows11-camera](https://github.com/deskcj/xiaomi-pad5-windows11-camera)).
Nothing here redistributes those files: the scripts download them from their owners.

## Layout chosen here
Windows only (Android data erased on purpose): `partition 107` from the mod-win TWRP gives
esp (350 MB, ESPNABU) + win (107 GB, WINNABU) + a 7 GB userdata; UEFI v2608.03 is flashed to the active boot slot.

## Steps (PC with Windows 10/11, tablet in fastboot)
1. `scripts/pc/pull_backup.ps1` — read-only backup of every partition ≤ 512 MiB (persist, modemst1/2, fsg, fsc, boot_a/b, …), checked by SHA-256 against the tablet.
2. Boot the mod-win TWRP, `adb shell partition <GB>` (erases Android data).
3. `adb shell msc`, then **as Administrator** `scripts/pc/install_windows.ps1` (DISM apply of the Microsoft ESD, DriverUpdater with `nabu.xml`, `bcdboot`).
4. `fastboot flash boot_<slot> MiPad5.UEFI-v2608.03.img` (or `_nSB` for Secure Boot off).
5. Secure Boot off: flash the `_nSB` UEFI, then **as Administrator** `scripts/pc/fix_windows.ps1` (test signing on, no automatic-repair loop, logs collected).
6. Camera: in Windows (test mode) run the Qualcomm ISP R28 installer from deskcj's project.

## Status
See [docs/STATUS.md](docs/STATUS.md).
