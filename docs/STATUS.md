# Status (2026-11-12)

| Item | State |
|---|---|
| Backup of all small partitions | done, verified (SHA-256 vs tablet) |
| Partitioning (esp 350 MB, win 107 GB, userdata 7 GB) | done |
| Windows 11 Pro ARM64 26100.4349 (it-IT, Microsoft ESD, SHA-1 verified) | applied |
| Drivers v2608.03 (DriverUpdater, nabu.xml) | installed offline |
| UEFI v2608.03 (Secure Boot on) in boot_b | flashed |
| First boot / OOBE | completed; then a display glitch at the password prompt and a reboot loop: under analysis |
| Secure Boot off + test signing | prepared (fix_windows.ps1, nSB UEFI) |
| Camera (deskcj Qualcomm ISP R28) | to install from Windows |
| Charging | community status: slow only. Research: which component sets the input current (PMIC charger in UEFI/ACPI vs. qcbattmngr8150 / qcbattminiclass8150 / qcpmicEIC8150 / UCSI) — see docs/CHARGING.md |
