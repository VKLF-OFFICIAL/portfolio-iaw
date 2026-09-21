@echo off
rem Doble clic, o arrastra archivos/carpetas sobre este archivo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0subir.ps1" %*
echo.
pause
