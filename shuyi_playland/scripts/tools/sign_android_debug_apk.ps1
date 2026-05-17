param(
    [string]$InputApk = "E:\Archive\Godot\shuyi\shuyi_playland\builds\shuyi-playland-debug.apk",
    [string]$AlignedApk = "E:\Archive\Godot\shuyi\shuyi_playland\builds\shuyi-playland-debug-aligned.apk",
    [string]$SignedApk = "E:\Archive\Godot\shuyi\shuyi_playland\builds\shuyi-playland-debug-signed.apk",
    [string]$BuildToolsDir = "D:\Program\Android\SDK\build-tools\35.0.1",
    [string]$Keystore = "$env:USERPROFILE\.android\debug.keystore",
    [string]$KeystorePassword = "android",
    [string]$KeyAlias = "androiddebugkey"
)

$ErrorActionPreference = "Stop"

if (!(Test-Path $InputApk)) {
    throw "Input APK not found: $InputApk"
}

$zipalign = Join-Path $BuildToolsDir "zipalign.exe"
$apksigner = Join-Path $BuildToolsDir "apksigner.bat"

if (!(Test-Path $zipalign)) {
    throw "zipalign.exe not found: $zipalign"
}

if (!(Test-Path $apksigner)) {
    throw "apksigner.bat not found: $apksigner"
}

if (!(Test-Path $Keystore)) {
    throw "Debug keystore not found: $Keystore"
}

Remove-Item $AlignedApk, $SignedApk, "$SignedApk.idsig" -ErrorAction SilentlyContinue

& $zipalign -f 4 $InputApk $AlignedApk
if ($LASTEXITCODE -ne 0) {
    throw "zipalign failed with exit code $LASTEXITCODE"
}

& $apksigner sign --ks $Keystore --ks-pass "pass:$KeystorePassword" --key-pass "pass:$KeystorePassword" --ks-key-alias $KeyAlias --out $SignedApk $AlignedApk
if ($LASTEXITCODE -ne 0) {
    throw "apksigner sign failed with exit code $LASTEXITCODE"
}

& $apksigner verify --verbose $SignedApk
if ($LASTEXITCODE -ne 0) {
    throw "apksigner verify failed with exit code $LASTEXITCODE"
}

Write-Host "Signed APK ready: $SignedApk"
