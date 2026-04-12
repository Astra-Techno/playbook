@echo off
setlocal

echo [1/3] Building Frontend...
cd frontend
call npm install
call npm run build
if %ERRORLEVEL% neq 0 (
    echo Frontend build failed!
    exit /b %ERRORLEVEL%
)
cd ..

echo [2/3] Preparing Deployment Package...
if exist deploy_package rmdir /s /q deploy_package
mkdir deploy_package

echo [3/3] Copying files...
xcopy /E /I backend deploy_package\backend
xcopy /E /I frontend\dist deploy_package\public_html
copy .htaccess deploy_package\public_html\

echo.
echo ========================================================
echo Deployment Package Ready in: deploy_package/
echo.
echo INSTRUCTIONS for kocourt.com:
echo 1. Upload content of 'deploy_package/public_html/' to the ROOT of kourtcurt.com
echo 2. Upload 'deploy_package/backend/' folder to kourtcurt.com/backend/
echo 3. Update 'backend/.env' on the server with production DB credentials.
echo ========================================================
pause
