# Install Windows 11 Pro ARM64 onto the Xiaomi Pad 5 (tablet in mass-storage mode via "adb shell msc"). Run as Administrator.
# Scripted from erdilS/Port-Windows-11-Xiaomi-Pad-5 guide/English/3-install-en.md.
# Expects: <here>\esd\*.esd (get_windows_esd.ps1) and <here>\drivers\ (MiPad5-Drivers-v2608.03-Desktop.7z extracted).
$ErrorActionPreference = 'Continue'
$W = $PSScriptRoot
$log = "$W\install.log"
function L($m) { ((Get-Date).ToString('HH:mm:ss') + ' ' + $m) | Tee-Object -Append $log }
L 'start'
$win = Get-Volume | ? { $_.FileSystemLabel -eq 'WINNABU' }
if (-not $win -or -not $win.DriveLetter) { L 'STOP: WINNABU not found'; exit 1 }
$X = "$($win.DriveLetter):"
$disk = (Get-Partition -DriveLetter $win.DriveLetter).DiskNumber
# ESPNABU: the 350 MB EFI partition on the same disk (not the 1 GB "esp" partition before it)
$esp = Get-Partition -DiskNumber $disk | ? { $_.Size -gt 300MB -and $_.Size -lt 400MB } | Select -First 1
if (-not $esp) { L 'STOP: ESPNABU (350 MB) not found'; exit 1 }
if (-not $esp.DriveLetter -or $esp.DriveLetter -eq "`0") { $esp | Add-PartitionAccessPath -AccessPath 'Y:\'; $Y = 'Y:' } else { $Y = "$($esp.DriveLetter):" }
L "WINNABU $X (disk $disk), ESPNABU $Y"
$esd = Get-ChildItem "$W\esd\*.esd" | Select -First 1
$idx = $null; $cur = $null
foreach ($line in (& dism /English /Get-ImageInfo /ImageFile:"$($esd.FullName)")) {
  if ($line -match '^Index : (\d+)') { $cur = $Matches[1] }
  if ($line -match '^Name : Windows 11 Pro$') { $idx = $cur }
}
L "ESD $($esd.Name) Windows 11 Pro index $idx"
if (-not $idx) { L 'STOP: no Windows 11 Pro index'; exit 1 }
& dism /English /Apply-Image /ImageFile:"$($esd.FullName)" /Index:$idx /ApplyDir:"$X\" 2>&1 | Select-String 'successfully|Error|%' | Select -Last 3 | % { L $_.Line }
if (-not (Test-Path "$X\Windows\System32\ntoskrnl.exe")) { L 'STOP: image not applied'; exit 1 }
L 'image applied; installing drivers'
Push-Location "$W\drivers"
& ".\tools\DriverUpdater\$env:PROCESSOR_ARCHITECTURE\DriverUpdater.exe" -r . -d .\definitions\Desktop\ARM64\Internal\nabu.xml -p $X 2>&1 | Select -Last 15 | % { L $_ }
Pop-Location
L 'bcdboot'
& bcdboot "$X\Windows" /s $Y /f UEFI 2>&1 | % { L $_ }
if (Test-Path "$Y\EFI\Microsoft\Boot\BCD") { L 'BOOT_FILES_OK' } else { L 'STOP: boot files missing'; exit 1 }
mountvol $Y /d
L 'WINDOWS_INSTALL_DONE'
