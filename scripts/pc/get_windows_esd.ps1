# Download the official Windows 11 ARM64 ESD (Pro, chosen language) from Microsoft's catalogue and verify its SHA-1.
param([string]$Lang = 'it-it', [string]$Out = "$PWD\esd")
New-Item -ItemType Directory -Force "$Out\x" | Out-Null
Invoke-WebRequest -UseBasicParsing 'https://go.microsoft.com/fwlink/?LinkId=2156292' -OutFile "$Out\products.cab"
expand.exe "$Out\products.cab" -F:* "$Out\x" | Out-Null
[xml]$x = Get-Content "$Out\x\products.cab" -Raw
$f = $x.MCT.Catalogs.Catalog.PublishedMedia.Files.File | ? { $_.Architecture -eq 'ARM64' -and $_.LanguageCode -eq $Lang -and $_.Edition -eq 'Professional' } | Select -First 1
& curl.exe -L -C - --retry 10 -o "$Out\$($f.FileName)" $f.FilePath
$h = (Get-FileHash -Algorithm SHA1 "$Out\$($f.FileName)").Hash.ToLower()
if ($h -eq $f.Sha1.ToLower()) { "ESD_OK $($f.FileName)" } else { "ESD_BAD $h expected $($f.Sha1)"; exit 1 }
