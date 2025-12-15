@echo off
echo ========================================
echo GPIB Dependencies Installation Script
echo ========================================
echo.

REM Check if Python is installed
python --version >nul 2>&1
if %errorlevel% neq 0 (
    echo [ERROR] Python is not installed or not in PATH
    echo Please install Python 3.8+ from https://www.python.org/downloads/
    echo Make sure to check "Add Python to PATH" during installation
    pause
    exit /b 1
)

echo [INFO] Python found:
python --version
echo.

REM Upgrade pip
echo [INFO] Upgrading pip...
python -m pip install --upgrade pip
echo.

REM Install PyVISA
echo [INFO] Installing PyVISA...
pip install pyvisa
if %errorlevel% neq 0 (
    echo [ERROR] Failed to install PyVISA
    pause
    exit /b 1
)
echo.

REM Install PyVISA-py (optional backend)
echo [INFO] Installing PyVISA-py...
pip install pyvisa-py
echo.

REM Install pandas for data export (optional)
echo [INFO] Installing pandas...
pip install pandas openpyxl
echo.

REM Verify installation
echo [INFO] Verifying installation...
python -c "import pyvisa; print('PyVISA version:', pyvisa.__version__)"
if %errorlevel% neq 0 (
    echo [ERROR] PyVISA verification failed
    pause
    exit /b 1
)
echo.

REM List available VISA resources
echo [INFO] Scanning for VISA resources...
python -c "import pyvisa; rm = pyvisa.ResourceManager(); print('Available resources:'); print(rm.list_resources())"
echo.

echo ========================================
echo Installation completed successfully!
echo ========================================
echo.
echo Next steps:
echo 1. Connect your GPIB adapter to the computer
echo 2. Install GPIB driver (NI-488.2 or Keysight IO Libraries)
echo 3. Run the Flutter application
echo 4. Click "GPIB Test" in the menu bar
echo.
pause
