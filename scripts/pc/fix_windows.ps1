# Run as Administrator with the tablet in mass-storage mode (mod-win TWRP: adb shell msc).
# 1) copies the tablet's Windows logs to diag\ (boot-loop analysis),
# 2) BCD: test signing on (unsigned/test-signed drivers, e.g. camera), no automatic-repair loop, no failure boot menu.
$ErrorActionPreference = 'Continue'
$W = $PSScriptRoot; $O = "$W\diag"; New-Item -ItemType Directory -Force $O | Out-Null
$log = "$O\fix.log"
function L($m) { ((Get-Date).ToString('HH:mm:ss') + ' ' + $m) | Tee-Object -Append $log }
$win = Get-Volume | ? { $_.FileSystemLabel -eq 'WINNABU' }
if (-not $win) { L 'STOP: WINNABU not found (tablet in msc mode?)'; exit 1 }
$X = "$($win.DriveLetter):"
L "WINNABU $X"
robocopy "$X\Windows\System32\winevt\Logs" "$O\evtx" System.evtx Application.evtx Setup.evtx "Microsoft-Windows-Kernel-Boot%4Operational.evtx" "Microsoft-Windows-Kernel-PnP%4Configuration.evtx" /B /R:0 /W:0 /NP | Out-Null
foreach ($d in 'Panther','Minidump','LiveKernelReports','System32\LogFiles\Srt') { robocopy "$X\Windows\$d" "$O\$($d -replace '\\','-')" /E /B /R:0 /W:0 /NP | Out-Null }
if (Test-Path "$X\Windows\MEMORY.DMP") { L ("MEMORY.DMP " + (Get-Item "$X\Windows\MEMORY.DMP").Length) }
L ("collected: " + ((Get-ChildItem -Recurse -File $O).Count) + " files")
$disk = (Get-Partition -DriveLetter $win.DriveLetter).DiskNumber
$esp = Get-Partition -DiskNumber $disk | ? { $_.Size -gt 300MB -and $_.Size -lt 400MB } | Select -First 1
if (-not $esp.DriveLetter -or $esp.DriveLetter -eq "`0") { $esp | Add-PartitionAccessPath -AccessPath 'Y:\' }
$bcd = 'Y:\EFI\Microsoft\Boot\BCD'
if (-not (Test-Path $bcd)) { L 'STOP: BCD not found'; exit 1 }
Copy-Item $bcd "$O\BCD.before" -Force
foreach ($a in @('testsigning on', 'recoveryenabled no', 'bootstatuspolicy IgnoreAllFailures')) {
  $r = & bcdedit /store $bcd /set '{default}' $a.Split(' ')[0] $a.Split(' ')[1] 2>&1
  L "bcdedit $a -> $r"
}
& bcdedit /store $bcd /enum '{default}' | Out-File "$O\bcd-default.txt"
mountvol Y: /d
L 'FIX_DONE'
