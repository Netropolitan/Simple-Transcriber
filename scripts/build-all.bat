@echo off
setlocal

echo ========================================
echo Simple Transcriber - Full Build
echo ========================================
echo.

:: Configuration
set "AHK_ROOT=C:\Program Files\AutoHotkey"
set "AHK_COMPILER=%AHK_ROOT%\Compiler\Ahk2Exe.exe"
set "AHK_BASE=%AHK_ROOT%\v2\AutoHotkey64.exe"
set "PROJECT_ROOT=%~dp0.."
set "BUILD_DIR=%PROJECT_ROOT%\build"
set "ICON=%PROJECT_ROOT%\assets\icon.ico"

:: Run main app compilation
call "%~dp0compile.bat"
if errorlevel 1 (
    echo Build failed at compilation step
    exit /b 1
)

echo.
echo Compiling installer...
"%AHK_COMPILER%" /in "%PROJECT_ROOT%\installer\Setup.ahk" /out "%BUILD_DIR%\SimpleTranscriber-Setup.exe" /icon "%ICON%" /base "%AHK_BASE%"
if errorlevel 1 (
    echo ERROR: Installer compilation failed
    exit /b 1
)
echo Installer compiled successfully.

echo.
echo Compiling uninstaller...
"%AHK_COMPILER%" /in "%PROJECT_ROOT%\installer\Uninstall.ahk" /out "%BUILD_DIR%\Uninstall.exe" /icon "%ICON%" /base "%AHK_BASE%"
if errorlevel 1 (
    echo ERROR: Uninstaller compilation failed
    exit /b 1
)
echo Uninstaller compiled successfully.

echo.
echo ========================================
echo Full build completed successfully!
echo ========================================
echo.
echo Outputs:
echo   - build\SimpleTranscriber.exe
echo   - build\SimpleTranscriber-Setup.exe
echo   - build\Uninstall.exe
echo   - build\settings.default.ini
echo   - build\icon.ico
echo.
echo Next steps:
echo   1. Test the application
echo   2. Create GitHub release
echo.

exit /b 0
