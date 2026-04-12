@echo off
setlocal
title KoCourt – Push to GitHub

echo.
echo Pushing to GitHub...
echo (GitHub Actions will build the frontend automatically)
echo.

git add .
git status
echo.
set /p msg=Commit message (or press Enter for default):
if "%msg%"=="" set msg=update

git commit -m "%msg%"
git push

echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║  Code pushed! GitHub Actions is now building the frontend.  ║
echo ║                                                              ║
echo ║  Once the build completes (~1-2 min), run deploy:           ║
echo ║  https://kocourt.com/deploy.php?key=YOUR_DEPLOY_KEY         ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
pause
