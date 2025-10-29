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

rem Auto-select option 1 (Pro to EnterpriseG) via stdin redirection (robust)
set "INPUT=%ROOT%\bedi_input.txt"
>"%INPUT%" echo 1
if exist "%NSUDO%" (
  echo Using NSudo to run Bedi as TrustedInstaller/System...
  "%NSUDO%" -U:T -P:E -UseCurrentConsole -Wait cmd /c "pushd "%ROOT%" && call "%BEDI%" ^< "%INPUT%""
) else (
  echo Running Bedi directly...
  cmd /c "pushd "%ROOT%" && call "%BEDI%" ^< "%INPUT%""
)
del /f /q "%INPUT%" >nul 2>nul

set "RC=%ERRORLEVEL%"
popd
exit /b %RC%


