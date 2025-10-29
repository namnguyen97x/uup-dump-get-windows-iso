@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
pushd "%ROOT%"

set "NSUDO=%ROOT%\Files\NSudo.exe"
set "BEDI=%ROOT%\Bedi.cmd"
if not exist "%BEDI%" (
  echo ERROR: Bedi.cmd not found at "%BEDI%"
  exit /b 1
)

rem Auto-select option 1 (Pro to EnterpriseG); Lite options come from Bedi.ini
if exist "%NSUDO%" (
  echo Using NSudo to run Bedi as TrustedInstaller/System...
  "%NSUDO%" -U:T -P:E -UseCurrentConsole -Wait cmd /c "pushd "%ROOT%" && (echo 1) ^| call "%BEDI%""
) else (
  echo Running Bedi directly...
  cmd /c "pushd "%ROOT%" && (echo 1) ^| call "%BEDI%""
)

set "RC=%ERRORLEVEL%"
popd
exit /b %RC%


