# Shuyi Playland — Android One-Click Build & Install
# Usage: pwsh build_and_install.ps1 [-ExportOnly] [-SkipInstall] [-DeviceId "emulator-5556"]
param(
    [switch]$ExportOnly,
    [switch]$SkipInstall,
    [string]$DeviceId = "",
    [string]$GodotExe = "godot"
)

$ErrorActionPreference = "Stop"
$ScriptDir = Split-Path -Parent $MyInvocation.MyCommand.Path
$ProjectRoot = Resolve-Path "$ScriptDir\..\.."
$BuildDir = "$ProjectRoot\builds"
$InputApk = "$BuildDir\shuyi-playland-debug.apk"
$SignedApk = "$BuildDir\shuyi-playland-debug-signed.apk"

# Step 1: Export APK from Godot (headless)
Write-Host "[1/4] Exporting APK from Godot..." -ForegroundColor Cyan
$exportArgs = @(
    "--headless",
    "--path", $ProjectRoot,
    "--export-debug", "Android",
    $InputApk
)
& $GodotExe @exportArgs
if ($LASTEXITCODE -ne 0) {
    throw "Godot export failed with exit code $LASTEXITCODE"
}
Write-Host "  APK exported: $InputApk" -ForegroundColor Green

if ($ExportOnly) {
    Write-Host "Export-only mode. Done." -ForegroundColor Green
    exit 0
}

# Step 2: Sign the APK
Write-Host "[2/4] Signing APK..." -ForegroundColor Cyan
$signScript = Join-Path $ScriptDir "sign_android_debug_apk.ps1"
if (!(Test-Path $signScript)) {
    throw "Sign script not found: $signScript"
}
& $signScript -InputApk $InputApk
Write-Host "  Signed APK: $SignedApk" -ForegroundColor Green

if ($SkipInstall) {
    Write-Host "Skip-install mode. Done." -ForegroundColor Green
    exit 0
}

# Step 3: Install to device
Write-Host "[3/4] Installing to device..." -ForegroundColor Cyan
$adbArgs = @("install", "-r", $SignedApk)
if ($DeviceId) {
    $adbArgs = @("-s", $DeviceId) + $adbArgs
}
$installOutput = & adb @adbArgs 2>&1
if ($LASTEXITCODE -ne 0) {
    Write-Host "  adb install failed: $installOutput" -ForegroundColor Yellow
    Write-Host "  Trying to restart adb daemon..." -ForegroundColor Yellow
    & adb kill-server 2>&1 | Out-Null
    & adb start-server 2>&1 | Out-Null
    Start-Sleep -Seconds 3
    $installOutput = & adb @adbArgs 2>&1
    if ($LASTEXITCODE -ne 0) {
        throw "adb install retry also failed: $installOutput"
    }
}
Write-Host "  Install output: $installOutput" -ForegroundColor Green

# Step 4: Verify installation
Write-Host "[4/4] Verifying installation..." -ForegroundColor Cyan
$pmArgs = @("shell", "pm", "list", "packages", "com.shuyi.playland")
$dumpArgs = @("shell", "dumpsys", "package", "com.shuyi.playland")
if ($DeviceId) {
    $pmArgs = @("-s", $DeviceId) + $pmArgs
    $dumpArgs = @("-s", $DeviceId) + $dumpArgs
}

$pkgList = & adb @pmArgs 2>&1
if ($pkgList -match "com.shuyi.playland") {
    Write-Host "  Package found on device: $pkgList" -ForegroundColor Green
    $dumpsysOut = & adb @dumpArgs 2>&1
    $versionMatch = [regex]::Match($dumpsysOut, "versionName=([^\s]+)")
    if ($versionMatch.Success) {
        Write-Host "  Installed version: $($versionMatch.Groups[1].Value)" -ForegroundColor Green
    }
    Write-Host "`nBuild & install complete!" -ForegroundColor Green
    Write-Host "Launch with: adb shell am start -n com.shuyi.playland/com.godot.game.GodotApp" -ForegroundColor Cyan
} else {
    Write-Host "  WARNING: Package NOT found on device. Install may have failed silently." -ForegroundColor Red
    Write-Host "  Check device connection and try again." -ForegroundColor Red
    exit 1
}
