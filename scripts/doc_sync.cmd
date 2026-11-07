@echo off
setlocal
set "DOCSYNC_SCRIPT=%~dp0doc_sync.ps1"
set "DOCSYNC_CONFIG=%~dp0..\.local\doc-sync.json"
set "DOCSYNC_ACTION="
if /I "%~1"=="start" set "DOCSYNC_ACTION=Start"
if /I "%~1"=="status" set "DOCSYNC_ACTION=Status"
if /I "%~1"=="stop" set "DOCSYNC_ACTION=Stop"
if not defined DOCSYNC_ACTION (
  echo Usage: doc_sync.cmd start^|status^|stop
  exit /b 2
)
powershell.exe -NoProfile -NonInteractive -Command "$code=[IO.File]::ReadAllText($env:DOCSYNC_SCRIPT); & ([scriptblock]::Create($code)) -Action $env:DOCSYNC_ACTION -ConfigPath $env:DOCSYNC_CONFIG"
exit /b %ERRORLEVEL%
