@echo off
echo ============================================================
echo   SIGMA Local yfinance Gateway - Startup
echo ============================================================
echo.

cd /d "%~dp0"

python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not in PATH!
    pause
    exit /b 1
)

echo [1/2] Installing dependencies...
python -m pip install -q -r requirements.txt

echo [2/2] Starting local gateway on port 8642...
echo.
python -m uvicorn data_server:app --host 0.0.0.0 --port 8642

pause
