:: must call from Bedi.cmd
@cls
@Echo Off
Set "_iw=install.wim"
If not exist %_iw% (Call :_Warn "%_iw% file not found")
@Setlocal EnableExtensions DisableDelayedExpansion
set "_drv=%~d0"
pushd "%ROOT%"
Chcp 437 >nul
set "_myver=Upmod v5.43"
Set "_Nol=1>Nul 2>Nul"
Echo:
start /b Powershell -nop -c "&{$w=(get-host).ui.rawui;$w.buffersize=@{width=256;height=1512};$w.windowsize=@{width=110;height=33};}"
for /d %%# in (log* mnt* sdir*) do (rmdir /s /q "%%#\")
set /a _ext=%RANDOM% * 400 / 32768 + 1
set "MT=%ROOT%\mnt%_ext%"
set "_scDir=%ROOT%\sdir%_ext%"
set "_log=%ROOT%\log%_ext%"
for /d %%# in (lcu*) do (set "_dlcu=%ROOT%\%%#")
if not defined _dlcu (set "_dlcu=%ROOT%\lcu%_ext%")
set "DISM=%ROOT%\DISM0\Dism.exe /English"
set "DismFmt=/LogLevel:2 /ScratchDir:%_scDir% /image:%MT%"
set "_psdism=-LogLevel 2 -Path '%mt%' -ScratchDirectory '%_scDir%'"
set "_Files=%ROOT%\Files"
set "_marks=%MT%\ProgramData\Bedi"
set "WLIB=%_Files%\wimlib-imagex.exe"
set "z7=%_Files%\7z.exe"
set "_exp=%_Files%\expand.exe"
set "nsudo=%_Files%\NSudo.exe -U:T -P:E -UseCurrentConsole -Wait"
set "pwshl=powershell -nologo -noni -nop -exec bypass -c"
set "_munfile=%_ext%.mun"
set "_vkey=QPM6N-7J2WJ-P88HH-P3YRH-YY74H"
call :_neutralizer
For /f "tokens=3 delims=: " %%# in ('%WLIB% info "%_iw%" 1 2^>Nul ^| Findstr /i /c:"Edition ID:"') do (Set "_eid=%%#")
echo IoTEnterpriseSEnterpriseG | find /i "%_eid%" %_Nol% || Call :_Warn "Only support EnterpriseG, EnterpriseS or IoTEnterpriseS image."
for /f "tokens=3-5 delims=~" %%a in ('%z7% l -ba "%_iw%" -r "windows\servicing\packages\Microsoft-Windows-Client-LanguagePack-Package~*.cat"') do (set "_arc=%%a"&set "_lang=%%b"&set "_version=%%~nc")
for /f "tokens=3-4 delims=." %%a in ('echo %_version%') do (set "_bld=%%a"& set "_spb=%%b")
For %%# in (%ROOT%\%_bld%\update\ssu*.esd) do (set "_ssu=%%#")
if not exist "%_ssu%" (Call :_Warn "SSU package not found.!")
For %%# in (%ROOT%\%_bld%\update\windows1*.esd) do (set "_lcu=%%#")
if not exist "%_lcu%" (Call :_Warn "LCU package not found.!")
for /f "tokens=3-5 delims=~" %%a in ('%z7% l -ba "%_lcu%" -r "Microsoft-Windows-Client-LanguagePack-Package~*.cat"') do (set "_carc=%%a"&set "_clang=%%b"&set "_cversion=%%~nc")
for /f "tokens=3-4 delims=." %%a in ('echo %_cversion%') do (set "_cbld=%%a"& set "_cspb=%%b")
if %_cbld% neq %_bld% (Call :_Warn "Wrong LCU package version.!")
mkdir %MT% %_log% %_scDir% %_Nol%
if %_bld% geq 25390 (call :_extraclcu)
%DISM% /logpath:%_log%\mounts.log /LogLevel:1 /ScratchDir:%_scDir% /Mount-Image /ImageFile:%_iw% /index:1 /MountDir:%MT% || Call :_Warn "Failed mounting image."
if exist "%_marks%\Bedi.ini" (
for /f "tokens=*" %%# in ('findstr /i "=" "%_marks%\Bedi.ini" 2^<Nul') do (set "%%#")
)
call :_%_msedge%msedge
call :_%_defender%defender
call :_%_store%store
if exist "%_dlcu%\update.mum" (set "_lcu=%_dlcu%\update.mum")
call :_set%_bld% %_Nol%
title Starting update SSU and LCU  -  #%_vbedi%
call :_Teet 2
if exist "%_ssu%" (
Echo - Update SSU, %_ssu%
%DISM% /Logpath:%_log%\ssu.log %DismFmt% /add-package:"%_ssu%" || Call :_Warn "Failed implement ssu pack."
Call :_Teet 2
)
if exist "%_lcu%" (
Echo - Update LCU, %_lcu%
%DISM% /Logpath:%_log%\lcu.log %DismFmt% /add-package:"%_lcu%" || Call :_Warn "Failed implement LCU pack."
call :_Teet 2
)
if %_bld% equ 25398 (if %_cspb% geq 1130 (
call :_manup%_bld% %_Nol%
copy /y "%_mumreq%.mum.bak" "%_mumreq%.mum" %_Nol%
copy /y "%_mumreq%.cat.bak" "%_mumreq%.cat" %_Nol%
Echo - ReUpdate LCU, %_lcu%
%DISM% /Logpath:%_log%\lcu.log %DismFmt% /add-package:"%_lcu%" || Call :_Warn "Failed re-implement LCU pack."
echo:
))
echo - Productkey %_vkey%
%DISM% /logpath:%_log%\vKey.log %DismFmt% /Set-productkey:%_vkey%
for /f "tokens=4 delims= " %%i in ('%DISM% /Logpath:%_log%\edition.log %DismFmt% /Get-Currentedition ^| Findstr /i /C:"Current Edition :"') do (set CURRENT=%%i)
echo:
echo  ------------------------------------------------------------
echo   Current Edition : %CURRENT%
echo  ------------------------------------------------------------
call :_Teet 2
:: detect cab packages
set "_updts=%ROOT%\%_bld%\update"
for /f %%# in ('dir /b /a-d "%_updts%\*.cab"') do (
%z7% l -ba "%_updts%\%%#" -r "*23h2enablement*.*"|find /i ".mum" %_Nol% && set "_ep=%_updts%\%%#"
%z7% l -ba "%_updts%\%%#" -r "msil_sentinel.v3.5client_*.*"|find /i ".manifest" %_Nol% && set "_fx35base=%_updts%\%%#"
%z7% l -ba "%_updts%\%%#" -r "amd64_wcf-m_sm_cfg_ins_exe_*.*"|find /i ".manifest" %_Nol% && set "_fx35cu=%_updts%\%%#"
%z7% l -ba "%_updts%\%%#" -r "amd64_netfx4-xpthemes_manifest_*.*"|find /i ".manifest" %_Nol% && set "_fx48base=%_updts%\%%#"
%z7% l -ba "%_updts%\%%#" -r "amd64_microsoft-windows-oobe-user_*.*"|find /i ".manifest" %_Nol% && set "_oobe=%_updts%\%%#"
%z7% l -ba "%_updts%\%%#" -r "package-defender*.*"|find /i ".xml" %_Nol% && set "_defend=%_updts%\%%#"
%z7% e -aoa "%_updts%\%%#" update.mum %_Nol%
Findstr /i "Package_for_DotNetRollup" update.mum %_Nol% && (set "_fx48cu=%_updts%\%%#")
Findstr /i "Package_for_SafeOSDU" update.mum %_Nol% && (set "_safeos=%_updts%\%%#")
del /f /q update.mum %_Nol%
)
:: Update enablement package
if defined _ep (
title Update Enablement Package  -  #%_vbedi%
echo - Update enablement package, %_ep%
mkdir "ep\" %_Nol% && %_exp% -f:* "%_ep%" "ep" %_Nol%
if exist "ep\update.mum" (
call :_modepws "%root%\ep" "EnterpriseEvalEdition" "EnterpriseSEdition"
)
call :_dismpack "ep" "/Add-Package /PackagePath:ep\update.mum"
if exist ep\ (rmdir /s /q ep\ %_Nol%)
)
:: Update oobe package
if defined _oobe (
title Update OOBE Package  -  #%_vbedi%
echo - Update oobe package, %_oobe%
mkdir "oobe" %_Nol% && %_exp% -f:* "%_oobe%" "oobe" %_Nol%
if exist "oobe\update.mum" (
call :_modepws "%root%\oobe" "EnterpriseEvalEdition" "EnterpriseSEdition"
)
call :_dismpack "oobe" "/Add-Package /PackagePath:oobe\update.mum"
if exist oobe\ (rmdir /s /q oobe\ %_Nol%)
)
:: Implement net framework481 base package
if defined _fx48base (
title Implement .Net Framework481 Base Package  -  #%_vbedi%
echo - Implement .Net Framework 48.1 Base, %_fx48base%
call :_dismpack "ndp48" "/add-package:"%_fx48base%""
)
:: Update net framework481 cu package
if defined _fx48cu (
title Update .Net Framework Package  -  #%_vbedi%
echo - Update .Net Framework, %_fx48cu%
call :_dismpack "ndp48cu" "/add-package:"%_fx48cu%""
)
:: Update defender platform and virus definitions
if defined _defend (
title Update Defender Platform and Definitions Package  -  #%_vbedi%
if /i %_defender% == With (call :_updefend)
)
:: Remove edge
if /i %_msedge% == Without (
if exist "%MT%\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
echo Removing edge browser and webview
call :_dismpack "edgebrw" "/Remove-Edge"
))
call :remFeatures
call :MountReg
%nsudo% Reg add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Component Based Servicing" /f /v "DisableRemovePayload" /t REG_DWORD /d "0" %_Nol%
%nsudo% Reg add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /f /v "DisableResetbase" /t REG_DWORD /d "0" %_Nol%
%nsudo% Reg add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /f /v "SupersededActions" /t REG_DWORD /d "3" %_Nol%
%nsudo% Reg add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\SideBySide\Configuration" /f /v "DisableComponentBackups" /t REG_DWORD /d "1" %_Nol%
call :UnMountReg
title Cleanup  -  #%_vbedi%
if %_bld% equ 25398 (if %_cspb% geq 1130 (
Echo - Restore health after manual updated packages
call :_dismpack "restheal" "/Cleanup-Image /restorehealth /source:%MT%\Windows\WinSxS"
))
Echo - Optimize ProvisionedAppxPackages
call :_dismpack "optappx" "/Optimize-ProvisionedAppxPackages"
Echo - StartComponentCleanup
call :_dismpack "cleanUp" "/Cleanup-Image /StartComponentCleanup"
Echo - Resetbase
call :_dismpack "resetbase" "/Cleanup-Image /StartComponentCleanup /Resetbase"
:: Implement netfx35
if defined _fx35base (
title Implement .Net Framework 3.5  -  #%_vbedi%
echo - Enable .Net Framework 3.5, %_fx35base%
if not exist "%MT%\Windows\Microsoft.NET\Framework\v2.0.50727\ngen.exe" (
if %_bld% geq 22621 (
if exist "%MT%\Windows\servicing\FodMetadata\" (%nsudo% cmd /c ren "%MT%\Windows\servicing\FodMetadata" "Food" %_Nol%)
if exist "%MT%\Windows\servicing\InboxFodMetadataCache\" (%nsudo% cmd /c rmdir /s /q "%MT%\Windows\servicing\InboxFodMetadataCache\" %_Nol%)
)
call :_dismpack "NetFx3" "/Add-Package:"%_fx35base%""
%DISM% /LogPath:%_log%\NetFx3.log %dismFmt% /Enable-Feature /FeatureName:NetFx3 /All /LimitAccess /Source:"%_fx35base%" %_Nol%
if exist "%MT%\Windows\servicing\Food\" (%nsudo% cmd /c ren "%mt%\Windows\servicing\Food" "FodMetadata" %_Nol%)
%DISM% /LogPath:%_log%\NetFx3.log %dismFmt% /get-capabilities %_Nol%
))
:: Update netfx35 cu
if defined _fx35cu (
if exist "%MT%\Windows\Microsoft.NET\Framework\v2.0.50727\ngen.exe" (
title Update .Net Framework 3.5  -  #%_vbedi%
echo - Update NetFx3 Package
mkdir fx3upd %_Nol% && %_exp% -f:* "%_fx35cu%" "fx3upd" %_Nol%
if exist "fx3upd\update.mum" (call :_modepws "%root%\fx3upd" "EnterpriseEvalEdition" "EnterpriseSEdition")
call :_dismpack "fx3upd" "/Add-Package /PackagePath:fx3upd\update.mum"
if exist fx3upd\ (rmdir /s /q fx3upd\ %_Nol%)
))
::Reimplement update
if defined _fx35base (
title Reinstall .Net Framework and LCU Packages  -  #%_vbedi%
echo - Reimplement .net framework and LCU packages
if defined _fx48cu (call :_dismpack "ndp48cu" "/add-package:"%_fx48cu%"")
call :_dismpack "lcu" "/add-package:"%_lcu%""
)
Call :clManual
::General tweaks
call :generaltweaks
::Update WinRE
if defined _safeos (call :updatewinre)
title Finishing with Optimizing %_iw%  -  #%_vbedi%
echo:
echo - Save and unmount %_iw%
%DISM% /logpath:%_log%\commit.log /LogLevel:3 /ScratchDir:%_scDir% /unmount-wim /mountdir:%MT% /commit
call :_Teet 2
echo - Image Optimizing
echo:
%WLIB% export "install.wim" 1 2.wim
call :_Teet 2
move /y 2.wim install.wim %_Nol%
del /f /q "*.mun" %_Nol%

:_End
echo FINISH..!!
<nul (set/p _bel=)
pause
(Goto) 2>Nul & Call "cleanup.cmd"
exit

:_Warn
Echo:
Echo:
Echo ==*^|ERROR:  %~1  ^|*==
Goto :_End

:_Teet
Echo:
ping 127.0.0.1 -n %* >Nul
Echo:
Exit /b

:MountReg
Set "mtrPath=%MT%\Windows\System32\config"
Set "mtUPath=%MT%\Users\Default"
if exist "%mtUPath%\NTUSER.DAT" Reg load HKLM\mtUSER "%mtUPath%\NTUSER.DAT" %_Nol%
if exist "%mtrPath%\SOFTWARE" Reg load HKLM\mtSOFT "%mtrPath%\SOFTWARE" %_Nol%
if exist "%mtrPath%\SYSTEM" Reg load HKLM\mtSYS "%mtrPath%\SYSTEM" %_Nol%
ping 127.0.0.1 -n 2 >Nul
Exit /b

:UnMountReg
Reg unload HKLM\mtUSER %_Nol%
Reg unload HKLM\mtSOFT %_Nol%
Reg unload HKLM\mtSYS %_Nol%
ping 127.0.0.1 -n 2 >Nul
Exit /b

:_dismpack
%DISM% /Logpath:%_log%\%~1.log %DismFmt% %~2
call :_Teet 2
exit /b

:_modepws
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]ps_XML')[1];ModSsu '%~1' '%~2' '%~3'"
exit /b

[22000 LTSC Keys]
:: EnterpriseS KEY=OEM_NONSLP, 43TBQ-NH92J-XKTM7-KT3KK-P39PB
:: IoTEnterpriseS KEY=OEM_NONSLP, QPM6N-7J2WJ-P88HH-P3YRH-YY74H

[22621 LTSC Keys]
:: EnterpriseS KEY=Volume_GVLK, M7XTQ-FN8P6-TTKYV-9D4CC-J462D
:: IoTEnterpriseS KEY=OEM_NONSLP, QPM6N-7J2WJ-P88HH-P3YRH-YY74H

[26100 LTSC Keys]
:EnterpriseS
set "KEY=M7XTQ-FN8P6-TTKYV-9D4CC-J462D"
set "KEYTYPE=Volume_GVLK"

:IoTEnterpriseS
if /i %KEYTYPE%==Volume_GVLK (set "KEY=KBN8V-HFGQ4-MGXVD-347P6-PDQGT")
if /i %KEYTYPE%==OEM_NONSLP (set "KEY=CGK42-GYN6Y-VD22B-BX98W-J8JXD")

:IoTEnterpriseSK
set "KEY=N979K-XWD77-YW3GB-HBGH6-D32MH"
set "KEYTYPE=OEM_DM"

:ps_XML
Function ModSsu([String] $fldr, [String] $sourc, [String] $targt) {
  Get-ChildItem $fldr -Filter *.mum | ForEach-Object {
    if ($_ | Select-String -Pattern $sourc) {
      ($_ | Get-Content -Raw) -replace $sourc, $targt | Set-Content $_.FullName
    }
  }
  Remove-Variable * -EA SilentlyContinue
}
#:ps_XML
::=========================================================================

:clManual
if exist "%MT%\Windows\WinSxS\ManifestCache\*.bin" (
takeown /f "%MT%\Windows\WinSxS\ManifestCache\*.bin" /A %_Nol%
icacls "%MT%\Windows\WinSxS\ManifestCache\*.bin" /grant *S-1-5-32-544:F %_Nol%
del /f /q "%MT%\Windows\WinSxS\ManifestCache\*.bin" %_Nol%
)
if exist "%MT%\Windows\WinSxS\Temp\PendingDeletes\*" (
takeown /f "%MT%\Windows\WinSxS\Temp\PendingDeletes\*" /A %_Nol%
icacls "%MT%\Windows\WinSxS\Temp\PendingDeletes\*" /grant *S-1-5-32-544:F %_Nol%
del /f /q "%MT%\Windows\WinSxS\Temp\PendingDeletes\*" %_Nol%
)
if exist "%MT%\Windows\WinSxS\Temp\TransformerRollbackData\*" (
takeown /f "%MT%\Windows\WinSxS\Temp\TransformerRollbackData\*" /R /A %_Nol%
icacls "%MT%\Windows\WinSxS\Temp\TransformerRollbackData\*" /grant *S-1-5-32-544:F /T %_Nol%
del /s /f /q "%MT%\Windows\WinSxS\Temp\TransformerRollbackData\*" %_Nol%
)
if exist "%MT%\Windows\inf\*.log" (
del /f /q "%MT%\Windows\inf\*.log" %_Nol%
)
for /f "tokens=* delims=" %%# in ('dir /b /ad "%MT%\Windows\CbsTemp\" 2^>nul') do rmdir /s /q "%MT%\Windows\CbsTemp\%%#\" %_Nol%
del /s /f /q "%MT%\Windows\CbsTemp\*" %_Nol%
for /f "tokens=* delims=" %%# in ('dir /b /ad "%MT%\Windows\Temp\" 2^>nul') do rmdir /s /q "%MT%\Windows\Temp\%%#\" %_Nol%
del /s /f /q "%MT%\Windows\Temp\*" %_Nol%
If exist "%MT%\Windows\servicing\LCU\" (
takeown /f "%MT%\Windows\servicing\LCU" /A %_Nol%
icacls "%MT%\Windows\servicing\LCU" /grant:r "*S-1-5-32-544:(OI)(CI)(F)" %_Nol%
rmdir /s /q "%MT%\Windows\servicing\LCU\" %_Nol%
)
if exist "%MT%\Windows\WinSxS\pending.xml" Exit /b
for /f "tokens=* delims=" %%# in ('dir /b /ad "%MT%\Windows\WinSxS\Temp\InFlight\" 2^>nul') do (
takeown /f "%MT%\Windows\WinSxS\Temp\InFlight\%%#" /A %_Nol%
icacls "%MT%\Windows\WinSxS\Temp\InFlight\%%#" /grant:r "*S-1-5-32-544:(OI)(CI)(F)" %_Nol%
rmdir /s /q "%MT%\Windows\WinSxS\Temp\InFlight\%%#\" %_Nol%
)
if exist "%MT%\Windows\WinSxS\Temp\PendingRenames\*" (
takeown /f "%MT%\Windows\WinSxS\Temp\PendingRenames\*" /A %_Nol%
icacls "%MT%\Windows\WinSxS\Temp\PendingRenames\*" /grant *S-1-5-32-544:F %_Nol%
del /f /q "%MT%\Windows\WinSxS\Temp\PendingRenames\*" %_Nol%
)
Exit /b

::Parameter: Limiter, Path, Encoding
:_export
Set "_trm=%~4"
If defined _trm (
set "0=%~f0"& powershell -nop -c "$f=[IO.File]::ReadAllText($env:0) -split '%~1'; [IO.File]::WriteAllText('%~2',$f[1].Trim(),[System.Text.Encoding]::%~3)"
) else (
set "0=%~f0"& powershell -nop -c "$f=[IO.File]::ReadAllText($env:0) -split '%~1'; [IO.File]::WriteAllText('%~2',$f[1].TrimStart(),[System.Text.Encoding]::%~3)"
)
Exit /b

rem Credits for abbodi1406 at MDL
:_updefend
if not exist "%MT%\Program Files\Windows Defender\MsMpEng.exe" (exit /b)
echo - Update Windows Defender, %_defend%
echo:
set "_mwd=%MT%\ProgramData\Microsoft\Windows Defender"
mkdir defend %_Nol% && %_exp% -f:* "%_defend%" "defend" %_Nol%
if exist "defend\*defender*.xml" for /f %%i in ('dir /b /a:-d "defend\*defender*.xml"') do (
for /f "tokens=3 delims=<> " %%# in ('type "defend\%%i" ^| find /i "platform"') do echo Platform  : %%#
for /f "tokens=3 delims=<> " %%# in ('type "defend\%%i" ^| find /i "engine"') do echo Engine    : %%#
for /f "tokens=3 delims=<> " %%# in ('type "defend\%%i" ^| find /i "signatures"') do echo Signatures: %%#
)
xcopy /CIRY "defend\Definition Updates\Updates" "%_mwd%\Definition Updates\Updates\" %_Nol%
if exist "%_mwd%\Definition Updates\Updates\MpSigStub.exe" del /f /q "%_mwd%\Definition Updates\Updates\MpSigStub.exe" %_Nol%
xcopy /ECIRY "defend\Platform" "%_mwd%\Platform\" %_Nol%
for /f %%# in ('dir /b /ad "defend\Platform\*.*.*.*"') do set "_wdplat=%%#"
if exist "%_mwd%\Platform\%_wdplat%\MpSigStub.exe" del /f /q "%_mwd%\Platform\%_wdplat%\MpSigStub.exe" %_Nol%
if not exist "defend\Platform\%_wdplat%\ConfigSecurityPolicy.exe" copy /y "%MT%\Program Files\Windows Defender\ConfigSecurityPolicy.exe" "%_mwd%\Platform\%_wdplat%\" %_Nol%
if not exist "defend\Platform\%_wdplat%\MpAsDesc.dll" copy /y "%MT%\Program Files\Windows Defender\MpAsDesc.dll" "%_mwd%\Platform\%_wdplat%\" %_Nol%
if not exist "defend\Platform\%_wdplat%\MpEvMsg.dll" copy /y "%MT%\Program Files\Windows Defender\MpEvMsg.dll" "%_mwd%\Platform\%_wdplat%\" %_Nol%
if not exist "defend\Platform\%_wdplat%\ProtectionManagement.dll" copy /y "%MT%\Program Files\Windows Defender\ProtectionManagement.dll" "%_mwd%\Platform\%_wdplat%\" %_Nol%
if not exist "defend\Platform\%_wdplat%\MpUxAgent.dll" copy /y "%MT%\Program Files\Windows Defender\MpUxAgent.dll" "%_mwd%\Platform\%_wdplat%\" %_Nol%
for /f %%A in ('dir /b /ad "%MT%\Program Files\Windows Defender\*-*"') do (
if not exist "%_mwd%\Platform\%_wdplat%\%%A\" mkdir "%_mwd%\Platform\%_wdplat%\%%A" %_Nol%
if not exist "defend\Platform\%_wdplat%\%%A\MpAsDesc.dll.mui" copy /y "%MT%\Program Files\Windows Defender\%%A\MpAsDesc.dll.mui" "%_mwd%\Platform\%_wdplat%\%%A\" %_Nol%
if not exist "defend\Platform\%_wdplat%\%%A\MpEvMsg.dll.mui" copy /y "%MT%\Program Files\Windows Defender\%%A\MpEvMsg.dll.mui" "%_mwd%\Platform\%_wdplat%\%%A\" %_Nol%
if not exist "defend\Platform\%_wdplat%\%%A\ProtectionManagement.dll.mui" copy /y "%MT%\Program Files\Windows Defender\%%A\ProtectionManagement.dll.mui" "%_mwd%\Platform\%_wdplat%\%%A\" %_Nol%
if not exist "defend\Platform\%_wdplat%\%%A\MpUxAgent.dll.mui" copy /y "%MT%\Program Files\Windows Defender\%%A\MpUxAgent.dll.mui" "%_mwd%\Platform\%_wdplat%\%%A\" %_Nol%
)
if not exist "defend\Platform\%_wdplat%\x86\MpAsDesc.dll" copy /y "%MT%\Program Files (x86)\Windows Defender\MpAsDesc.dll" "%_mwd%\Platform\%_wdplat%\x86\" %_Nol%
for /f %%A in ('dir /b /ad "%MT%\Program Files (x86)\Windows Defender\*-*"') do (
if not exist "%_mwd%\Platform\%_wdplat%\x86\%%A\" mkdir "%_mwd%\Platform\%_wdplat%\x86\%%A" %_Nol%
if not exist "defend\Platform\%_wdplat%\x86\%%A\MpAsDesc.dll.mui" copy /y "%MT%\Program Files (x86)\Windows Defender\%%A\MpAsDesc.dll.mui" "%_mwd%\Platform\%_wdplat%\x86\%%A\" %_Nol%
)
if exist "defend\" (rmdir /s /q "defend\" %_Nol% && echo Done.)
call :_Teet 2
exit /b

:rempack_XML
Function DelNudes([String] $xmlFile, [String] $Rempackname) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$updates = $xml.assembly.package.update
	foreach($packname in $Rempackname.Split("|")) {
	  $updates | Where {$_.package.assemblyIdentity.name.contains($packname)} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	}
	$xml.Save("$xmlFile")
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:rempack_XML
::=========================================================================

:repcompack_XML
Function DelNudes([String] $xmlFile, [String] $Rempackname) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$updates = $xml.assembly.package.update
    $updates | Where {$_.component.assemblyIdentity.name.contains($Rempackname)} | Foreach-Object {$_.name = "3A85776914ECCD84253163D62474F25B20F3E924A0D2B6760BA0FFD3B44E97D8"; `
	  $_.component.assemblyIdentity.version = "10.0.25398.1"}
	$xml.Save("$xmlFile")
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:repcompack_XML
::=========================================================================

:_extraclcu
if not exist "%_dlcu%\update.mum" (
call :_Teet 2
echo Need to extract %_lcu%, please wait...
%z7% x "%_lcu%" -o"%_dlcu%" -y %_Nol%
)
exit /b

:_withoutmsedge
if %_bld% geq 26000 (exit /b)
call :_extraclcu
call :_msedge%_bld:~0,3%
exit /b

:_msedge220
call :_xmlmumrem "Microsoft-Windows-Desktop-Required-ClientOnly-Removable-Package" "MicrosoftEdgeDevToolsClient" %_Nol%
exit /b

:_msedge226
call :_xmlmumrem "Microsoft-Windows-EditionSpecific-EnterpriseS-Package" "Windows-Internet-Browser" %_Nol%
exit /b

:_msedge253
call :_msedge226
exit /b

:_withmsedge
rem just empty dummy function
exit /b

:_xmlmumrem
For %%# in (%_dlcu%\%~1*~~*.mum) do (set "_mumfile=%%#")
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]rempack_XML')[1];DelNudes '%_mumfile%' '%~2'"
exit /b

:_xmlmumculrem
For %%# in (%_dlcu%\%~1*~%~3~*.mum) do (set "_mumfile=%%#")
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]rempack_XML')[1];DelNudes '%_mumfile%' '%~2'"
exit /b

:_withoutdefender
if %_bld% geq 26000 (exit /b)
call :_extraclcu
call :_defend%_bld:~0,3%
exit /b

:_defend220
call :_xmlmumrem "Microsoft-Windows-EditionSpecific-EnterpriseS-Package" "Windows-SenseClient"
call :_xmlmumrem "Microsoft-Windows-Client-Desktop-Required-Package01" "AM-Default-Definitions" %_Nol%
call :_xmlmumrem "Microsoft-Windows-Desktop-Shared-Package" "Dynamic-Image"
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-Package" "Defender-ApplicationGuard-Inbox"
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-WOW64-Package" "Defender-ApplicationGuard-Inbox"
exit /b

:_defend226
call :_xmlmumrem "Microsoft-Windows-EditionSpecific-EnterpriseS-Package" "Windows-SenseClient"
call :_xmlmumrem "Microsoft-Windows-Client-Desktop-Required-Package03" "Defender-AM-Default-Definitions" %_Nol%
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-Package" "Defender-ApplicationGuard-Inbox"
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-WOW64-Package" "Defender-ApplicationGuard-Inbox"
exit /b

:_defend253
call :_xmlmumrem "Microsoft-Windows-EditionSpecific-EnterpriseS-Package" "Windows-SenseClient"
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-Package" "Defender-ApplicationGuard-Inbox"
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-WOW64-Package" "Defender-ApplicationGuard-Inbox"
exit /b

:_withdefender
rem  just empty dummy function
exit /b

:remFeatures
if /i %_defender% == Without (set "_sFeat=Defender|Platform|BitLocker")
if not defined _sFeat (exit /b)
title Remove Feature Packages  -  #%_vbedi%
echo Keep clean from windows defender
echo:
set "_flist=%_log%\feat-%_ext%.lst"
>%_flist% (%pwshl% "(Get-WindowsOptionalFeature -LogPath '%_log%\feats.log' %_psdism%|?{($_.FeatureName -Match '%_sFeat%')}).FeatureName")
for /f "tokens=*" %%# in ('findstr /i . %_flist%') do (
  <nul (set/p _msg=- %%#...)
  %dism% /Quiet /LogPath:%_log%\feats.log %dismfmt% /Disable-Feature /FeatureName:%%# /Remove %_nol% && Echo  REMOVED. || Echo  FAILED!
)
echo ------------------------------------------------------------
call :_Teet 2
exit /b

:_neutralizer
set "_store=With"
set "_defender=With"
set "_msedge=With"
set "_helospeech=With"
set "_winre=With"
set "_wifirtl=With"
exit /b

:_set25398
call :%_bld%_%_eid%
call :_neutralizer
if %_cspb% geq 1130 (
call :_detailreq
)
exit /b

:25398_IoTEnterpriseS
set "_vkey=KBN8V-HFGQ4-MGXVD-347P6-PDQGT"
exit /b

:25398_EnterpriseG
Set "_vKey=YYVX9-NTFWV-6MDM3-9PT4T-4M68B"
Set "_virEd=EnterpriseG"
exit /b

:_detailreq
for %%# in (%_dlcu%\Microsoft-Windows-Client-Desktop-Required-Package~*~en-us~*.mum) do (set "_mumreq=%%~dpn#")
copy /y "%_mumreq%.mum" "%_mumreq%.mum.bak"
copy /y "%_mumreq%.cat" "%_mumreq%.cat.bak"
copy /y "%ROOT%\%_bld%\%_bld%.tac" "%_mumreq%.cat"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]repcompack_XML')[1];DelNudes '%_mumreq%.mum' 'client-desktop-required'"
exit /b

:_manup25398
if not exist "%ROOT%\%_bld%\manupd.esd" (exit /b)
%nsudo% %z7% x "%ROOT%\%_bld%\manupd.esd" -o"%MT%" -y %_Nol%
if exist "%MT%\register.cmd" (
call :_mountcomp
%nsudo% cmd /c call "%MT%\register.cmd"
call :_unmountcomp
del /f /q "%MT%\register.cmd"
)
exit /b

:_dismrepack
echo:
Echo - Update %~1
%DISM% /Logpath:%_log%\%~2.log /LogLevel:2 /ScratchDir:%_scDir% /image:re %~3 || echo Error updating %~1 for WinRE &exit /b
Call :_Teet 2
exit /b

:updatewinre
title Updating WinRE  -  #%_vbedi%
set "_winre=%MT%\windows\system32\recovery\winre.wim"
if not exist "%_winre%" (exit /b)
attrib -s -h -i "%_winre%" %_Nol%
move /y %_winre% . %_Nol% && mkdir re %_Nol%
echo:
echo - Updating WinRE
%DISM% /logpath:%_log%\winre.log /LogLevel:1 /ScratchDir:%_scDir% /Mount-Image /ImageFile:winre.wim /index:1 /MountDir:re
call :_dismrepack "SSU, %_ssu%" "ssure" "/add-package:"%_ssu%""
call :_dismrepack "SafeOS, %_safeos%" "safeos" "/add-package:"%_safeos%""
call :_dismrepack "LCU, %_lcu%" "lcure" "/add-package:"%_lcu%""
call :_dismrepack "StartComponentCleanup" "cleanre" "/Cleanup-Image /StartComponentCleanup"
call :_dismrepack "Resetbase" "resetre" "/Cleanup-Image /StartComponentCleanup /Resetbase"
echo:
echo - Save and unmount WinRE
%DISM% /logpath:%_log%\commitre.log /LogLevel:1 /ScratchDir:%_scDir% /unmount-wim /mountdir:re /commit
call :_Teet 2
echo - Image Optimizing WinRE
echo:
%WLIB% export "winre.wim" 1 "%_winre%" && del /f /q "winre.wim" %_Nol%
call :_Teet 2
rmdir /s /q re %_Nol%
echo FINISH updating WinRE
exit /b

:_disvbs
if %_bld% geq 21000 (if /i %_defender% == Without (
call :_disbitlocker
%nsudo% reg.exe add "HKLM\mtSYS\ControlSet001\Control\DeviceGuard" /f /v "EnableVirtualizationBasedSecurity" /t REG_DWORD /d "0" %_Nol%
%nsudo% reg.exe add "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /f /v "Enabled" /t REG_DWORD /d "0" %_Nol%
%nsudo% reg.exe delete "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /f /v "ChangedInBootCycle" %_Nol%
%nsudo% reg.exe delete "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity" /f /v "WasEnabledBy" %_Nol%
%nsudo% reg.exe add "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\KernelShadowStacks" /f /v "Enabled" /t REG_DWORD /d "0" %_Nol%
%nsudo% reg.exe add "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\WindowsHello" /f /v "Enabled" /t REG_DWORD /d "0" %_Nol%
%nsudo% reg.exe delete "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\KernelShadowStacks" /f /v "ChangedInBootCycle" %_Nol%
%nsudo% reg.exe delete "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\KernelShadowStacks" /f /v "WasEnabledBy" %_Nol%
%nsudo% reg.exe add "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\CredentialGuard" /f /v "Enabled" /t REG_DWORD /d "0" %_Nol%
%nsudo% reg.exe delete "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\CredentialGuard" /f /v "ChangedInBootCycle" %_Nol%
%nsudo% reg.exe delete "HKLM\mtSYS\ControlSet001\Control\DeviceGuard\Scenarios\CredentialGuard" /f /v "WasEnabledBy" %_Nol%
%nsudo% reg.exe add "HKLM\mtSYS\ControlSet001\Control\Lsa" /f /v "RunAsPPL" /t REG_DWORD /d "0" %_Nol%
))
exit /b

:_mountcomp
reg.exe query HKLM\mtSOFT %_Nol% || reg.exe load HKLM\mtSOFT "%MT%\Windows\System32\Config\SOFTWARE" %_Nol%
reg.exe query HKLM\mtCOMP %_Nol% || reg.exe load HKLM\mtCOMP "%MT%\Windows\System32\Config\COMPONENTS" %_Nol%
exit /b

:_unmountcomp
reg.exe unload HKLM\mtSOFT %_Nol%
reg.exe unload HKLM\mtCOMP %_Nol%
exit /b

Rem -------------------------------------------------------------------------------------------
Rem  Remove Library folder from ThisPC
Rem -------------------------------------------------------------------------------------------
:remLibraryFolder
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{2B20DF75-1EDA-4039-8097-38798227D5B7}" /f %_Nol%
::pictures
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
::videos
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
::Downloads
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
::Music
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
::Documents
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{f42ee2d3-909f-4907-8871-4c22fc0bf756}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
::Desktop
rem reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{3dfdf296-dbec-4fb4-81d1-6a3438bcf4de}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{088e3905-0323-4b02-9826-5d99428e115f}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{24ad3ad4-a569-4530-98e1-ab02f9417aa8}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{f86fa3ab-70d2-4fc7-9c99-fcbf05467f3a}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{d3162b92-9365-467a-956b-92703aca08af}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{2B20DF75-1EDA-4039-8097-38798227D5B7}" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\WOW6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}" /f %_Nol%
reg.exe add "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{0ddd015d-b06c-45d5-8c4c-f59713854639}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
reg.exe add "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{35286a68-3c57-41a1-bbb1-0eae73d76c95}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
reg.exe add "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{7d83ee9b-2244-4e70-b1f5-5393042af1e4}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
reg.exe add "HKLM\mtSOFT\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\FolderDescriptions\{a0c69a99-21c8-4671-8703-7934162fcf1d}\PropertyBag" /f /v "ThisPCPolicy" /t REG_SZ /d "Hide" %_Nol%
REM Remove Desktop folder from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{B4BFCC3A-DB2C-424C-B029-7FE99A87C641}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Documents folder from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{A8CDFF1C-4878-43be-B5FD-F8091C1C60D0}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Downloads folder from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{374DE290-123F-4565-9164-39C4925E467B}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{374DE290-123F-4565-9164-39C4925E467B}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Libraries from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{031E4825-7B94-4dc3-B131-E946B44C8DD5}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{031E4825-7B94-4dc3-B131-E946B44C8DD5}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Music folder from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{1CF1260C-4DD0-4ebb-811F-33C572699FDE}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Pictures folder from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{3ADD1653-EB32-4cb0-BBD7-DFA0ABB5ACCA}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Videos folder from "Show all folders"
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Policies\NonEnum" /f /v "{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{A0953C92-50DC-43bf-BE83-3742FED03C9C}" /f /v "HiddenByDefault" /t REG_DWORD /d "1" %_Nol%
REM Remove Gallery folder from "Show all folders"
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{e88865ea-0e1c-4e20-9aa6-edcd0212c87c}" /f %_Nol%
REM Remove Home folder from "Show all folders"
reg.exe delete "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop\NameSpace\{f874310e-b6b7-47dc-bc84-b9e6b38f5903}" /f %_Nol%
Rem Remove double dektop name space
for /f "delims=" %%# in ('reg.exe query "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Desktop" /k /f "NameSpace*" 2^>Nul ^| find "_"') do (reg.exe delete "%%#" /f %_Nol%)
exit /b

:generaltweaks
call :MountReg
%nsudo% reg.exe import "%_Files%\tweaks\gen_tweaks.reg" %_Nol%
call :_disvbs
call :remLibraryFolder
rem Disable CBS.log
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Component Based Servicing" /f /v "EnableLog" /t REG_DWORD /d "0" %_Nol%
rem Disable windows reserved storage
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\ReserveManager" /f /v "ShippedWithReserves" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\ReserveManager" /f /v "PassedPolicy" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\ReserveManager" /f /v "MiscPolicyInfo" /t REG_DWORD /d "2" %_Nol%
rem Disable USB AutoSuspend for Balanced and High Performance power schemes
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /f /v "ACSettingIndex" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /f /v "DCSettingIndex" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /f /v "ACSettingIndex" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\2a737441-1930-4402-8d77-b2bebba308a3\48e6b7a6-50f5-4782-a5d4-53bb8f07e226" /f /v "DCSettingIndex" /t REG_DWORD /d "0" %_Nol%
rem Disable idle Hard Disk auto power off for Balanced and High Performance power schemes
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /f /v "ACSettingIndex" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\381b4222-f694-41f0-9685-ff5bb260df2e\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /f /v "DCSettingIndex" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /f /v "ACSettingIndex" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\Power\User\PowerSchemes\8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c\0012ee47-9041-4b5d-9b77-535fba8b1442\6738e2c4-e8a5-4a42-b16a-e040e769756e" /f /v "DCSettingIndex" /t REG_DWORD /d "0" %_Nol%
rem Enable title bars and windows border colour
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\DWM" /f /v "ColorPrevalence" /t REG_DOWRD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\DWM" /f /v "ColorPrevalence" /t REG_DOWRD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "ColorPrevalence" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "EnableBlurBehind" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "ColorPrevalence" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "EnableBlurBehind" /t REG_DWORD /d "0" %_Nol%
rem Dark mode for System and App
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "AppsUseLightTheme" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "SystemUsesLightTheme" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "AppsUseLightTheme" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize" /f /v "SystemUsesLightTheme" /t REG_DWORD /d "0" %_Nol%
rem Windows Console Host
reg.exe add "HKLM\mtUSER\Console\%%Startup" /f /v "DelegationConsole" /t REG_SZ /d "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}" %_Nol%
reg.exe add "HKLM\mtUSER\Console\%%Startup" /f /v "DelegationTerminal" /t REG_SZ /d "{B23D10C0-E52E-411E-9D5B-C09FDF709C7D}" %_Nol%
rem For NEW Console host as default, add this additional key (For LEGACY set the value from 1 to 0)
reg.exe add "HKLM\mtUSER\Console" /v "ForceV2" /t REG_DWORD /d "1" /f %_Nol%
rem Remove autologger telemetry
reg.exe delete "HKLM\mtSYS\ControlSet001\Control\WMI\Autologger\CloudExperienceHostOobe" /f %_Nol%
reg.exe delete "HKLM\mtSYS\ControlSet001\Control\WMI\Autologger\Diagtrack-Listener" /f %_Nol%
reg.exe delete "HKLM\mtSYS\ControlSet001\Control\WMI\Autologger\SQMLogger" /f %_Nol%
reg.exe delete "HKLM\mtSYS\ControlSet001\Control\WMI\Autologger\WFP-IPsec Trace" /f %_Nol%
rem Performance system
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "DisableDeleteNotification" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "Win31FileSystem" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "Win95TruncatedExtensions" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "LongPathsEnabled" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsDisableLastAccessUpdate" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsDisableSpotCorruptionHandling" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsDisableEncryption" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsDisable8dot3NameCreation" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsBugcheckOnCorrupt" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsMemoryUsage" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "NtfsMftZoneReservation" /t REG_DWORD /d "4" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\FileSystem" /f /v "RefsDisableLastAccessUpdate" /t REG_DWORD /d "1" %_Nol%
Rem About keyboard keystroke
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "AutoRepeatDelay" /t REG_SZ /d "200" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "AutoRepeatRate" /t REG_SZ /d "10" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "BounceTime" /t REG_SZ /d "5" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "DelayBeforeAcceptance" /t REG_SZ /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "Last BounceKey Setting" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "Last Valid Delay" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "Last Valid Repeat" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Control Panel\Accessibility\Keyboard Response" /f /v "Last Valid Wait" /t REG_DWORD /d "0" %_Nol%
Rem Combine when taskbar is full
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarGlomming" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "MMTaskbarGlomLevel" /t REG_DWORD /d "1" %_Nol%
REM Disable video thumbnails in Explorer (speeds up work and allows you to move and delete files)
reg.exe delete "HKLM\mtSOFT\Classes\.avi\ShellEx" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Classes\.mpg\ShellEx" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Classes\.mpe\ShellEx" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Classes\.mpeg\ShellEx" /f %_Nol%
reg.exe delete "HKLM\mtSOFT\Classes\.mp4\ShellEx" /f %_Nol%
REM Combine when taskbar is full.
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarGlomming" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarGlomLevel" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "MMTaskbarGlomLevel" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "MMTaskbarEnabled" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarGlomming" /t REG_DWORD /d "0" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarGlomLevel" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "MMTaskbarGlomLevel" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "MMTaskbarEnabled" /t REG_DWORD /d "1" %_Nol%
Rem Enable End Task With Right Click
reg.exe add "HKLM\mtUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarDeveloperSettings" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtUSER\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarEndTask" /t REG_DWORD /d "1" %_Nol%
rem Taskbar Alignment, 0=Left 1=Centre
reg.exe add "HKLM\mtUSER\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced" /f /v "TaskbarAl" /t REG_DWORD /d "0" %_Nol%
call :UnMountReg
exit /b

:_disbitlocker
rem Disable services; BDESVC, EFS -------------------------------------------
reg.exe add "HKLM\mtSOFT\Policies\Microsoft\Windows\EnhancedStorageDevices" /f /v "PreventDeviceEncryption" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSOFT\Policies\Microsoft\Windows\EnhancedStorageDevices" /f /v "TCGSecurityActivationDisabled" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Control\BitLocker" /f /v "PreventDeviceEncryption" /t REG_DWORD /d "1" /f %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Services\BDESVC" /f /v "Start" /t REG_DWORD /d "4" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Policies" /f /v "NtfsDisableEncryption" /t REG_DWORD /d "1" %_Nol%
reg.exe add "HKLM\mtSYS\ControlSet001\Services\EFS" /v "Start" /t REG_DWORD /d "4" /f %_Nol%
exit /b

:_withoutstore
call :_extraclcu
call :_store%_bld:~0,3% %_Nol%
exit /b

:_withstore
rem  just empty dummy function
exit /b

:_store226
call :_xmlmumrem "Microsoft-Windows-Desktop-Required-SharedWithServer-removable-Package" "UserExperience-LKG-Package" %_Nol%
exit /b

