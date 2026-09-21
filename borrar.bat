@echo off
rem Doble clic para borrar tareas o un tema del portfolio.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0borrar.ps1" %*
echo.
pause
