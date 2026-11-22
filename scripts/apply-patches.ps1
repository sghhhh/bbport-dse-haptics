# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$WindowsSource,
    [Parameter(Mandatory)] [string]$SeamlessSource
)

$ErrorActionPreference = 'Stop'
$windows = (Resolve-Path -LiteralPath $WindowsSource).Path
$seamless = (Resolve-Path -LiteralPath $SeamlessSource).Path
$repo = Split-Path -Parent $PSScriptRoot
$windowsCommit = 'b69561c0fae84f115db00110d28442ee5f3672d5'

$head = & git -C $windows rev-parse HEAD
if ($LASTEXITCODE -ne 0 -or $head -ne $windowsCommit) {
    throw "Windows source needs tag windows-v1.9.8.6 at $windowsCommit."
}
if (-not (Test-Path -LiteralPath (Join-Path $seamless 'gpu/CMakeLists.txt') -PathType Leaf)) {
    throw 'Select the extracted Seamless source directory that contains gpu/CMakeLists.txt.'
}

$changes = @(
    @{ Source = $seamless; Patch = Join-Path $repo 'patches/seamless-dse-haptics.patch' },
    @{ Source = $windows; Patch = Join-Path $repo 'patches/windows-launcher.patch' }
)
$oldCeiling = $env:GIT_CEILING_DIRECTORIES
try {
    # An extracted source archive must not be interpreted as a subdirectory of this repo.
    $env:GIT_CEILING_DIRECTORIES = Split-Path -Parent $seamless
    $pending = @()
    foreach ($change in $changes) {
        $details = & git -C $change.Source apply --check --whitespace=error $change.Patch 2>&1
        if ($LASTEXITCODE -eq 0) {
            $pending += $change
            continue
        }
        & git -C $change.Source apply --reverse --check $change.Patch 2>$null
        if ($LASTEXITCODE -ne 0) { throw "Patch check failed for $($change.Patch)`n$details" }
        Write-Output "Already applied $([IO.Path]::GetFileName($change.Patch))"
    }
    foreach ($change in $pending) {
        & git -C $change.Source apply --whitespace=error $change.Patch
        if ($LASTEXITCODE -ne 0) { throw "Could not apply: $($change.Patch)" }
        Write-Output "Applied $([IO.Path]::GetFileName($change.Patch))"
    }
} finally {
    $env:GIT_CEILING_DIRECTORIES = $oldCeiling
}
