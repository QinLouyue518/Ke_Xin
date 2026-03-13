@echo off
chcp 65001 >nul
echo ========================================
echo   Flutter APK Build Tool
echo ========================================
echo.

REM Step 1: Update version
echo Step 1/2: Updating version...
echo.

powershell.exe -ExecutionPolicy Bypass -File "%~dp0bump_version.ps1"

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo Version update failed, build terminated
    pause
    exit /b 1
)

echo.
echo ========================================
echo.

REM Step 2: Build APK
echo Step 2/2: Building APK...
echo.

flutter build apk --release

if %ERRORLEVEL% NEQ 0 (
    echo.
    echo APK build failed
    pause
    exit /b 1
)

echo.
echo ========================================
echo   Build Completed!
echo ========================================
echo.

REM Show APK info
set APK_PATH=build\app\outputs\flutter-apk\app-release.apk
if exist "%APK_PATH%" (
    echo APK Location: %APK_PATH%
    for %%A in ("%APK_PATH%") do echo APK Size: %%~zA bytes
    echo.
    set /p OPEN="Open APK folder? (Y/N): "
    if /i "%OPEN%"=="Y" explorer.exe /select,"%CD%\%APK_PATH%"
) else (
    echo APK file not found, please check build logs
)

echo.
echo Next build will auto-increment version
echo.
pause
