# Read-only backup: every tablet partition up to 512 MiB plus GPT heads and partition tables, checked by SHA-256.
# Tablet in the mod-win TWRP (adb root). Usage: pull_backup.ps1 -Adb path\to\adb.exe -Out folder [-Serial id]
param([string]$Adb = 'adb', [string]$Out = "$PWD\nabu-partitions", [string]$Serial = '')
$S = if ($Serial) { @('-s', $Serial) } else { @() }
New-Item -ItemType Directory -Force $Out | Out-Null
function Pull($remote, $file) {
  # dd into the tablet's RAM, pull, delete (one partition at a time fits in /tmp)
  $cmd = $remote -replace '2>/dev/null', 'of=/tmp/p.img 2>/dev/null'
  & $Adb @S shell $cmd | Out-Null
  & $Adb @S pull /tmp/p.img $file 2>&1 | Out-Null
  & $Adb @S shell 'rm -f /tmp/p.img' | Out-Null
}
$list = & $Adb @S shell 'cd /dev/block/by-name; for n in *; do t=$(readlink -f $n); echo "$n $t $(blockdev --getsize64 $t)"; done'
$list | Out-File "$Out\partitions.txt" -Encoding ascii
foreach ($d in 'sda','sdb','sdc','sdd','sde','sdf') {
  & $Adb @S shell "parted -s /dev/block/$d unit B print 2>&1" | Out-File "$Out\table-$d.txt" -Encoding ascii
  Pull "dd if=/dev/block/$d bs=4096 count=6 2>/dev/null" "$Out\gpt-$d-head.bin"
}
$sums = @()
foreach ($line in $list) {
  $p = $line.Trim() -split '\s+'; if ($p.Count -lt 3) { continue }
  $n = $p[0]; $t = $p[1]; $s = [int64]$p[2]
  if ($s -le 0 -or $s -gt 536870912) { continue }
  Pull "dd if=$t bs=1048576 2>/dev/null" "$Out\$n.img"
  $len = (Get-Item "$Out\$n.img").Length
  $dev = (& $Adb @S shell "sha256sum $t" | Out-String).Split(' ')[0].Trim()
  $pc = (Get-FileHash -Algorithm SHA256 "$Out\$n.img").Hash.ToLower()
  $ok = if ($len -eq $s -and $dev -eq $pc) { 'OK' } else { 'MISMATCH' }
  $sums += "$ok $n $s $len $pc"
}
$sums | Out-File "$Out\verify.txt" -Encoding ascii
"DONE ok=" + ($sums | ? { $_ -like 'OK*' }).Count + " bad=" + ($sums | ? { $_ -like 'MISMATCH*' }).Count | Out-File -Append "$Out\verify.txt"
