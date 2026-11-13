# Troubleshooting found on this install

## Tablet drops into fastboot after a few Windows boots (Windows-only install)
Cause: Android A/B slot logic. The bootloader (ABL) decrements `slot-retry-count` on every boot of a slot that is not
marked successful; only Android's boot-control HAL marks a slot successful, so with UEFI/Windows in both boot slots the
counters run down (7 boots per slot), the slot becomes `unbootable`, and ABL stops in fastboot.
Seen here: `slot-unbootable:a:yes`, `slot-retry-count:a:0`, `slot-successful:a:no`.

Fix (from the mod-win TWRP; GPT backup first):
```
sgdisk --backup=/tmp/sde-gpt-before.bin /dev/block/sde      # pull it to the PC
sgdisk --attributes=14:set:54 --attributes=37:set:54 /dev/block/sde   # boot_a = sde14, boot_b = sde37 on nabu
```
Bit 54 of the GPT attributes is Qualcomm's "successful" flag. Afterwards `fastboot getvar all` shows
`slot-successful:a:yes` / `b:yes` and the retry counters no longer run down. Check the partition numbers with
`ls -l /dev/block/by-name/boot_*` first. If a slot is already `unbootable`, `fastboot set_active a` resets it.

## Boot loop after setup: Qualcomm drivers refused by code integrity (0xC0E90002)
The Kernel-Boot log showed event 49 for qcpmic8180, qcpep8180, qcspmi8180, qcscm8180, QcTrEE8180, qcgpio, ...
Turning off the vulnerable-driver blocklist / Smart App Control / WHQL setting offline made winload itself fail
("Code integrity initialization failed", 0xc0e90002). What booted: original CI settings restored, Secure Boot off (nSB UEFI),
test signing on, automatic repair off, and the A/B slots re-activated (see above). Keep Windows Update paused until set up.

## The old iPadOS (UniXNU) boot menu appears instead of Windows
A second ESP (sda29, 1 GB) still held UniXNU's EFI/BOOT loader; the UEFI picked it first. It was reformatted (label NOTUSED);
Windows boots from ESPNABU (sda31).
