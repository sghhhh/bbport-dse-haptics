# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$SeamlessSource,
    [string]$Clang64 = 'C:\msys64\clang64',
    [string]$DependencyPrefix,
    [string]$Revision = 'bbsc100-p198-dse6'
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$gpu = Join-Path (Resolve-Path -LiteralPath $SeamlessSource).Path 'gpu'
$clang = (Resolve-Path -LiteralPath $Clang64).Path
if ($DependencyPrefix) {
    $dependencies = (Resolve-Path -LiteralPath $DependencyPrefix).Path
} else {
    $dependencies = $clang
}
$build = Join-Path $repo '.build/seamless'
$cmake = Join-Path $clang 'bin/cmake.exe'
$ninja = Join-Path $clang 'bin/ninja.exe'
$pkgconf = Join-Path $clang 'bin/pkg-config.exe'
$savedPath = $env:PATH
$savedPkgConfig = $env:PKG_CONFIG_PATH

try {
    $env:PATH = "$(Join-Path $dependencies 'bin');$(Join-Path $clang 'bin');$savedPath"
    $env:PKG_CONFIG_PATH = "$(Join-Path $dependencies 'lib/pkgconfig');$(Join-Path $clang 'lib/pkgconfig')"
    & $pkgconf --modversion sdl3 libavformat libavcodec libavutil libswscale libswresample
    if ($LASTEXITCODE -ne 0) { throw 'CLANG64 dependencies are missing.' }

    $options = @(
        '-S', $gpu, '-B', $build, '-G', 'Ninja',
        "-DCMAKE_MAKE_PROGRAM=$ninja",
        "-DCMAKE_PREFIX_PATH=$dependencies;$clang",
        "-DCMAKE_C_COMPILER=$(Join-Path $clang 'bin/clang.exe')",
        "-DCMAKE_CXX_COMPILER=$(Join-Path $clang 'bin/clang++.exe')",
        "-DPKG_CONFIG_EXECUTABLE=$pkgconf",
        "-DOPENSSL_ROOT_DIR=$dependencies",
        "-DProtobuf_DIR=$(Join-Path $dependencies 'lib/cmake/protobuf')",
        "-Dabsl_DIR=$(Join-Path $dependencies 'lib/cmake/absl')",
        '-DCMAKE_BUILD_TYPE=Release', '-DCMAKE_C_FLAGS_RELEASE=-O2 -DNDEBUG',
        '-DCMAKE_CXX_FLAGS_RELEASE=-O2 -DNDEBUG', '-DBB_PGO=off', '-DBB_LTO=OFF',
        "-DBB_SEAMLESS_REVISION=$Revision"
    )
    & $cmake @options
    if ($LASTEXITCODE -ne 0) { throw 'Seamless configuration failed.' }

    & $cmake --build $build --target bb-probe
    if ($LASTEXITCODE -ne 0) { throw 'Seamless build failed.' }
    Write-Output (Join-Path $build 'bb-probe-seamless.exe')
} finally {
    $env:PATH = $savedPath
    $env:PKG_CONFIG_PATH = $savedPkgConfig
}
