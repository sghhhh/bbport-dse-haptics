# SPDX-License-Identifier: GPL-2.0-or-later
param(
    [Parameter(Mandatory)] [string]$PortDir,
    [string]$ModsDir
)

$ErrorActionPreference = 'Stop'
$port = (Resolve-Path -LiteralPath $PortDir).Path
$manifestPath = Join-Path $port 'bbport-files.json'
$manifest = Get-Content -LiteralPath $manifestPath -Raw | ConvertFrom-Json -AsHashtable
if ($manifest.version -ne '1.9.8.6' -or -not (Test-Path -LiteralPath (Join-Path $port 'bin/bb-probe.exe'))) {
    throw 'Use a Windows bbport 1.9.8.6 installation.'
}
$running = Get-CimInstance Win32_Process | Where-Object {
    $_.ExecutablePath -and $_.ExecutablePath.StartsWith($port + '\', [StringComparison]::OrdinalIgnoreCase) -and
    $_.Name -in @('Bloodborne.exe', 'bb-probe.exe', 'bb-probe-seamless.exe', 'bb-probe-seamless-dse.exe')
}
if ($running) { throw 'Close the game and its launcher before replacing their files.' }

$payload = (Resolve-Path -LiteralPath (Join-Path $PSScriptRoot 'payload')).Path
$launcher = Join-Path $payload '_launcher_dse'
$files = @('Bloodborne.exe', 'bin/bb-probe-seamless-dse.exe', 'bin/libc++.dll', 'licenses/dse-libcxx.txt')
foreach ($file in (Get-ChildItem -LiteralPath $launcher -File -Recurse)) {
    $files += [IO.Path]::GetRelativePath($payload, $file.FullName)
}
foreach ($name in $files) {
    if (-not (Test-Path -LiteralPath (Join-Path $payload $name) -PathType Leaf)) {
        throw "Release payload is missing $name."
    }
    $entry = $name.Replace('\', '/')
    if ($entry.StartsWith('bin/')) {
        $manifest.files[$entry] = (Get-FileHash -LiteralPath (Join-Path $payload $name)).Hash.ToLowerInvariant()
    }
}

$nonce = [Guid]::NewGuid().ToString('N').Substring(0, 8)
$backup = Join-Path $port ('.dse-backup-' + $nonce)
New-Item -ItemType Directory -Path $backup | Out-Null
$nextManifest = Join-Path $backup 'next-manifest.json'
$manifest | ConvertTo-Json -Depth 5 | Set-Content -LiteralPath $nextManifest -Encoding utf8
$written = [System.Collections.Generic.List[object]]::new()
try {
    foreach ($name in ($files + 'bbport-files.json')) {
        $target = [IO.Path]::GetFullPath((Join-Path $port $name))
        if (-not $target.StartsWith($port + '\', [StringComparison]::OrdinalIgnoreCase)) {
            throw 'Unexpected path outside the bbport installation.'
        }
        $source = if ($name -eq 'bbport-files.json') { $nextManifest } else { Join-Path $payload $name }
        $old = Join-Path $backup $name
        New-Item -ItemType Directory -Path (Split-Path -Parent $target) -Force | Out-Null
        New-Item -ItemType Directory -Path (Split-Path -Parent $old) -Force | Out-Null
        $temp = $target + '.dse-' + $nonce
        Copy-Item -LiteralPath $source -Destination $temp
        if (Test-Path -LiteralPath $target) { [IO.File]::Replace($temp, $target, $old) }
        else { [IO.File]::Move($temp, $target) }
        $written.Add(@{ Target = $target; Backup = $old })
        if ((Get-FileHash -LiteralPath $target).Hash -ne (Get-FileHash -LiteralPath $source).Hash) {
            throw "Verification failed for $name."
        }
    }
} catch {
    $written.Reverse()
    foreach ($file in $written) {
        if (Test-Path -LiteralPath $file.Backup) { [IO.File]::Move($file.Backup, $file.Target, $true) }
        else { Remove-Item -LiteralPath $file.Target }
    }
    throw
}

if (-not $ModsDir) { $ModsDir = Join-Path $port 'mods' }
$profile = 'DSE Haptics/dvdroot_ps4/other/bbport-dse-haptics.json'
$profileTarget = Join-Path $ModsDir $profile
if (-not (Test-Path -LiteralPath $profileTarget)) {
    New-Item -ItemType Directory -Path (Split-Path -Parent $profileTarget) -Force | Out-Null
    Copy-Item -LiteralPath (Join-Path (Join-Path $payload 'mods') $profile) -Destination $profileTarget
} else {
    Write-Output 'Kept the existing DSE profile. New curves have built-in defaults.'
}
Write-Output "Installed DSE and updated the file manifest. Previous files: $backup"
