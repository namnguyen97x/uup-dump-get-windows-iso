@echo off
setlocal EnableExtensions
set "ROOT=%~dp0"
if "%ROOT:~-1%"=="\" set "ROOT=%ROOT:~0,-1%"
pushd "%ROOT%"

rem --- Self-contained EnterpriseG automation (no dependency on Bedi.cmd) ---
set "BUILD=22621"
set "WIM=%ROOT%\install.wim"
set "MOUNT=%ROOT%\mnt_auto"
set "LOG=%ROOT%\log_auto"
set "BUILD_DIR=%ROOT%\%BUILD%"
set "EDITION=EnterpriseG"
set "EDITION_KEY=YYVX9-NTFWV-6MDM3-9PT4T-4M68B"
set "LANG=en-US"

if not exist "%WIM%" (echo ERROR: %WIM% not found.& exit /b 1)
if not exist "%BUILD_DIR%\Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd" (
  echo ERROR: Missing %BUILD%\Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd
  exit /b 1
)
if not exist "%BUILD_DIR%\Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd" (
  echo ERROR: Missing %BUILD%\Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd
  exit /b 1
)
if not exist "%LOG%" mkdir "%LOG%" >nul 2>nul

set "SEVENZ=%ROOT%\Files\7z.exe"
set "TMPPAY=%ROOT%\_payload_%BUILD%"
if exist "%TMPPAY%" rmdir /s /q "%TMPPAY%"
mkdir "%TMPPAY%" >nul 2>nul
if exist "%SEVENZ%" (
  "%SEVENZ%" x -y -o"%TMPPAY%" "%BUILD_DIR%\Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd" >nul 2>nul
  "%SEVENZ%" x -y -o"%TMPPAY%" "%BUILD_DIR%\Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd" >nul 2>nul
) else (
  echo WARNING: 7z.exe not found. Trying to add ESD directly may fail.
)

if exist "%MOUNT%" rmdir /s /q "%MOUNT%"
mkdir "%MOUNT%" >nul 2>nul
echo Mounting image...
dism /English /Mount-Image /ImageFile:"%WIM%" /Index:1 /MountDir:"%MOUNT%" /LogPath:"%LOG%\mount.log" || goto :fail

echo Setting edition to %EDITION% ...
dism /English /Image:"%MOUNT%" /Set-Edition:%EDITION% /ProductKey:%EDITION_KEY% /LogPath:"%LOG%\edition.log" >nul 2>nul

echo Adding language pack (en-US)...
for %%C in ("%TMPPAY%\*.cab") do (
  dism /English /Image:"%MOUNT%" /Add-Package /PackagePath:"%%~fC" /LogPath:"%LOG%\lp.log" >nul 2>nul
)
dism /English /Image:"%MOUNT%" /Set-AllIntl:%LANG% /LogPath:"%LOG%\intl.log" >nul 2>nul

echo Removing Microsoft Edge (best-effort)...
dism /English /Image:"%MOUNT%" /Remove-Edge /LogPath:"%LOG%\edge.log" >nul 2>nul

echo Committing image...
dism /English /Unmount-Image /MountDir:"%MOUNT%" /Commit /LogPath:"%LOG%\commit.log" || goto :fail

for /f "delims=" %%L in ('dism /English /Get-WimInfo /WimFile:"%WIM%" /Index:1 ^| find /i "Current Edition"') do set "CURRED=%%L"
echo %CURRED%
echo %CURRED% | find /i "%EDITION%" >nul || (
  echo ERROR: Edition verification failed. Expected %EDITION%.
  exit /b 1
)

echo Done.
exit /b 0

:fail
echo ERROR: DISM failed. See logs in %LOG%.
if exist "%MOUNT%" dism /English /Unmount-Image /MountDir:"%MOUNT%" /Discard >nul 2>nul
exit /b 1


