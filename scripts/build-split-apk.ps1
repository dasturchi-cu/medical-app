# Split APK build (kichik hajm — har ABI alohida)
# Natija: build/app/outputs/flutter-apk/
#   app-arm64-v8a-release.apk   (~32 MB) — zamonaviy telefonlar
#   app-armeabi-v7a-release.apk (~30 MB) — eski 32-bit
#   app-x86_64-release.apk      (~33 MB) — emulyator

$ErrorActionPreference = "Stop"
$Root = Split-Path $PSScriptRoot -Parent
$ApiBaseUrl = if ($env:API_BASE_URL) { $env:API_BASE_URL } else { "http://84.46.243.149" }

Set-Location $Root
Write-Host "Building split APKs in $Root ..." -ForegroundColor Cyan
Write-Host "API_BASE_URL=$ApiBaseUrl" -ForegroundColor Yellow
flutter build apk --release --split-per-abi `
  --dart-define=API_BASE_URL=$ApiBaseUrl

$out = Join-Path $Root "build\app\outputs\flutter-apk"
$version = (Select-String -Path (Join-Path $Root "pubspec.yaml") -Pattern '^version:\s*(\S+)' | ForEach-Object { $_.Matches[0].Groups[1].Value })
$dest = Join-Path $Root "releases\apk-split-$version"
New-Item -ItemType Directory -Force -Path $dest | Out-Null

Get-ChildItem $out -Filter "app-*-release.apk" | Copy-Item -Destination $dest -Force

Write-Host ""
Write-Host "Tayyor:" -ForegroundColor Green
Get-ChildItem $dest -Filter "*.apk" | ForEach-Object {
    $mb = [math]::Round($_.Length / 1MB, 1)
    Write-Host "  $($_.Name) - $mb MB ($($_.Length) bytes)"
}
Write-Host ""
Write-Host "Railway admin Variables (misol):" -ForegroundColor Yellow
Write-Host "  APK_SOURCE_URL_ARM64=https://.../app-arm64-v8a-release.apk"
Write-Host "  APK_SOURCE_URL_ARM32=https://.../app-armeabi-v7a-release.apk"
Write-Host "  APK_SOURCE_URL_X64=https://.../app-x86_64-release.apk"
Write-Host "  APK_CONTENT_LENGTH_ARM64=33401578"
Write-Host "  APK_CONTENT_LENGTH_ARM32=31684378"
Write-Host "  APK_CONTENT_LENGTH_X64=34949414"

