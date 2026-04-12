@echo off
setlocal
title KoCourt – Build & Push

echo.
echo ╔═════════════════════════════════════╗
echo ║   KoCourt – Build and Push to Git  ║
echo ╚═════════════════════════════════════╝
echo.

:: ── Step 1: Build Frontend ──────────────────────────────────────────────────
echo [1/4] Building Vue frontend...
cd frontend
call npm install --silent
call npm run build
if %ERRORLEVEL% neq 0 (
    echo  ERROR: Frontend build failed!
    pause & exit /b 1
)
cd ..
echo  Done.
echo.

:: ── Step 2: Copy dist → public_html/ in repo ────────────────────────────────
echo [2/4] Copying build output to public_html/...
if exist public_html rmdir /s /q public_html
mkdir public_html
xcopy /E /I /Q frontend\dist\* public_html\
echo  Done.
echo.

:: ── Step 3: Git add, commit, push ───────────────────────────────────────────
echo [3/4] Committing and pushing to GitHub...
git add public_html/ backend/ frontend/src/ .gitignore .htaccess deploy.php
git commit -m "build: deploy $(date /t) $(time /t)"
git push
if %ERRORLEVEL% neq 0 (
    echo  ERROR: Git push failed! Check your credentials.
    pause & exit /b 1
)
echo  Done.
echo.

:: ── Step 4: Instructions ────────────────────────────────────────────────────
echo [4/4] Build pushed to GitHub.
echo.
echo ╔══════════════════════════════════════════════════════════════╗
echo ║  Now deploy to kocourt.com — open this URL in your browser: ║
echo ║                                                              ║
echo ║  https://kocourt.com/deploy.php?key=YOUR_DEPLOY_KEY         ║
echo ║                                                              ║
echo ║  (DEPLOY_KEY is set in backend/.env on the server)          ║
echo ╚══════════════════════════════════════════════════════════════╝
echo.
pause
