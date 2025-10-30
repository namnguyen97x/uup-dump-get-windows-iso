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

rem Allow workflow to override via environment
if defined BEDI_BUILD set "BUILD=%BEDI_BUILD%"
if defined BEDI_EDITION set "EDITION=%BEDI_EDITION%"
if defined BEDI_LANG set "LANG=%BEDI_LANG%"
set "BUILD_DIR=%ROOT%\%BUILD%"
set "SCR=%ROOT%\log_auto\scratch"

rem Lite options (align with Bedi.ini semantics)
set "_store=Without"
set "_defender=Without"
set "_msedge=Without"
set "_helospeech=Without"
set "_winre=Without"
set "_wifirtl=Without"

if not exist "%WIM%" (echo ERROR: %WIM% not found.& exit /b 1)
if not exist "%BUILD_DIR%" mkdir "%BUILD_DIR%" >nul 2>nul
set "EDITIONSPEC_ESD=%BUILD_DIR%\Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd"
set "CLIENTS_ESD=%BUILD_DIR%\clients.esd"

rem Resolve EditionSpecific ESD flexibly if missing
if not exist "%EDITIONSPEC_ESD%" (
  for /f "delims=" %%p in ('dir /b /a:-d "%BUILD_DIR%\*EditionSpecific*%EDITION%*Package*.esd" 2^>nul') do (
    set "EDITIONSPEC_ESD=%BUILD_DIR%\%%p"
    echo Found EditionSpecific ESD: %%p
  )
  if not exist "%EDITIONSPEC_ESD%" if exist "%BUILD_DIR%\Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd" (
    set "EDITIONSPEC_ESD=%BUILD_DIR%\Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd"
    echo Found EditionSpecific ESD (exact): Microsoft-Windows-EditionSpecific-%EDITION%-Package.esd
  )
)

if not exist "%EDITIONSPEC_ESD%" if not exist "%CLIENTS_ESD%" (
  echo ERROR: Missing EditionSpecific-%EDITION% ESD ^(or clients.esd containing it^) in "%BUILD_DIR%"
  echo DEBUG: Listing %BUILD_DIR%
  dir /b "%BUILD_DIR%"
  dir /b %BUILD_DIR%
  exit /b 1
)

set "LP_ESD=%BUILD_DIR%\Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd"
if not exist "%LP_ESD%" (
  for /f "delims=" %%p in ('dir /b /a:-d "%BUILD_DIR%\*Client-LanguagePack*amd64*en-us*.esd" 2^>nul') do (
    set "LP_ESD=%BUILD_DIR%\%%p"
    echo Found Language Pack ESD: %%p
  )
)
if not exist "%LP_ESD%" (
  echo ERROR: Missing en-US LP ESD in "%BUILD_DIR%" (e.g. Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd)
  echo DEBUG: Listing %BUILD_DIR%
  dir /b "%BUILD_DIR%"
  exit /b 1
)
if not exist "%LOG%" mkdir "%LOG%" >nul 2>nul
if not exist "%SCR%" mkdir "%SCR%" >nul 2>nul

set "SEVENZ=%ROOT%\Files\7z.exe"
set "TMPPAY=%ROOT%\_payload_%BUILD%"
if exist "%TMPPAY%" rmdir /s /q "%TMPPAY%"
mkdir "%TMPPAY%" >nul 2>nul
if exist "%SEVENZ%" (
  "%SEVENZ%" x -y -o"%TMPPAY%" "%LP_ESD%" >nul 2>nul
  if exist "%EDITIONSPEC_ESD%" (
    "%SEVENZ%" x -y -o"%TMPPAY%" "%EDITIONSPEC_ESD%" >nul 2>nul
  ) else (
    echo Extracting EditionSpecific from clients.esd...
    "%SEVENZ%" l "%CLIENTS_ESD%" | find /i "Microsoft-Windows-EditionSpecific-%EDITION%-Package" >nul || (
      echo ERROR: clients.esd does not contain EditionSpecific-%EDITION% package
      exit /b 1
    )
    "%SEVENZ%" x -y -o"%TMPPAY%" "%CLIENTS_ESD%" "*Microsoft-Windows-EditionSpecific-%EDITION%-Package*" >nul 2>nul
  )
) else (
  echo WARNING: 7z.exe not found. Trying to add ESD directly may fail.
)

rem Elevation check; prefer NSudo TrustedInstaller if available
set "NSUDO=%ROOT%\Files\NSudo.exe"
net session >nul 2>nul
if errorlevel 1 (
  if exist "%NSUDO%" (
    echo Relaunching with NSudo (TrustedInstaller)...
    "%NSUDO%" -U:T -P:E -UseCurrentConsole -Wait cmd /c "pushd "%ROOT%" && call "%~f0""
    set "RC=%ERRORLEVEL%"
    popd
    exit /b %RC%
  ) else (
    echo ERROR: This script requires Administrator privileges. Place NSudo.exe in Files or run elevated.
    exit /b 1
  )
)

if exist "%MOUNT%" rmdir /s /q "%MOUNT%"
mkdir "%MOUNT%" >nul 2>nul
echo Mounting image...
dism /English /ScratchDir:"%SCR%" /Mount-Image /ImageFile:"%WIM%" /Index:1 /MountDir:"%MOUNT%" /LogPath:"%LOG%\mount.log" || goto :fail

echo Setting edition to %EDITION% ...
dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Set-Edition:%EDITION% /ProductKey:%EDITION_KEY% /LogPath:"%LOG%\edition.log" >nul 2>nul

echo Adding language pack (en-US)...
for %%C in ("%TMPPAY%\*.cab") do (
  dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Add-Package /PackagePath:"%%~fC" /LogPath:"%LOG%\lp.log" >nul 2>nul
)
dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Set-AllIntl:%LANG% /LogPath:"%LOG%\intl.log" >nul 2>nul

if /i "%_msedge%"=="Without" (
  echo Removing Microsoft Edge (best-effort)...
  dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Remove-Edge /LogPath:"%LOG%\edge.log" >nul 2>nul
)

if /i "%_store%"=="Without" (
  echo Removing Store-related provisioned apps (best-effort)...
  for %%A in (
    "Microsoft.DesktopAppInstaller"
    "Microsoft.WindowsStore"
    "Microsoft.HEIFImageExtension"
    "Microsoft.HEVCVideoExtension"
    "Microsoft.VP9VideoExtensions"
    "Microsoft.WebMediaExtensions"
    "Microsoft.WebpImageExtension"
  ) do (
    dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Remove-ProvisionedAppxPackage /PackageName:%%~A /LogPath:"%LOG%\appx_%%~A.log" >nul 2>nul
  )
)

if /i "%_defender%"=="Without" (
  echo Disabling Defender features (best-effort)...
  dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Disable-Feature /FeatureName:Windows-Defender /Remove /LogPath:"%LOG%\def1.log" >nul 2>nul
  dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Disable-Feature /FeatureName:Windows-Defender-Default-Definitions /Remove /LogPath:"%LOG%\def2.log" >nul 2>nul
)

if /i "%_helospeech%"=="Without" (
  echo Removing Hello.Face and Speech capabilities (best-effort)...
  dism /English /Image:"%MOUNT%" /Get-Capabilities > "%LOG%\caps.txt" 2>&1
  for /f "tokens=1,* delims=:" %%i in ('findstr /i "Capability Identity" "%LOG%\caps.txt"') do (
    echo %%j | findstr /i "Hello.Face Speech" >nul && (
      for /f "tokens=* delims= " %%z in ("%%j") do dism /English /ScratchDir:"%SCR%" /Image:"%MOUNT%" /Remove-Capability /CapabilityName:%%z /LogPath:"%LOG%\cap_rm.log" >nul 2>nul
    )
  )
)

if /i "%_winre%"=="Without" (
  echo Removing Windows Recovery Image (winre.wim)...
  if exist "%MOUNT%\Windows\System32\Recovery\winre.wim" del /f /q "%MOUNT%\Windows\System32\Recovery\winre.wim" >nul 2>nul
)

echo Committing image...
dism /English /ScratchDir:"%SCR%" /Unmount-Image /MountDir:"%MOUNT%" /Commit /LogPath:"%LOG%\commit.log" || goto :fail

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
if exist "%MOUNT%" dism /English /ScratchDir:"%SCR%" /Unmount-Image /MountDir:"%MOUNT%" /Discard >nul 2>nul
exit /b 1


