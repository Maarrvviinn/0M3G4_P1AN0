@echo off
title Deploy 0M3G4 P1AN0

echo ====================================================
echo             0M3G4 P1AN0 Deployment Tool
echo ====================================================
echo.

:: Navigate to script directory
cd /d "%~dp0"

:: Check if git repository is present
git rev-parse --is-inside-work-tree >nul 2>&1
if errorlevel 1 (
    echo [ERROR] Not inside a Git repository!
    echo Please run this batch script from the 0M3G4 P1AN0 repository folder.
    pause
    exit /b 1
)

:: Prompt for commit message or use default
set "msg="
set /p "msg=Enter commit message (press ENTER for 'update'): "
if "%msg%"=="" set "msg=update"

echo.
echo [1/3] Staging all files...
git add -A

echo [2/3] Committing changes with message: "%msg%"...
git commit -m "%msg%"

echo.
echo [3/3] Pushing to GitHub (origin/main)...
git push origin main
if errorlevel 1 (
    echo.
    echo [ERROR] Failed to push to origin main! Check your authentication or network.
    pause
    exit /b 1
)

echo.
echo ====================================================
echo    [SUCCESS] Deployment complete!
echo    Direct loader is live at:
echo    https://raw.githubusercontent.com/Maarrvviinn/0M3G4_P1AN0/main/loader.lua
echo ====================================================
echo.
pause
