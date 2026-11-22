# SPDX-License-Identifier: GPL-2.0-or-later
[CmdletBinding()]
param(
    [Parameter(Mandatory)] [string]$WindowsSource,
    [string]$Python
)

$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$source = (Resolve-Path -LiteralPath $WindowsSource).Path
$launcher = Join-Path $source 'launcher'
$build = Join-Path $repo '.build/launcher'
$dist = Join-Path $repo '.build/dist'
if (-not $Python) { $Python = Join-Path $repo '.build/venv/Scripts/python.exe' }
$Python = (Resolve-Path -LiteralPath $Python).Path

$options = @(
    '-m', 'PyInstaller', '--noconfirm', '--clean', '--windowed', '--onedir',
    '--name', 'Bloodborne', '--contents-directory', '_launcher_dse',
    '--icon', (Join-Path $launcher 'bloodborne.ico'),
    '--distpath', $dist, '--workpath', $build, '--specpath', $build,
    '--paths', (Join-Path $source 'scripts'),
    '--add-data', "$(Join-Path $launcher 'assets');assets"
)
$imports = @('argparse', 'base64', 'bisect', 'collections', 'contextlib', 'hashlib',
             'json', 're', 'shutil', 'struct', 'tempfile', 'xml.etree.ElementTree',
             'urllib.request', 'ctypes.wintypes')
foreach ($module in $imports) { $options += @('--hidden-import', $module) }
$options += Join-Path $launcher 'bbport_launcher_win.py'

$savedCache = $env:PYINSTALLER_CONFIG_DIR
try {
    $env:PYINSTALLER_CONFIG_DIR = Join-Path $repo '.build/pyinstaller-cache'
    & $Python @options
    if ($LASTEXITCODE -ne 0) { throw 'Launcher build failed.' }
    Write-Output (Join-Path $dist 'Bloodborne')
} finally {
    $env:PYINSTALLER_CONFIG_DIR = $savedCache
}
