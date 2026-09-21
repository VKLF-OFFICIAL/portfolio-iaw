@echo off
rem Doble clic, o arrastra el PDF sobre este archivo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0subir.ps1" %*
echo.
pause
