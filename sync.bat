@echo off
cd /d "%~dp0"
echo Syncing zombie-horde from GitHub...
git fetch origin
if errorlevel 1 (
    echo Fetch failed. Check your internet connection.
    pause
    exit /b 1
)
git reset --hard origin/main
if errorlevel 1 (
    echo Reset failed.
    pause
    exit /b 1
)
echo.
echo Done. Open Godot and press F5.
pause
