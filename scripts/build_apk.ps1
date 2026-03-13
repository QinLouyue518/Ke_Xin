# Flutter APK One-Click Build Script
# Function: Auto-increment version and build APK

$ErrorActionPreference = "Stop"

Write-Host "========================================" -ForegroundColor Cyan
Write-Host "  Flutter APK Build Tool" -ForegroundColor Cyan
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 1. Increment version
Write-Host "Step 1/2: Updating version..." -ForegroundColor Yellow
Write-Host ""

& "$PSScriptRoot\bump_version.ps1"

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nVersion update failed, build terminated" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "========================================" -ForegroundColor Cyan
Write-Host ""

# 2. Build APK
Write-Host "Step 2/2: Building APK..." -ForegroundColor Yellow
Write-Host ""

flutter build apk --release

if ($LASTEXITCODE -ne 0) {
    Write-Host "`nAPK build failed" -ForegroundColor Red
    exit 1
}

# 3. Show results
Write-Host ""
Write-Host "========================================" -ForegroundColor Green
Write-Host "  Build Completed!" -ForegroundColor Green
Write-Host "========================================" -ForegroundColor Green
Write-Host ""

# Get APK path
$apkPath = "build\app\outputs\flutter-apk\app-release.apk"
if (Test-Path $apkPath) {
    $apkSize = (Get-Item $apkPath).Length / 1MB
    Write-Host "APK Location: $apkPath" -ForegroundColor Cyan
    Write-Host "APK Size: $([math]::Round($apkSize, 2)) MB" -ForegroundColor Cyan
    Write-Host ""
    
    # Ask if open folder
    $openExplorer = Read-Host "Open APK folder? (Y/N)"
    if ($openExplorer -eq "Y" -or $openExplorer -eq "y") {
        explorer.exe "/select,$(Resolve-Path $apkPath)"
        Write-Host "Folder opened" -ForegroundColor Green
    }
} else {
    Write-Host "APK file not found, please check build logs" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Next build will auto-increment version" -ForegroundColor Cyan
Write-Host ""
