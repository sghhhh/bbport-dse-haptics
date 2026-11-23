# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$Clang64,
    [Parameter(Mandatory)] [string]$Scratch,
    [Parameter(Mandatory)] [string]$OutputDir
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
New-Item -ItemType Directory -Force -Path $Scratch, $OutputDir | Out-Null
$Scratch = (Resolve-Path -LiteralPath $Scratch).Path
$OutputDir = (Resolve-Path -LiteralPath $OutputDir).Path
$release = 'https://github.com/Supermedo/bloodborne_pc/releases/download/windows-v1.9.8.6'
$msysRepo = 'https://repo.msys2.org/mingw/clang64'

function Get-CheckedArchive([string]$Url, [string]$Path, [string]$SHA256) {
    & curl.exe --fail --location --retry 3 --silent --show-error --output $Path $Url
    if ($LASTEXITCODE -ne 0) { throw "Could not download $Url." }
    if ((Get-FileHash -LiteralPath $Path).Hash -ne $SHA256) { throw "Archive digest mismatch for $Url." }
}

$sourceZip = Join-Path $Scratch 'seamless.zip'
Get-CheckedArchive "$release/bb-probe-seamless-1.9.8.6-source.zip" $sourceZip `
    '2fc82471bc71965ede76cbcab3c19ea03854014340f1704252ee750b6ba4d8ef'
$sourceDir = Join-Path $Scratch 'seamless'
Expand-Archive -LiteralPath $sourceZip -DestinationPath $sourceDir
$seamless = Join-Path $sourceDir 'bb-probe-seamless-src'
$windows = Join-Path $Scratch 'windows'
& git clone --quiet --depth 1 --branch windows-v1.9.8.6 --filter=blob:none --sparse `
    https://github.com/Supermedo/bloodborne_pc.git $windows
if ($LASTEXITCODE -ne 0) { throw 'Windows source checkout failed.' }
& git -C $windows sparse-checkout set launcher scripts packaging/windows
if ($LASTEXITCODE -ne 0) { throw 'Windows sparse checkout failed.' }
& "$PSScriptRoot/apply-patches.ps1" -WindowsSource $windows -SeamlessSource $seamless

# Match the DLL interfaces shipped in the 1.9.8.6 base, using an overlay prefix.
$packages = [ordered]@{
    'sdl3-3.4.18-1'           = '26847e18a9f413a1ebec5a2359881ceeef810558c63235ca0997a353c868035b'
    'ffmpeg-9.0.2-3'          = '621d4c8ad1f377d3182dd99b66a83df2a256b5ff4dd89a26c5285e64c8751abe'
    'openssl-3.6.5-1'         = 'c6be6a00e4c5672306d3abefa195d8341d57f6d9c52a066bc6145d50038e4c62'
    'protobuf-36.2-1'         = 'db5ac36d574f450f850a3070cfab7225cf6494f60af8afe88cc7d6d37f142712'
    'abseil-cpp-20260526.0-1' = '6474858963f7dda27bea60659de58c974273e2d0897ef3af1177a6cb69b70de0'
    'zlib-1.3.2-1'            = '035f5162093177f39eaee9711f2aa3619716d33413dde3dd8307965c5eb1155d'
}
$prefix = Join-Path $Scratch 'dependencies'
New-Item -ItemType Directory -Force -Path $prefix | Out-Null
foreach ($package in $packages.GetEnumerator()) {
    $name = "mingw-w64-clang-x86_64-$($package.Key)-any.pkg.tar.zst"
    $archive = Join-Path $Scratch $name
    Get-CheckedArchive "$msysRepo/$name" $archive $package.Value
    & tar.exe -xf $archive -C $prefix clang64
    if ($LASTEXITCODE -ne 0) { throw "Could not extract $name." }
}

$env:CMAKE_BUILD_PARALLEL_LEVEL = [Math]::Min(4, [Environment]::ProcessorCount).ToString()
& "$PSScriptRoot/build-seamless.ps1" -SeamlessSource $seamless -Clang64 $Clang64 `
    -DependencyPrefix (Join-Path $prefix 'clang64')
$python = (Get-Command python.exe).Source
& $python -m pip install --disable-pip-version-check pyinstaller==6.22.3 pillow==13.0.0
if ($LASTEXITCODE -ne 0) { throw 'Could not install launcher build dependencies.' }
& "$PSScriptRoot/build-launcher.ps1" -WindowsSource $windows -Python $python -OmitBenchmarkSave

$stage = Join-Path $Scratch 'package'
$payload = Join-Path $stage 'payload'
New-Item -ItemType Directory -Force -Path (Join-Path $payload 'bin'), (Join-Path $payload 'licenses') | Out-Null
$built = Join-Path $repo '.build/seamless/bb-probe-seamless.exe'
$launcher = Join-Path $repo '.build/dist/Bloodborne'
$engine = Join-Path $payload 'bin/bb-probe-seamless-dse.exe'
Copy-Item -LiteralPath $built -Destination $engine
Copy-Item -LiteralPath (Join-Path $launcher 'Bloodborne.exe') -Destination $payload
Copy-Item -LiteralPath (Join-Path $launcher '_launcher_dse') -Destination $payload -Recurse
Copy-Item -LiteralPath (Join-Path $Clang64 'bin/libc++.dll') -Destination (Join-Path $payload 'bin')
Copy-Item -LiteralPath (Join-Path $Clang64 'share/licenses/libc++/LICENSE') `
    -Destination (Join-Path $payload 'licenses/dse-libcxx.txt')
Copy-Item -LiteralPath (Join-Path $repo 'mods') -Destination $payload -Recurse
Copy-Item -LiteralPath "$PSScriptRoot/install-windows.ps1" -Destination (Join-Path $stage 'Install-DSE.ps1')
Copy-Item -LiteralPath (Join-Path $repo 'LICENSE') -Destination $stage
Copy-Item -LiteralPath (Join-Path $repo 'docs/releases.md') -Destination (Join-Path $stage 'README.md')
Copy-Item -LiteralPath (Join-Path $repo 'docs/profiles.md') -Destination $stage

# Launch without game files or a GPU after resolving imports against the exact base DLLs.
$runtimeZip = Join-Path $Scratch 'base-runtime.zip'
Get-CheckedArchive "$release/Bloodborne-Windows.zip" $runtimeZip `
    '182be6863141c9c7e4622731e67a2c25ee3dfe97f62255bfb2af1a194c673317'
$check = Join-Path $Scratch 'loader-check'
New-Item -ItemType Directory -Force -Path $check | Out-Null
$archive = [IO.Compression.ZipFile]::OpenRead($runtimeZip)
try {
    foreach ($entry in $archive.Entries) {
        if ($entry.FullName -match '^(?:[^/]+/)?bin/([^/]+\.dll)$') {
            [IO.Compression.ZipFileExtensions]::ExtractToFile($entry, (Join-Path $check $Matches[1]), $true)
        }
    }
} finally {
    $archive.Dispose()
}
Copy-Item -LiteralPath $engine, (Join-Path $payload 'bin/libc++.dll') -Destination $check -Force
if (-not (Test-Path -LiteralPath (Join-Path $env:SystemRoot 'System32/vulkan-1.dll'))) {
    Copy-Item -LiteralPath (Join-Path $Clang64 'bin/vulkan-1.dll') -Destination $check
}
$stdout = Join-Path $check 'stdout.txt'
$stderr = Join-Path $check 'stderr.txt'
$oldPath = $env:PATH
$oldCpuCheck = $env:BB_SKIP_CPU_CHECK
try {
    $env:PATH = "$env:SystemRoot\System32;$env:SystemRoot"
    $env:BB_SKIP_CPU_CHECK = '1'
    $process = Start-Process -FilePath (Join-Path $check 'bb-probe-seamless-dse.exe') `
        -WorkingDirectory $check -WindowStyle Hidden -PassThru `
        -RedirectStandardOutput $stdout -RedirectStandardError $stderr
    if (-not $process.WaitForExit(30000)) {
        $process.Kill()
        throw 'Engine loader check timed out.'
    }
} finally {
    $env:PATH = $oldPath
    $env:BB_SKIP_CPU_CHECK = $oldCpuCheck
}
if ($process.ExitCode -ne 1 -or -not (Select-String -LiteralPath $stderr, $stdout -SimpleMatch 'Usage:')) {
    throw "The engine did not reach its usage screen against the base DLLs (exit $($process.ExitCode))."
}
if (Get-ChildItem -LiteralPath (Join-Path $payload '_launcher_dse') -Recurse -File -Filter 'userdata*') {
    throw 'The launcher archive included a character save.'
}
Write-Output 'The x86-64 engine reached its usage screen with the bbport 1.9.8.6 runtime.'
Compress-Archive -Path (Join-Path $stage '*') -DestinationPath (Join-Path $OutputDir 'bbport-dse8-windows-x86_64.zip')
Compress-Archive -LiteralPath (Join-Path $repo 'mods'), (Join-Path $repo 'docs/profiles.md'), (Join-Path $repo 'LICENSE') `
    -DestinationPath (Join-Path $OutputDir 'bbport-dse8-profiles.zip')
