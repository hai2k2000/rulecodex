@echo off
setlocal
set "CODEX_MANAGED_PS=%~dp0codex-managed.ps1"
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%CODEX_MANAGED_PS%" %*
exit /b %ERRORLEVEL%
