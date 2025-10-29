@MODE CON:cols=110 lines=33
@Echo Off
Set "_drv=%~d0"
Set "ROOT=%~dp0"
If "%ROOT:~-1%"=="\" Set "ROOT=%ROOT:~0,-1%"
Pushd "%ROOT%"
Chcp 437 >nul
set "_iw=install.wim"
if not exist %_iw% (call :_Warn "There is no %_iw% in the directory")
::# self-elevate passing args and preventing loop by AveYo
set "args="%~f0" %*" & call set "args=%%args:"=\""%%"
reg query HKU\S-1-5-19>nul 2>nul||(if "%?%" neq "y" powershell -c "start cmd -ArgumentList '/c set ?=y&call %args%' -verb runas" &exit)
::# End self-elevate passing
@Setlocal EnableExtensions DisableDelayedExpansion
rem start /b Powershell -nop -c "&{$w=(get-host).ui.rawui;$w.buffersize=@{width=256;height=1512};$w.windowsize=@{width=110;height=33};}"
start /b Powershell -nop -c "&{$w=(get-host).ui.rawui;$w.buffersize=@{width=256;height=1512};}"
set "_vbedi=Bedi v7.44"
Set "_Nol=1>Nul 2>Nul"
Echo:
::# lean xp+ color macros by AveYo:  %<%:af " hello "%>>% & %<%:cf " w\"or\"ld "%>%   for single \ / " use .%|%\  .%|%/  \"%|%\"
for /f "delims=:" %%s in ('echo;prompt $h$s$h:^|cmd /d') do set "|=%%s"&set ">>=\..\c nul&set /p s=%%s%%s%%s%%s%%s%%s%%s<nul&popd"
set "<=pushd "%public%"&2>nul findstr /c:\ /a" &set ">=%>>%&echo;" &set "|=%|:~0,1%" &set /p s=\<nul>%_Nol%
::# End lean xp+ color macros
call :_neutralizer
%<%:cf " Prepare "%>>% & %<%:2f " Starting up... "%>>% & %<%:1f " Please wait "%>%
set "_Files=%ROOT%\Files"
for %%# in (wimlib-imagex.exe 7z.exe NSudo.exe expand.exe expand_new.exe 7z.dll libwim-15.dll ModLCU.cmd msdelta.dll PSFExtractor.exe upmod.cmd) do (
if not exist "%_Files%\%%#" (Call :_Warn "File "%_Files%\%%#" does not exist.")
)
rem --- Auto non-interactive selection if BEDI_AUTO_SELECT is set ---
if defined BEDI_AUTO_SELECT (
  set "_opt=%BEDI_AUTO_SELECT%"
  if "%_opt%"=="1" (
    set "_sourSKU=Professional"& set "_targSKU=EnterpriseG"
  ) else if "%_opt%"=="2" (
    set "_sourSKU=Professional"& set "_targSKU=EnterpriseS"
  ) else if "%_opt%"=="3" (
    set "_sourSKU=Professional"& set "_targSKU=WNC"
  ) else if "%_opt%"=="4" (
    set "_sourSKU=Core"& set "_targSKU=Starter"
  ) else if "%_opt%"=="5" (
    set "_sourSKU=ServerDatacenter"& set "_targSKU=EnterpriseS"
  ) else if "%_opt%"=="6" (
    set "_sourSKU=ServerDatacenter"& set "_targSKU=EnterpriseG"
  ) else (
    rem Fallback to interactive menu if value invalid
    call :_MenuTarget
  )
) else (
  call :_MenuTarget
)
for /f "tokens=*" %%# in ('findstr /i "=" Bedi.ini 2^<Nul') do (set "%%#")
Title Building Windows %_targSKU% from %_sourSKU% image  ~  #%_vbedi%
for /f "usebackq delims=" %%# in (`powershell "\"%_targSKU%\".ToUpper()"`) do (set "_bldUpp=%%~#")
set /a _ext=%RANDOM% * 400 / 32768 + 1
set "MT=%ROOT%\mnt%_ext%"
set "_scDir=%ROOT%\sdir%_ext%"
set "_log=%ROOT%\log%_ext%"
set "_sxs=sxs%_ext%"
set "_lp=lp%_ext%"
set "_remdef=%_log%\remdef-%_ext%.lst"
set "DISM=dism.exe /English"
if exist "%ROOT%\DISM0\dism.exe" (set "DISM=%ROOT%\DISM0\dism.exe /English")
set "WLIB=%ROOT%\Files\wimlib-imagex.exe"
set "z7=%ROOT%\Files\7z.exe"
set "nsudo=%ROOT%\Files\NSudo.exe -U:T -P:E -UseCurrentConsole -Wait"
set "_marks=%MT%\ProgramData\Bedi"
set "_mums=%MT%\Windows\servicing\Packages"
set "_tatat=%_log%\tat%_ext%.lst"
set "_resth=0"
set "pwshl=powershell -nologo -noni -nop -exec bypass -c"
set "DismFmt=/LogLevel:2 /ScratchDir:%_scDir% /image:%MT%"
set "_psdism=-LogLevel 2 -Path '%MT%' -ScratchDirectory '%_scDir%'"
set "_cbsKey=HKLM\mtSOFT\Microsoft\Windows\CurrentVersion\Component Based Servicing"
set "_supEnterpriseS=17763 19041 22000 22621 26100 25398"
set "_supEnterpriseG=17763 19041 22000 22621 25398 26100 27729"
set "_supWNC=26100"
set "_supStarter=15063"
set "_seps=------------------------------------------------------------"
Cls
Echo ========================================================================================================
Echo o-------------------------------- THE CONSTRUCTION Of %_bldUpp% -------------------------------------o
Echo ========================================================================================================
Echo.
Echo.
%<%:cf " Prepare "%>>% & %<%:3f " Checking all payload files necessary "%>>% & %<%:1f " Please wait "%>%
%z7% l -ba "%_iw%" -r "windows\servicing\packages\*_for_KB*.*" | find /i "_" %_Nol% && Call :_Warn "Only supports images without any update packages."
For /f "tokens=3 delims=: " %%# in ('%WLIB% info "%_iw%" 2^>Nul ^| Findstr /i /c:"Image Count:"') do (If %%# geq 2 Call :_Warn "Only need professional edition alone.")
For /f "tokens=3 delims=: " %%# in ('%WLIB% info "%_iw%" 1 2^>Nul ^| Findstr /i /c:"Edition ID:"') do (Set "_eid=%%#")
if /i not "%_eid%"=="%_sourSKU%" (Call :_Warn "This source image is not %_sourSKU% edition!")
if /i "%_eid%" == "ServerDatacenter" (
for /f "tokens=3-5 delims=~" %%a in ('%z7% l -ba "%_iw%" -r "windows\servicing\packages\Microsoft-Windows-Server-LanguagePack-Package~*.cat"') do (set "_arc=%%a"&set "_lang=%%b"&set "_version=%%~nc")
) else (
for /f "tokens=3-5 delims=~" %%a in ('%z7% l -ba "%_iw%" -r "windows\servicing\packages\Microsoft-Windows-Client-LanguagePack-Package~*.cat"') do (set "_arc=%%a"&set "_lang=%%b"&set "_version=%%~nc")
)
for /f "tokens=3-4 delims=." %%a in ('echo %_version%') do (
set "_bld=%%a"
if %%b geq 2 (Call :_Warn "Service Pack Build number not supported: %%b")
)
if /i "%_arc%"=="amd64" (set "_uarc=x64") else (Call :_Warn "Only support amd64 architecture, current: %_arc%")
set "_cad=%ROOT%\%_bld%"
set "_vwin=10"
set "_vacdef=%_cad%\Windows-Defender-Vaccine.esd"
if %_bld% geq 22000 (if %_bld% leq 27800 (set "_vwin=11"))
if %_bld% lss 21000 (call :_neutralizer)
If not exist "%ROOT%\%_bld%" (Call :_Warn "The payload files not ready in %_bld% folder")
setlocal EnableDelayedExpansion
echo !_sup%_targSKU%! | find /i "%_bld%" %_Nol% || Call :_Warn "%_targSKU% SKU only support build !_sup%_targSKU%!. The current build is %_bld%."
endlocal
if /i %_targSKU% == EnterpriseG (
if /i not %_lang% == en-us (Call :_Warn "Language Pack not supported for %_targSKU%. Only en-US")
set "_msedge=Without"& set "_defender=Without")
if %_vwin% equ 10 (call :_neutralizer)
Set "_unXml=%ROOT%\%_sxs%\%_bld%.xml"
Set "_esp=%_cad%\Microsoft-Windows-EditionSpecific-%_targSKU%-Package.esd"
Set "_edi=Microsoft-Windows-%_targSKU%Edition~31bf3856ad364e35~%_arc%~~%_version%"
::EnterprisG Volume key (gvlk)
Call :Set_%_targSKU%
Del /f /q %_cad%\*.xml %_cad%\*.mum %_cad%\*.cat %_Nol%
for /d %%# in (log* lp* mnt* sdir* sxs*) do (rmdir /s /q "%%#\")
echo:
echo Source image version: %_eid% %_version% %_lang% %_arc%
echo:
<nul (Set /p _msg=Checking language package...)
set "_fmtName=Microsoft-Windows-Client-LanguagePack-Package-%_arc%-%_lang%.esd"
set "_lpp=%_cad%\%_fmtName%"
if not exist "%_lpp%" (
  dir /b "%_cad%\microsoft-windows-client-languagepack-Package*" %_Nol% || call :_Warn "Language package not found!!"
  for /f %%# in ('dir /b /a:-d "%_cad%\microsoft-windows-client-languagepack-Package*" 2^>Nul') do (
	ren %_cad%\%%# %_fmtName% %_Nol%
	goto :_Ada
  )
)
:_Ada
for /f "tokens=3-5 delims=~" %%a in ('%z7% l -ba "%_lpp%" -r "Microsoft-Windows-Client-LanguagePack-Package~*.cat"') do (set "_carc=%%a"&set "_clang=%%b"&set "_cversion=%%~nc")
if /i not %_version% == %_cversion% (call :_Warn "Wrong language package version!!")
if /i not %_arc% == %_carc% (call :_Warn "Wrong language package architecture!!")
if /i %_targSKU% == EnterpriseG (if /i not %_clang% == en-us (Call :_Warn "Language Pack not supported for %_targSKU%. Only en-US"))
rem if /i not %_lang% == %_clang% (call :_Warn "Only support language package en-US")
echo  Ready.
<nul (set /p _msg=Checking specific package...)
If not exist "%_esp%" (
if %_bld% neq 25398 (call :_Warn "Missing edition specific package file")
if not exist "%_cad%\clients.esd" (call :_Warn "Missing edition specific package file")
%z7% l -ba "%_cad%\clients.esd" -r "Microsoft-Windows-EditionSpecific-%_targSKU%-Package*.*" | find /i ".cat" %_Nol% || if not exist "%_cad%\%_targSKU%.esd" (call :_Warn "Missing edition specific package file")
set "_esp=%_cad%\clients.esd" && set "_sourSKU=ServerDatacenterCor"
goto :_getonexml
) else (
%z7% e -aoa "%_esp%" update.mum %_Nol%
findstr /i "\"%_version%\"" update.mum %_Nol% || (del /f /q update.mum & call :_Warn "Wrong edition specific package version!!")
findstr /i "Microsoft-Windows-EditionSpecific-%_targSKU%" update.mum %_Nol% || (del /f /q update.mum & call :_Warn "Wrong edition for specific package file")
del /f /q update.mum && echo  ready.
)
<nul (set /p _msg=Checking client package...)
%WLIB% extract %_iw% 1 Windows\Servicing\Packages\*Windows-%_sourSKU%Edition~31bf3856ad364e35*.* --dest-dir="%_cad%" --no-acls --no-attributes %_Nol%
ren "%_cad%\*Windows-%_sourSKU%Edition~31bf3856ad364e35*.mum" "%_edi%.mum" %_Nol%
ren "%_cad%\*Windows-%_sourSKU%Edition~31bf3856ad364e35*.cat" "%_edi%.cat" %_Nol%
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]%_targSKU%_XML')[1];DelNudes '%_cad%\%_edi%.mum' '%_bld%'"
:_getonexml
call :_OneXML
mkdir %MT% %_log% %_lp% %_scDir% %_sxs% %_Nol% && Echo  ready.
call :_Teet 2
if exist %_sxs%\ (
  %<%:1f " Process "%>>% & %<%:4f " Get %_targSKU% edition files required "%>>% & %<%:f0 " Please wait "%>%
  If exist "%_cad%\1.xml" (Move /y "%_cad%\1.xml" "%_unXml%" %_Nol%)
  If exist "%_cad%\%_edi%.*" (Move /y "%_cad%\%_edi%.*" %ROOT%\%_sxs%\ %_Nol%)
  Echo:
  <nul (Set /p _msg=Extract Windows %_targSKU% specific edition esd...)
  if /i %_targSKU% == WNC (
    %WLIB% extract "%_edPack%" 1 --dest-dir="%ROOT%\%_sxs%" --no-acls --no-attributes --quiet %_Nol%
    %WLIB% extract "%_edPackW%" 1 --dest-dir="%ROOT%\%_sxs%" --no-acls --no-attributes --quiet %_Nol%
	Call :_export ":NXT_64\:.*" "%ROOT%\%_sxs%\Microsoft-Windows-EditionPack-NXT-Package~31bf3856ad364e35~amd64~~10.0.26100.1.mum" "ASCII" "1"
	Call :_export ":NXT_wow\:.*" "%ROOT%\%_sxs%\Microsoft-Windows-EditionPack-NXT-WOW64-Package~31bf3856ad364e35~amd64~~10.0.26100.1.mum" "ASCII" "1"
  )
  %WLIB% extract "%_esp%" 1 --dest-dir="%ROOT%\%_sxs%" --no-acls --no-attributes --quiet %_Nol% && Echo  Done. || Call :_Warn "Failed getting specific edition."
) else (Call :_Warn "sxs folder does not exist!!")
If exist %_lp%\ (
  <nul (Set /p _msg=Extract Windows language package...)
  %z7% x "%_lpp%" -o"%ROOT%\%_lp%" -y %_Nol% && Echo  Done. || Call :_Warn "Failed getting language package."
) else (Call :_Warn "Lp folder does not exist!!")
Call :_Teet 2
%<%:4f " Building "%>>% & %<%:f0 " Map %_iw% to a folder for servicing "%>%
%DISM% /logpath:%_log%\mounts.log /LogLevel:1 /ScratchDir:%_scDir% /Mount-Image /ImageFile:%_iw% /index:1 /MountDir:%MT% || Call :_Warn "Failed mounting image."
if %_bld% equ 25398 (
%WLIB% extract "%_cad%\%_targSKU%.esd" 1 --dest-dir="%ROOT%\%_sxs%" --no-acls --no-attributes --quiet %_Nol%
call :_prerec
)
call :_%_msedge%msedge
call :_%_defender%defender
%nsudo% cmd /c del /f /q "%mt%\Windows\servicing\Sessions\*" %_Nol%
Call :_Teet 2
%<%:4f " Building "%>>% & %<%:f0 " Start building %_targSKU% "%>%
%DISM% /logpath:%_log%\convert.log %DismFmt% /Apply-Unattend:%_unXml% 2>Nul || Call :_Warn "Apply unattend has Fail."
Call :_Teet 2
%<%:1f " Integrate "%>>% & %<%:f0 " Integrate client language package "%>%
echo:
:: Not support multi languages, but Bedi will let you do it. Just watch out yours feature basic, and FoDs languages.
if /i not %_lang% == %_clang% (
echo - Remove old client language package
%DISM% /Logpath:%_log%\remlp.log %DismFmt% /Remove-Package /PackageName:Microsoft-Windows-Client-LanguagePack-Package~31bf3856ad364e35~%_arc%~%_lang%~%_version%
Call :_Teet 2
echo - Implement desired client language package
)
%DISM% /Logpath:%_log%\lp.log %DismFmt% /add-package:"%ROOT%\%_lp%" || Call :_Warn "Failed add language pack."
%DISM% /Quiet /Logpath:%_log%\lp.log %DismFmt% /set-AllIntl:%_clang% %_Nol%
%DISM% /Quiet /Logpath:%_log%\lp.log %DismFmt% /Set-SKUIntlDefaults:%_clang% %_Nol%
Call :_Teet 2
if defined _vKey (
  %<%:1f " Integrate "%>>% & %<%:f0 " Trying to implement %_targSKU% key "%>%
  %DISM% /Quiet /logpath:%_log%\vKey.log %DismFmt% /Set-productkey:%_vKey% %_Nol% && Echo   Done. || Call :_Warn "Wrong product key."
) else (
  %<%:1f " Integrate "%>>% & %<%:f0 " Set %_virEd% edition "%>%
  %DISM% /Quiet /logpath:%_log%\vEdition.log %DismFmt% /Set-Edition:%_virEd% %_Nol% && Echo   Done. || Echo   Failed set to %_virEd% edition.
)
For /f "tokens=4 delims= " %%i in ('%DISM% /Logpath:%_log%\edition.log %DismFmt% /Get-Currentedition ^| Findstr /i /C:"Current Edition :"') do (set CURRENT=%%i)
echo:
echo  ------------------------------------------------------------
echo   Current Edition : %CURRENT%
echo  ------------------------------------------------------------
call :_Teet 2
set "_ipDisp=Windows %_vwin% %CURRENT% %_uarc% %_clang% %_version%"
set "_ipDDesc=Windows %_vwin% %CURRENT% %_version% %_uarc% %_clang%"
%<%:1f " Integrate "%>>% & %<%:f0 " Trying to apply %CURRENT% edition unattend file "%>%
Del /f /q %MT%\Windows\*.xml %_Nol%
Copy /y %MT%\Windows\servicing\Editions\%CURRENT%Edition.xml %MT%\Windows\%CURRENT%.xml %_Nol%
%DISM% /Quiet /Logpath:%_log%\edition.log %DismFmt% /apply-unattend:%MT%\Windows\%CURRENT%.xml %_Nol% && Echo   Done. || Echo   Failed applying.
call :_set%_targSKU%
call :_saveset
if %_bld% lss 25390 (call :remAppxProv)
if %_bld% equ 25398 (call :_AddAppxs "%_cad%\uwps")
call :_AddFODs
if /i %_msedge% == Without (
if exist "%MT%\Program Files (x86)\Microsoft\Edge\Application\msedge.exe" (
call :_Teet 2
title Remove Microsoft Edge Package  ~  #%_vbedi%
%<%:5f " Lite options "%>>% & %<%:f0 " Removing microsoft edge package "%>%
echo:
%DISM% /Logpath:%_log%\remedge.log %dismFmt% /Remove-Edge
)) else (if %_bld% equ 25398 (call :_addedge253))
call :remCapab
call :remFeatures
:: Remove windows recovery image
if /i %_winre% == Without (
call :_Teet 2
title Remove Windows Recovery  ~  #%_vbedi%
%<%:5f " Lite options "%>>% & %<%:f0 " Removing Windows Recovery Image "%>%
echo:
del /f /q %MT%\Windows\System32\Recovery\winre.wim %_Nol% && echo  DONE. || echo  FAILED.
)
call :_Teet 2
%<%:2f " Finish "%>>% & %<%:f0 " Optimize and Cleanup image "%>%
echo:
<nul (Set /p _msg=Optimizing provisioned appx packages...)
%DISM% /Quiet /Logpath:%_log%\optappx.log %dismFmt% /Optimize-ProvisionedAppxPackages %_Nol% && Echo  Optimized. || Echo  Failed.
if not exist "%MT%\Windows\WinSxS\pending.xml" (
if %_resth% equ 1 (
  call :_Teet 2
  echo Recovering the image healthy after getting vaccinated
  %DISM% /logpath:%_log%\restheal.log %dismFmt% /Cleanup-Image /restorehealth /source:%MT%\Windows\WinSxS /LimitAccess
)
  call :_Teet 2
  <nul (Set /p _msg=Starting component cleanup...)
  %DISM% /Quiet /logpath:%_log%\cleanUp.log %dismFmt% /Cleanup-Image /StartComponentCleanup %_Nol% && Echo  Done. || Echo  Failed.
  call :_Teet 2
  %<%:2f " Finish "%>>% & %<%:f0 " Resetbase %CURRENT% image "%>%
  Echo:
  <nul (Set /p _msg=Starting reset image base...)
  %DISM% /Quiet /Logpath:%_log%\clean.log %DismFmt% /Cleanup-Image /StartComponentCleanup /Resetbase %_Nol% && Echo  Done. || Echo  Failed.
)
Call :_Teet 2
%<%:2f " Finish "%>>% & %<%:f0 " Cleanup unnecessary files "%>%
Call :clManual
Echo   Done.
Call :_Teet 2
Title Save and Unmount image  -  #%_vbedi%
%<%:2f " Finish "%>>% & %<%:f0 " Save and Unmount %CURRENT% image "%>%
%DISM% /logpath:%_log%\commit.log /LogLevel:2 /ScratchDir:%_scDir% /Unmount-wim /Mountdir:%MT% /Commit
Call :_Teet 2
%<%:2f " Finish "%>>% & %<%:f0 " Set WIM information "%>%
Echo:
%WLIB% info %_iw% 1 --image-property NAME="" --image-property DESCRIPTION="" --image-property FLAGS="" --image-property DISPLAYNAME="" --image-property DISPLAYDESCRIPTION="" >NUL 2>&1
%WLIB% info %_iw% 1 --image-property NAME="%CURRENT%" --image-property DESCRIPTION="%CURRENT% %_version% %_uarc% %_clang%" --image-property FLAGS="%CURRENT%" --image-property DISPLAYNAME="%_ipDisp%" --image-property DISPLAYDESCRIPTION="%_ipDDesc%"
Call :_Teet 2
%<%:2f " Finish "%>>% & %<%:f0 " Optimize %CURRENT% image "%>%
%DISM% /logpath:%_log%\export.log /LogLevel:1 /ScratchDir:%_scDir% /export-image /sourceimagefile:%_iw% /sourceindex:1 /destinationimagefile:2.wim /Compress:max /CheckIntegrity
Call :_Teet 2
Del /f /q %_iw% >Nul
Rmdir /s /q %_sxs% %_Nol%
Ren 2.wim %_iw% >Nul
%WLIB% info %_iw% 1
Title FINISH.!  -  #%_vbedi%
Echo:
Echo ========================================================================================================
Echo o-------------------------- %CURRENT% has been successfully constructed --------------------------o
Echo ========================================================================================================
Echo:

:_End
<Nul (set/p _bel=)
Echo:
Choice /c XC /n /m "Press e[X]it or [C]leanup. "
if %ERRORLEVEL% equ 2 (Goto) 2>Nul & Call cleanup.cmd
Exit

:_Warn
Echo:
Echo:
Echo ==*^|ERROR:  %~1  ^|*==
Goto :_End

:_MenuTarget
setlocal EnableDelayedExpansion
if exist Bedi.ini (
for /f "tokens=*" %%# in ('Findstr /i "=" Bedi.ini 2^<Nul') do (
set "%%#"
set "_oldcfg=%%#,!_oldcfg!"
) )
set "_targSKU=Pro_to_EnterpriseG,Pro_to_EnterpriseS,Pro_to_WNC,Core_to_Starter,Server_to_EnterpriseS,Server_to_EnterpriseG"
:_disp
cls
Title Menu Target Selection  ~  #%_vbedi%
echo:
echo ===== Choose target =========
echo:
set /a _No=0
for %%# in (%_targSKU%) do (
  set /a _No+=1
  set _ch!_No!=%%#
  set _opts=%%#
  echo  !_No!. !_opts:_= !
)
echo:
echo  Lite Options:
echo  -------------
echo  20. !_store! Windows Store  		23. !_helospeech! HelloFace and Speech
echo  21. !_defender! Defender,VBS,Bitlocker	24. !_winre! Windows Recovery
echo  22. !_msedge! Microsoft Edge		25. !_wifirtl! Realtek Wifi Driver
echo:
echo  Tools:
echo  ------
echo   9. Modding LCU
echo  10. Updating image
echo  11. Cleanup folder
echo:
echo   0. Exit
echo:
echo ====== Type, hit enter ======
echo Hint:
echo - 5-6, only for build number 25398
echo - 9-10, support for 22000, 22621, and 25398
echo - 20-25, exclusive only for 22000, 22621 and 25398 (IoT)EnterpriseS
echo - 25 = Rtl8187se, Rtl819xp, Rtl85n64
echo:
:_lis
set /p "_opt=Choose your option: " || Goto :_lis
for /f "delims=0123456789" %%a in ("!_opt!") do (set "_opt=")
set "_opt=%_opt%"
if not defined _opt (Goto :_lis)
if %_opt% equ 9 (Goto) 2>Nul & Call "%_Files%\ModLCU.cmd"
if %_opt% equ 10 (Goto) 2>Nul & Call "%_Files%\upmod.cmd"
if %_opt% equ 11 (Goto) 2>Nul & Call "cleanup.cmd"
if %_opt% equ 20 (if /i !_store! == With (set "_store=Without"& Goto :_disp) else (set "_store=With"& Goto :_disp))
if %_opt% equ 21 (if /i !_defender! == With (set "_defender=Without"& Goto :_disp) else (set "_defender=With"& Goto :_disp))
if %_opt% equ 22 (if /i !_msedge! == With (set "_msedge=Without"& Goto :_disp) else (set "_msedge=With"& Goto :_disp))
if %_opt% equ 23 (if /i !_helospeech! == With (set "_helospeech=Without"& Goto :_disp) else (set "_helospeech=With"& Goto :_disp))
if %_opt% equ 24 (if /i !_winre! == With (set "_winre=Without"& Goto :_disp) else (set "_winre=With"& Goto :_disp))
if %_opt% equ 25 (if /i !_wifirtl! == With (set "_wifirtl=Without"& Goto :_disp) else (set "_wifirtl=With"& Goto :_disp))
if %_opt% gtr !_No! (Goto :_lis)
set "_chnm=!_ch%_opt%!"
if %_opt% equ 0 (Exit)
for /f "tokens=1 delims=_" %%# in ("%_chnm%") do (set "_isserv=%%#")
for /f "tokens=3 delims=_" %%# in ("%_chnm%") do (set "_targSKU=%%#")
if /i %_isserv% == Server (set "_sourSKU=ServerDatacenter") else (set "_sourSKU=Professional")
if /i %_targSKU% == Starter (set "_sourSKU=Core")
set "_newcfg=_sourSKU=!_sourSKU!,_targSKU=!_targSKU!,_store=!_store!,_defender=!_defender!,_msedge=!_msedge!,_helospeech=!_helospeech!,_winre=!_winre!,_wifirtl=!_wifirtl!,"
if /i not !_oldcfg! == !_newcfg! (
>Bedi.ini (
echo ;#%_vbedi% Configurations
echo _sourSKU=!_sourSKU!
echo _targSKU=!_targSKU!
echo _store=!_store!
echo _defender=!_defender!
echo _msedge=!_msedge!
echo _helospeech=!_helospeech!
echo _winre=!_winre!
echo _wifirtl=!_wifirtl!)
)
endlocal
cls
exit /b

:clManual
if exist "%MT%\sources\" (rmdir /s /q "%MT%\sources\" %_Nol%)
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

:_Teet
Echo:
ping 127.0.0.1 -n %* >Nul
Echo:
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

:EnterpriseG_XML
Function DelNudes([String] $xmlFile, $builds) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$xml.assembly.assemblyIdentity.name = "Microsoft-Windows-EnterpriseGEdition"
	$xml.assembly.package.identifier = "Windows EnterpriseG Edition"
	$updates = $xml.assembly.package.update
	$updates | Where {$_.name.contains("Not-Supported-On-LTSB")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	$updates | Where {$_.name.contains("EditionSpecific-Professional-WOW64")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	$updates | Where {$_.name.contains("EditionSpecific-Professional")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionSpecific-EnterpriseG-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionSpecific-EnterpriseG-Package"}
    $xml.Save("$xmlFile")
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:EnterpriseG_XML
::=========================================================================

:WNC_XML
Function DelNudes([String] $xmlFile, $builds) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$xml.assembly.assemblyIdentity.name = "Microsoft-Windows-WNCEdition"
	$xml.assembly.package.identifier = "Windows WNC Edition"
	$updates = $xml.assembly.package.update
	$updates | Where {$_.name.contains("Not-Supported-On-LTSB")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	$updates | Where {$_.name.contains("EditionSpecific-Professional-WOW64")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	$updates | Where {$_.name.contains("EditionSpecific-Professional")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionSpecific-WNC-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionSpecific-WNC-Package"}
	$updates | Where {$_.name.contains("EditionPack-Professional-WOW64")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionPack-WNC-WOW64-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionPack-WNC-WOW64-Package"}
	$updates | Where {$_.name.contains("EditionPack-Professional")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionPack-WNC-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionPack-WNC-Package"}
    $xml.Save("$xmlFile")
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:WNC_XML
::=========================================================================

:EnterpriseS_XML
Function DelNudes([String] $xmlFile, $builds) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$xml.assembly.assemblyIdentity.name = "Microsoft-Windows-EnterpriseSEdition"
	$xml.assembly.package.identifier = "Windows EnterpriseS Edition"
	$updates = $xml.assembly.package.update
	$updates | Where {$_.name.contains("Not-Supported-On-LTSB")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	$updates | Where {$_.name.contains("EditionSpecific-Professional-Package")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionSpecific-EnterpriseS-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionSpecific-EnterpriseS-Package"}
	if ($builds -ge '22621') {
	  $updates | Where {$_.name.contains("EditionSpecific-Professional-WOW64")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64-Package"; `
	    $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64-Package"}
    } else {
	  $updates | Where {$_.name.contains("EditionSpecific-Professional-WOW64")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	}
	$updates | Where {$_.name.contains("Windows-RegulatedPackages-Package")} | Foreach-Object {$_.name = "Microsoft-Windows-Common-RegulatedPackages-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-Common-RegulatedPackages-Package"}
	$updates | Where {$_.name.contains("Windows-RegulatedPackages-WOW64")} | Foreach-Object {$_.name = "Microsoft-Windows-Common-RegulatedPackages-WOW64-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-Common-RegulatedPackages-WOW64-Package"}
	$xml.Save("$xmlFile")
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:EnterpriseS_XML
::=========================================================================

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

:Starter_XML
Function DelNudes([String] $xmlFile, $builds) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$xml.assembly.assemblyIdentity.name = "Microsoft-Windows-StarterEdition"
	$xml.assembly.package.identifier = "Windows Starter Edition"
	$updates = $xml.assembly.package.update
	$updates | Where {$_.name.contains("EditionSpecific-Core-Package")} | Foreach-Object {$_.name = "Microsoft-Windows-EditionSpecific-Starter-Package"; `
	  $_.package.assemblyIdentity.name = "Microsoft-Windows-EditionSpecific-Starter-Package"}
	$selNode = $updates | Where {$_.name.contains("EditionSpecific-Starter-Package")}; $clNode = $selNode.Clone()
	$clNode.name = "Microsoft-Windows-EditionSpecific-Starter-WOW64-Package"; $clNode.package.assemblyIdentity.name = "Microsoft-Windows-EditionSpecific-Starter-WOW64-Package"
	[void]$xml.assembly.package.InsertAfter($clNode, $selNode)
	$updates | Where {$_.name.contains("Windows-EditionPack-Core")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
	$updates | Where {$_.name.contains("Windows-Holographic-Desktop")} | Foreach-Object {[void]$_.ParentNode.RemoveChild($_)}
    $xml.Save("$xmlFile")
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:Starter_XML
::=========================================================================

:_OneXML
If exist %_cad%\*.xml (Del /f /q %_cad%\*.xml)
>%_cad%\1.xml (
Echo.^<?xml version="1.0" encoding="utf-8"?^>
Echo.^<unattend xmlns="urn:schemas-microsoft-com:unattend"^>
Echo.    ^<servicing^>
Echo.        ^<package action="install"^>
Echo.           ^<assemblyIdentity name="Microsoft-Windows-%_targSKU%Edition" version="%_version%" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral"/^>
Echo.	        ^<source location="Microsoft-Windows-%_targSKU%Edition~31bf3856ad364e35~amd64~~%_version%.mum"/^>
Echo.        ^</package^>
if %_bld% equ 25398 (
Echo.        ^<package action="remove"^>
Echo.           ^<assemblyIdentity name="Microsoft-Windows-Server-FodMetadata-Package" version="%_version%" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral"/^>
Echo.        ^</package^>
Echo.        ^<package action="remove"^>
Echo.           ^<assemblyIdentity name="Microsoft-Windows-Server-LanguagePack-Package" version="%_version%" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="en-US"/^>
Echo.        ^</package^>
Echo.        ^<package action="remove"^>
Echo.           ^<assemblyIdentity name="Microsoft-Windows-ServerTurbineCorEdition" version="%_version%" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral"/^>
Echo.        ^</package^>
)
Echo.        ^<package action="remove"^>
Echo.           ^<assemblyIdentity name="Microsoft-Windows-%_sourSKU%Edition" version="%_version%" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral"/^>
Echo.        ^</package^>
Echo.    ^</servicing^>
Echo.^</unattend^>
)
Exit /b
::=========================================================================

:NXT_64:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionPack-NXT-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionPack-NXT" releaseType="Feature Pack">
    <update name="1f7d4a23a5421d808344b0e767cd6a8f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Win2-MSXML6-Feature" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="fcc02e2617792e90bfb3edbb44b52038">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-CorePC-HyperV-Guest-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6fba97605c47d9bcbbbb37306df19d03">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-AppxOffline-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="bbebf61bb877ce91f39fa538c039d606">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-Configuration-Desktop-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="3cb502877a19332158f39478d1898881">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-Infrastructure-Desktop-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="d80d021fcd88fc0fb47bd44cbd8b4388">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-Servicing-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="84f484f870d56a4310e243948fe8aa55">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-Shell-Config-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="de544d3fa6c58e8bf7f0056244df064a">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-Windows365-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="c5ba5983662fa5978c36517668e6e397">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OneCore-Graphics-HyperV-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="66fef376421b48a9ecae9d258aeec68b">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OneCore-HyperV-Guest-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6f722f1b831920b227c08d374db2e21f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OneCore-HyperV-Guest-Networking-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="c9b3121aff3cb95e6e6c52d513b93c54">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Win4-Product-Extension-NXT-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="e358ea7f961b30e894dc193fd028e129">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Win4-WAM-Extension-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="74c95b7a1e37035c8f961e110a24f5b0">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Font-Support-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="5ee3eff79f8a47184db61c82a1b198ca">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-InstallType-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="b4783ea877d8775bc8789399aec58522">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="e613b5e235109adf9c53dd763923a94f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-BaseBuildRevisionNumber-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="13d019086ef00c398221973752e252ad">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-BuildLayers-OneCoreUAP-BuildInfo-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="37c6a6dcf1589e8f06e569e40c8264d7">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-BuildLayers-OneCoreUAP-VersionInfo-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="9aedfe97e216a79820cfc5f5fb542470">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-ControlsFolder-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="89b781d60232697a1b1cb7feae1cf13a">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-DisplayVersion-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="66f5b0095475f4d2f535a9f9f9f6bf28">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-Legacy-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="e41c9726fb7395f4d3ff07423ed922ac">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-SoftwareType-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6bffd56a4c16577560ddeaf89776c676">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-VersionInfo-Dynamic-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="1316bc27c9a4c0a1234fa2b5f2d3019c">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-VersionInfo-Static-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="a2c6b1e6342353069b79272da120609e">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-AppManagement-AppV-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="96faa43d2236eedf07bde990707174ba">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-AppManagement-Common-Package" version="10.0.26100.1" processorArchitecture="amd64" language="en-US" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="71fefd2fcb10d0fae3f7b8c7eca9691f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Client-AssignedAccess-Package" version="10.0.26100.1" processorArchitecture="amd64" language="en-US" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7a799b4ca5ccc3c74cdf03a54b57d19f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Client-ShellLauncher-Package" version="10.0.26100.1" processorArchitecture="amd64" language="en-US" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="1cea2dad1090379f3dd3eda1bb001145">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Enterprise-Desktop-Shared-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="30fa5e666c33b022e89f1847d91e8071">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-NetFx3-OC-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="a0533726923739b66e429ed866733ab4">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-NetFx4-US-OC-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7c598aad9dacde61f5988107c55da1c0">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-NetFx3-WCF-OC-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="a3ef0f91a5e67285cd823c3118c4dc25">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-NetFx4-WCF-US-OC-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:NXT_64:

:NXT_wow:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionPack-NXT-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionPack-NXT-WOW64" releaseType="Feature Pack">
    <update name="4946e0a20bf5712e32dba3c72726437d">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Win2-MSXML6-WOW64-Feature" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="af0aa72e1baad8dc4b6a660818b70041">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-CorePC-HyperV-Guest-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="187692a279ef05bde48796a32951cdb9">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-AppxOffline-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="40e5dfc722ef83175b121fe5462a99aa">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-NXT-Servicing-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7df3ae9bb6c87560de4c26c43b6b3d3a">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OneCore-HyperV-Guest-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="a4c615f34b7fca1831a5e6a088ee3f7a">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Win4-Product-Extension-NXT-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="2b6099e2e47629cbf855db7df6b53e11">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Win4-WAM-Extension-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="76ce6e128e4ba0369c6fa942ca4d5ede">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Client-AssignedAccess-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="58731324c82242f12697aeec1d3facfa">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-AppManagement-AppV-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="0bb1880094ca93e3eaaff1332099bd43">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-AppManagement-Common-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="4c890dc9964df2bf754a45180be679b5">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Enterprise-Desktop-Shared-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="f3882484956bb4a7b17be8e8199b0609">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Font-Support-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="ccf2aaae4127e4b5c49977d9f71d2abc">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="4d93d6cc266b930f9659478041a602c1">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-BaseBuildRevisionNumber-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7129ecb00366d4c02cdd3f8e580cf071">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-BuildLayers-OneCoreUAP-BuildInfo-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="c4b36c3a64fafe90e403f2d1139ea1a5">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-BuildLayers-OneCoreUAP-VersionInfo-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="d3f13d6304c57bb09f7aeae1f5b9596d">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-ControlsFolder-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="71a6d2001cf8ce8a22514ca4ce4b0f63">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-DisplayVersion-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="300c64efba36e3f86cb49a375e71573c">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-Legacy-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="fc993537a91a8ffd6ab12f5cc95a3448">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-SoftwareType-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="521f646d0fae4ff75af69078d525044f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-VersionInfo-Dynamic-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="b3185c2258a23ac9b5f2cb70f4c892cc">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Product-Data-VersionInfo-Static-WOW64-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:NXT_wow:

:_setWNC
call :MountReg
%nsudo% reg add "HKLM\mtSOFT\Microsoft\Command Processor" /f /v "DefaultColor" /t REG_DWORD /d "10" %_Nol%
%nsudo% reg add "HKLM\mtSOFT\Microsoft\Windows NT\CurrentVersion\NXT" /f /v "F10Admin_Password" /t REG_SZ /d "" %_Nol%
call :UnMountReg
Exit /b

:_setEnterpriseS
set "safe_prov=NET.Native|ScreenSketch|SecHealthUI|UI.Xaml|VCLibs"
if /i %_defender% == Without (set "safe_prov=NET.Native|ScreenSketch|UI.Xaml|VCLibs")
if /i %_store% == With (set "safe_prov=%safe_prov%|DesktopAppInstaller|Store|HEIFImageExtension|HEVCVideoExtension|VP9VideoExtensions|WebMediaExtensions|WebpImageExtension")
exit /b

:_setEnterpriseG
Xcopy /CHIERQY "%_Files%\Lics\%_targSKU%" "%MT%\Windows\System32\" %_Nol%
call :MountReg
reg add "HKLM\mtSOFT\Microsoft\PolicyManager\current\device\Accounts" /f /v "AllowMicrosoftAccountSignInAssistant" /t REG_DWORD /d "1" %_Nol%
call :UnMountReg
set "safe_prov=NET.Native|ScreenSketch|UI.Xaml|VCLibs"
if /i %_store% == With (
set "safe_prov=%safe_prov%|DesktopAppInstaller|Store|HEIFImageExtension|HEVCVideoExtension|VP9VideoExtensions|WebMediaExtensions|WebpImageExtension"
)
set "_defender=Without"& set "_msedge=Without"
exit /b

:MountReg
Set "mtrPath=%MT%\Windows\System32\config"
rem Set "mtUPath=%MT%\Users\Default"
rem if exist "%mtUPath%\NTUSER.DAT" Reg load HKLM\mtUSER "%mtUPath%\NTUSER.DAT" %_Nol%
if exist "%mtrPath%\SOFTWARE" Reg load HKLM\mtSOFT "%mtrPath%\SOFTWARE" %_Nol%
if exist "%mtrPath%\SYSTEM" Reg load HKLM\mtSYS "%mtrPath%\SYSTEM" %_Nol%
rem if exist "%mtrPath%\DEFAULT" Reg load HKLM\mtDEF "%mtrPath%\DEFAULT" %_Nol%
ping 127.0.0.1 -n 2 >Nul
Exit /b

:UnMountReg
rem Reg unload HKLM\mtDEF %_Nol%
rem Reg unload HKLM\mtUSER %_Nol%
Reg unload HKLM\mtSOFT %_Nol%
Reg unload HKLM\mtSYS %_Nol%
ping 127.0.0.1 -n 2 >Nul
Exit /b

:_AddFODs
set "_notforg="
if exist "%_cad%\fods\*.cab" (set "_fodext=%_cad%\fods\*.cab") else (if exist "%_cad%\fods\*.esd" (set "_fodext=%_cad%\fods\*.esd"))
if exist "%_cad%\fodlp\*.cab" (set "_fodextlp=%_cad%\fodlp\*.cab") else (if exist "%_cad%\fodlp\*.esd" (set "_fodextlp=%_cad%\fodlp\*.esd"))
if not defined _fodext (exit /b) else (set "_fodext=%_cad%\fods"& set "_fodextlp=%_cad%\fodlp")
call :_Teet 2
if /i %_targSKU% == EnterpriseG (set "_notforg=notepad,MSPaint,SnippingTool")
title Implementing %_targSKU% FOD Packages  ~  #%_vbedi%
%<%:5f " Customize "%>>% & %<%:f0 " Implement some %_targSKU% FoD packages "%>%
echo:
if exist "%MT%\Windows\servicing\FodMetadata\" (%nsudo% cmd /c ren "%mt%\Windows\servicing\FodMetadata" "Food" %_Nol%)
if exist "%MT%\Windows\servicing\InboxFodMetadataCache\" (%nsudo% cmd /c rmdir /s /q "%mt%\Windows\servicing\InboxFodMetadataCache\" %_Nol%)
for /f %%# in ('dir /b /a:-d "%_fodext%\*"') do (
<nul (Set /p _msg=- %%#...)
for %%g in (%_notforg%) do (
echo %%# | findstr /ir "%%g.*amd64" %_Nol% && set "_notig=1"
)
if defined _notig (echo  SKIP.) else (%dism% /Quiet /logpath:%_log%\fod.log %dismfmt% /add-package:"%_fodext%\%%#" %_Nol% && echo  DONE. || Echo  FAILED!)
set "_notig="
)
echo %_seps%
if defined _fodextlp (
call :_Teet 2
title Implementing %_targSKU% FOD Language Packages  ~  #%_vbedi%
%<%:5f " Customize "%>>% & %<%:f0 " Implement some %_targSKU% FoD language packages "%>%
echo:
for /f %%# in ('dir /b /a:-d "%_fodextlp%\*"') do (
<nul (Set /p _msg=- %%#...)
for %%g in (%_notforg%) do (
echo %%# | findstr /ir "%%g.*amd64" %_Nol% && set "_notig=1"
)
if defined _notig (echo  SKIP.) else (%dism% /Quiet /logpath:%_log%\fodlp.log %dismfmt% /add-package:"%_fodextlp%\%%#" %_Nol% && echo  DONE. || Echo  FAILED!)
set "_notig="
))
echo %_seps%
set "_notforg="
set "_bldmeta=%_cad%\%_bld%_fodmetadata.cab"
if exist "%_bldmeta%" (
<nul (Set /p _msg=- Microsoft-Windows-FodMetadata-Package...)
%dism% /Quiet /logpath:%_log%\fodmeta.log %dismfmt% /add-package:"%_bldmeta%" %_Nol% && echo  DONE. || Echo  FAILED!
)
if not exist "%MT%\Windows\servicing\FodMetadata\" (
if exist "%MT%\Windows\servicing\Food\" (%nsudo% cmd /c ren "%MT%\Windows\servicing\Food" "FodMetadata" %_Nol%)) else (
if exist "%MT%\Windows\servicing\Food\" (%nsudo% cmd /c rmdir /s /q "%MT%\Windows\servicing\Food" %_Nol%))
%DISM% /Quiet /logpath:%_log%\capa.log %dismfmt% /get-capabilities %_Nol%
exit /b

:_AddAppxs
call :_Teet 2
title Implementing Provisioned Packages  ~  #%_vbedi%
%<%:5f " Customize "%>>% & %<%:f0 " Implement some provisioned appx and licenses "%>%
echo:
set "_skappx="
set "_apxstore=store,DesktopAppInstaller,HEIFImageExtension,HEVCVideoExtension,VP9VideoExtensions,WebMediaExtensions,WebpImageExtension"
if /i %_defender% == Without (set "_skappx=SecHealthUI")
if /i %_store% == Without (if defined _skappx (set "_skappx=%_skappx%,%_apxstore%") else (set "_skappx=%_apxstore%"))
setlocal EnableDelayedExpansion
set _appxs=msixbundle,appxbundle,appx,msix
set _lic=
For %%i in (!_appxs!) do (
For /f "tokens=* delims=" %%# in ('dir /b "%~1\*.%%i" 2^>Nul') do (
  set "_notig=0"
  for %%s in (%_skappx%) do (
    echo %%# | find /i "%%s" %_Nol% && set "_notig=1"
  )
  set "_lic=/SkipLicense"&Set "_xml="
  if !_notig! neq 1 (
  For /f "tokens=1,5 delims=_" %%a in ('Echo %%~n#') do (Set "_xml=%~1\%%a_%%b.xml")
  if exist "!_xml!" (set "_lic=/LicensePath:"!_xml!"")
  %z7% l -ba "%~1\%%#" | find /i "\Stub\" %_Nol% && Set "_lic=!_lic! /StubPackageOption:InstallFull"
  <nul (Set /p _msg=- %%#...)
  %DISM% /Quiet /Logpath:%_log%\adappx.log %dismfmt% /Add-ProvisionedAppxPackage /PackagePath:"%~1\%%#" /Region:US !_lic! %_Nol% && Echo  DONE. || Echo  FAILED!
  )
))
For /f "tokens=* delims=" %%# in ('dir /b /ad "%~1\*" 2^>Nul') do (
  set "_lic=/SkipLicense"
  set "_notig=0"
  for %%s in (%_skappx%) do (
    echo %%# | find /i "%%s" %_Nol% && set "_notig=1"
  )
  if !_notig! neq 1 (
  if exist "%~1\%%#\License.xml" (set "_lic=/LicensePath:"%~1\%%#\License.xml"")
  if exist "%~1\%%#\AppxMetadata\Stub\*.*x" (set "_lic=!_lic! /StubPackageOption:InstallFull")
  <nul (Set /p _msg=- %%#...)
  %DISM% /Quiet /Logpath:%_log%\adappx.log %dismfmt% /Add-ProvisionedAppxPackage /PackagePath:"%~1\%%#\%%#.msixbundle" /Region:US !_lic! %_Nol% && Echo  DONE. || Echo  FAILED!
  )
)
endlocal
echo %_seps%
Exit /b

:remAppxProv
call :_Teet 2
title Remove Appx Provisioned Packages  ~  #%_vbedi%
%<%:5f " Lite Option "%>>% & %<%:f0 " Removing unused appx provisioned "%>%
echo:
set "_flist=%_log%\prov-%_ext%.lst"
if defined safe_prov (
set "_shlcmd=(Get-AppxProvisionedPackage -LogPath '%_log%\rmprov.log' %_psdism%|?{$_.PackageName -NotMatch '%safe_prov%'}).PackageName"
) else (
set "_shlcmd=(Get-AppxProvisionedPackage -LogPath '%_log%\rmprov.log' %_psdism%).PackageName"
)
>%_flist% (%pwshl% "%_shlcmd%")
for /f "tokens=*" %%# in ('Findstr /i . %_flist%') do (
<nul (set/p _msg=- %%#...)
%dism% /Quiet /Logpath:%_log%\rmprov.log %dismfmt% /Remove-ProvisionedAppxPackage /PackageName:%%# %_nol% && echo  REMOVED. || echo  FAILED!
)
echo %_seps%
exit /b

:Set_EnterpriseG
Set "_vKey=YYVX9-NTFWV-6MDM3-9PT4T-4M68B"
Set "_virEd=EnterpriseG"
Exit /b

:Set_EnterpriseS
Rem Set "_vKey=CGK42-GYN6Y-VD22B-BX98W-J8JXD"
Rem Set "_vKey=JH8W6-VMNWP-6QBDM-PBP4B-J9FX9"
Set "_virEd=IoTEnterpriseS"
if /i %_bld% equ 17763 (set "_virEd=EnterpriseS")
if /i %_bld% equ 25398 (set "_vKey=KBN8V-HFGQ4-MGXVD-347P6-PDQGT")
Exit /b

:Set_WNC
Set "_vKey=TMP2N-KGFHJ-PWM6F-68KCQ-3PJBP"
Set "_virEd=WNC"
Set "_edPack=%_cad%\Microsoft-Windows-EditionPack-WNC-Package.ESD"
Set "_edPackW=%_cad%\Microsoft-Windows-EditionPack-WNC-WOW64-Package.ESD"
Exit /b

:Set_Starter
  Set "_vKey=D6RD9-D4N8T-RT9QX-YW6YT-FCWWJ"
  Set "_virEd=Starter"
Exit /b

:_saveset
:: save settings to a file
if not exist "%_marks%\" (mkdir "%_marks%\" %_Nol%)
copy /y Bedi.ini "%_marks%\Bedi.ini" %_Nol%
exit /b

:_remtestpack
call :MountReg
For %%# in (%_defPack%) do (
call :_lossp %%#
)
call :UnMountReg
exit /b

:_lossp
set _deff=%*~
if not exist %_remdef% (type nul>%_remdef%)
for /f "delims=" %%i in ('reg query "%_cbsKey%\Packages" /k /f "*%_deff%*" 2^>Nul ^| find "~~"') do (
reg delete "%%i\Owners" /f %_Nol%
reg add "%%i" /f /v "Visibility" /t REG_DWORD /d "1" %_Nol%
>>%_remdef% echo %%~nxi
)
exit /b

:_doremtestpack
For /f "tokens=*" %%# in ('Findstr /i . %_remdef% 2^<Nul') do (
  <nul (Set /p _msg=- %%#...)
  %DISM% /Quiet /logpath:%_log%\defend.log %dismFmt% /Remove-Package /PackageName:%%# %_Nol% && Echo  Done. || Echo  FAILED!
)
del /f /q "%_remdef%" %_Nol%
rem set "_resth=1"
exit /b

:_xmlrem
if %_bld% lss 21950 (exit /b) else (if %_bld% gtr 26000 (exit /b))
For %%# in (%ROOT%\%_sxs%\Microsoft-Windows-EditionSpecific-EnterpriseS-Package*.mum) do (set "_mumfile=%%#")
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]rempack_XML')[1];DelNudes '%_mumfile%' '%~1'"
exit /b

:remCapab
if /i %_helospeech% == Without (set "rem_cap=Hello.Face|Speech")
if /i %_wifirtl% == Without (if defined rem_cap (set "rem_cap=%rem_cap%|Rtl8187se|Rtl819xp|Rtl85n64") else (set "rem_cap=Rtl8187se|Rtl819xp|Rtl85n64"))
if not defined rem_cap (exit /b)
Call :_Teet 2
title Remove Capabilites Packages  -  #%_vbedi%
%<%:5f " Lite Option "%>>% & %<%:f0 " Removing some capabilities app "%>%
echo:
set "_flist=%_log%\cap-%_ext%.lst"
>%_flist% (%pwshl% "(Get-WindowsCapability -LogPath '%_log%\rmcapa.log' %_psdism%|?{($_.State -eq 'Installed') -and ($_.Name -Match '%rem_cap%')}).Name")
For /f "tokens=*" %%# in ('Findstr /i . %_flist%') do (
  <nul (set/p _msg=- %%#...)
  %DISM% /Quiet /LogPath:%_log%\rmcapa.log %dismFmt% /Remove-Capability /CapabilityName:%%# %_Nol% && Echo  REMOVED. || Echo  FAILED!
)
echo %_seps%
exit /b

:remFeatures
if /i %_defender% == Without (set "_sFeat=Defender|Platform|BitLocker")
if not defined _sFeat (exit /b)
title Remove Feature Packages  -  #%_vbedi%
call :_Teet 2
%<%:5f " Lite option "%>>% & %<%:f0 " Removing some feature packages "%>%
echo:
set "_flist=%_log%\feat-%_ext%.lst"
>%_flist% (%pwshl% "(Get-WindowsOptionalFeature -LogPath '%_log%\feats.log' %_psdism%|?{($_.FeatureName -Match '%_sFeat%')}).FeatureName")
for /f "tokens=*" %%# in ('findstr /i . %_flist%') do (
  <nul (set/p _msg=- %%#...)
  %dism% /Quiet /LogPath:%_log%\feats.log %dismfmt% /Disable-Feature /FeatureName:%%# /Remove %_nol% && Echo  REMOVED. || Echo  FAILED!
)
echo %_seps%
exit /b

:_neutralizer
set "_store=With"
set "_defender=With"
set "_msedge=With"
set "_helospeech=With"
set "_winre=With"
set "_wifirtl=With"
exit /b

:_vacdefend
if exist "%_vacdef%" (
echo:
%<%:5f " Isolation "%>>% & %<%:f0 " Vaccination Windows Defender "%>%
%DISM% /logpath:%_log%\defremoval.log %dismFmt% /Add-Package:"%_vacdef%"
)
exit /b

:_withoutdefender
if %_bld% lss 21000 (exit /b) else (if %_bld% gtr 26000 (exit /b))
title Quarantine Windows Defender Installation  ~  #%_vbedi%
set "_packdefender=Windows-Defender-ApplicationGuard-Inbox-Package,Windows-Defender-ApplicationGuard-Inbox-WOW64-Package"
call :_defendremgen "%_packdefender%" "defender"
call :_vacdefend
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-Package" "Defender-ApplicationGuard-Inbox"
call :_xmlmumrem "Microsoft-Windows-EditionPack-Professional-WOW64-Package" "Defender-ApplicationGuard-Inbox"
if %_bld% equ 22000 (call :_xmlmumrem "Microsoft-Windows-Desktop-Shared-Package" "Dynamic-Image-Package")
call :_xmlrem "Windows-SenseClient"
exit /b

:_xmlmumrem
For %%# in (%_mums%\%~1~*.mum) do (set "_mumfile=%%#")
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]rempack_XML')[1];DelNudes '%_mumfile%' '%~2'"
exit /b

:_defendremgen
set "_defPack=%~1"
call :_remtestpack
if exist "%_remdef%" (
call :_Teet 2
%<%:5f " Isolation "%>>% & %<%:f0 " Quarantine windows %~2 packages "%>%
echo:
call :_doremtestpack
)
exit /b

:_withdefender
rem just empty dummy function
exit /b

:_withoutmsedge
if %_bld% lss 21000 (exit /b) else (if %_bld% gtr 26000 (exit /b))
title Quarantine Microsoft Edge Inbox Installation  ~  #%_vbedi%
call :_msedge%_bld%
call :_xmlrem "Windows-Internet-Browser"
exit /b

:_msedge22000
set "_defPack=Windows-MicrosoftEdgeDevToolsClient-Package"
call :_remtestpack
if exist "%_remdef%" (
  call :_Teet 2
  %<%:5f " Isolation "%>>% & %<%:f0 " Quarantine Microsoft Edge inbox apps "%>%
  echo:
  call :_doremtestpack
)
call :_xmlmumrem "Microsoft-Windows-Desktop-Required-ClientOnly-Removable-Package" "Windows-MicrosoftEdgeDevToolsClient"
exit /b

:_msedge22621
if exist "%_cad%\Microsfot-Edge-Vaccine.esd" (
call :_Teet 2
%<%:5f " Isolation "%>>% & %<%:f0 " Vaccination Microsoft Edge inbox apps "%>%
%DISM% /logpath:%_log%\defremoval.log %dismFmt% /Add-Package:"%_cad%\Microsfot-Edge-Vaccine.esd"
)
exit /b

:_msedge25398
call :_msedge22621
exit /b

:_withmsedge
rem just empty dummy function
exit /b

:_prerec
call :_Teet 2
%<%:5f " Customize "%>>% & %<%:f0 " Removing fod packages from source "%>%
echo:
for %%# in (
Downlevel-NLS-Sorting-Versions-Server-FoD-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-OneCore-DirectX-Database-FOD-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-Kernel-LA57-FoD-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-LanguageFeatures-Speech-en-us-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-LanguageFeatures-TextToSpeech-en-us-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-Telnet-Client-FOD-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-VBSCRIPT-FoD-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-WMIC-FoD-Package~31bf3856ad364e35~amd64~~10.0.25398.1
OpenSSH-Client-Package~31bf3856ad364e35~amd64~~10.0.25398.1
Microsoft-Windows-LanguageFeatures-Basic-en-us-Package~31bf3856ad364e35~amd64~~10.0.25398.1
) do (
<nul (set/p _msg=- %%#...)
%DISM% /Quiet /LogPath:%_log%\remcapab.log %dismFmt% /Remove-Package /PackageName:%%# %_Nol% && Echo  REMOVED. || Echo  FAILED.
)
exit /b

:_addedge253
if exist "%_cad%\edge.wim" (
call :_Teet 2
%<%:5f " Customize "%>>% & %<%:f0 " Implement Microsoft Edge "%>%
%DISM% /LogPath:%_log%\addedge.log %dismFmt% /Add-Edge /SupportPath:"%_cad%"
)
exit /b

