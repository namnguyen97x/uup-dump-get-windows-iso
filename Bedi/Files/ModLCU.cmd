:: must call from Bedi.cmd
@Cls
@Echo Off
@Setlocal EnableExtensions DisableDelayedExpansion
Title Modding LCU.msu file  ~  #%_vbedi%
set "_drv=%~d0"
pushd "%ROOT%"
chcp 437 >nul
start /b powershell -nop -c "&{$w=(get-host).ui.rawui;$w.buffersize=@{width=256;height=1512};$w.windowsize=@{width=110;height=33};}"
set "_vclcu=ModLCU v3.1"
set "_vsupp=22000 22621 25398"
set "_Nol=1>Nul 2>Nul"
set "_source=EnterpriseEval"
set "_target=EnterpriseS"
set "_meds=31bf3856ad364e35~amd64~"
set /a _ext=%RANDOM% * 300 / 32768 + 1
set "_bin=%ROOT%\Files"
set "z7=%_bin%\7z.exe"
set "wlib=%_bin%\wimlib-imagex.exe"
set "_exp=%_bin%\expand.exe"
set "_tmp=%ROOT%\tmp%_ext%"
set "_kb=%ROOT%\kb%_ext%"
set "_fsu=%ROOT%\fsu%_ext%"
set "_sxs=%ROOT%\sxs%_ext%"
<nul (set /p _msg=Preparing the binary needs...)
for /f %%# in ('dir /b /a-d "*.msu" 2^>Nul') do (
%z7% l -ba "%%#" -r "ssu*.*" | find /i "-" %_Nol% && set "_msu=%%#"
)
if not defined _msu (call :_Warn Update file not found.!!)
Title Modding %_msu% file  ~  #%_vclcu%
for /d %%# in (tmp* kb* fsu* sxs*) do (rmdir /s /q "%%#\")
for /f "tokens=3 delims= " %%# in ('%z7% l -ba -slt "%_msu%" -r "ssu*.*" ^| findstr /i "ssu"') do (set "_ssu=%%~n#")
for /f "tokens=3 delims= " %%# in ('%z7% l -ba -slt "%_msu%" -r "windows1*.psf" ^| findstr /i ".psf"') do (set "_wkb=%%~n#"& set "_wkbx=%_tmp%\%%~n#.cab")
%z7% e -aoa "%_msu%" desktopdeployment.cab %_ssu%.* %_wkb%.* -o"%_tmp%\" -y %_Nol%
::cek support build number
for /f "tokens=2 delims=-" %%# in ('echo %_ssu%') do (set "_modbld=%%~n#")
echo %_vsupp% | find /i "%_modbld%" %_Nol% || Call :_Warn "Only support 22000 and 22621 build number. The current build is %_modbld%."
if %_modbld% equ 25398 (set "_source=ServerDatacenterCor")
if not exist "%_tmp%\desktopdeployment.cab" (call :_Warn "Desktopdeployment.cab file not exist.")
%z7% e -aoa "%_tmp%\desktopdeployment.cab" dpx.dll -o"%_tmp%\" -y %_Nol%
for /f "tokens=3 delims= " %%# in ('%z7% l -ba -slt "%_tmp%\desktopdeployment.cab" -r "updatecompression.dll" ^| findstr /i "update"') do (set "_ucmp=%%#")
if defined _ucmp (
%z7% e -aoa "%_tmp%\desktopdeployment.cab" "%_ucmp%" -o"%_tmp%" -y %_Nol%
ren %_tmp%\%_ucmp% msdelta.dll
copy /y "%_bin%\expand_new.exe" "%_tmp%\expand.exe" %_Nol%
set "_exp=%_tmp%\expand.exe"
)
for %%# in (msdelta.dll PSFExtractor.exe) do (if not exist "%_tmp%\%%#" (copy /y "%_bin%\%%#" "%_tmp%\" %_Nol%))
mkdir %_kb% %_fsu% %_sxs% %_Nol%
echo READY.
echo:
<nul (set /p _msg=Extract %_ssu%.cab, please wait...)
if not exist %_tmp%\%_ssu%.cab (call :_Warn "Service stack update cab files not found.")
%_exp% -f:* "%_tmp%\%_ssu%.cab" "%_fsu%" %_Nol% && echo DONE. || call :_Warn "Failed extracting %_ssu%.cab files."
<nul (set /p _msg=Extract %_wkbx%, please wait...)
if not exist %_tmp%\%_wkb%.cab (
set "_wkbx=%_tmp%\%_wkb%.wim"& set "_wim=1"
if not exist %_tmp%\%_wkb%.wim (call :_Warn "Last cumulative update cab/wim file not found.")
)
if defined _wim (
%z7% e -aoa "%_wkbx%" -o"%_kb%" -y %_Nol% && echo DONE. || call :_Warn "Failed extracting %_wkb%.wim files."
) else (%_exp% -f:* %_wkbx% "%_kb%" %_Nol% && echo DONE. || call :_Warn "Failed extracting %_wkb%.cab files.")
<nul (set /p _msg=Extract %_wkb%.psf, please wait...)
if not exist "%_kb%\express.psf.cix.xml" (call :_Warn "express.psf.cix.xml file not found.")
%_tmp%\PSFExtractor.exe -v2 %_tmp%\%_wkb%.psf %_kb%\express.psf.cix.xml %_kb%\ %_Nol% && echo DONE. || call :_Warn "Failed extracting %_wkb%.psf files."
echo:
echo Everything is ready. Starting LCU modification...
ping 127.0.0.1 -n 3 >Nul
:_StartModding
echo:
Echo Starting Modding %_target%...
echo:
<nul (set /p _msg=Modding Service stack update...)
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSsu '%_fsu%' '%_source%' '%_target%'" && echo  DONE.
rem for 22000 EOS
if %_modbld% equ 22000 (goto :22000_only)
if exist "%ROOT%\%_modbld%\ModLCU.esd" (%wlib% extract "%ROOT%\%_modbld%\ModLCU.esd" 1 --dest-dir="%_sxs%" --no-acls --no-attributes --quiet %_Nol%)
<nul (set /p _msg=Modding %_target%-SPP-Components-Package...)
call :_getver "Security-SPP-Component-SKU-Enterprise-Package"
set "_modnew=Microsoft-Windows-%_target%-SPP-Components-Package~%_meds%~%_modver%"
call :_renmod "%_target%-SPP-Components-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpp '%_sxs%\%_modnew%.mum' '%_modver%' '%_sxs%'" && echo  DONE.
<nul (set /p _msg=Modding Editions-%_target%-Package...)
call :_getver "editions-professional-package"
set "_modnew=Microsoft-Windows-Editions-%_target%-Package~%_meds%~%_modver%"
call :_renmod "Editions-%_target%-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpp '%_sxs%\%_modnew%.mum' '%_modver%' '%_sxs%'" && echo  DONE.
<nul (set /p _msg=Modding Desktop-BCDTemplate-Client-Package...)
call :_getver "EditionPack-Professional-removable-Package"
set "_modnew=Microsoft-Windows-Desktop-BCDTemplate-Client-Package~%_meds%~%_modver%"
call :_renmod "Desktop-BCDTemplate-Client-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpp '%_sxs%\%_modnew%.mum' '%_modver%' '%_sxs%'" && echo  DONE.
<nul (set /p _msg=Modding Shell32-OEMDefaultAssociations-Legacy-Package...)
set "_modnew=Microsoft-Windows-Shell32-OEMDefaultAssociations-Legacy-Package~%_meds%~%_modver%"
call :_renmod "Shell32-OEMDefaultAssociations-Legacy-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpp '%_sxs%\%_modnew%.mum' '%_modver%' '%_sxs%'" && echo  DONE.
<nul (set /p _msg=Modding EditionSpecific-%_target%-Removable-Package...)
set "_modnew=Microsoft-Windows-EditionSpecific-%_target%-Removable-Package~%_meds%~%_modver%"
call :_renmod "EditionSpecific-%_target%-Removable-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpp '%_sxs%\%_modnew%.mum' '%_modver%' '%_sxs%'" && echo  DONE.
<nul (set /p _msg=Modding Branding-%_target%-Package...)
set "_modnew=Microsoft-Windows-Branding-%_target%-Package~%_meds%~%_modver%"
call :_renmod "Branding-%_target%-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpp '%_sxs%\%_modnew%.mum' '%_modver%' '%_sxs%'" && echo  DONE.
Xcopy /CHIERQY "%_sxs%" "%_kb%" %_Nol%
<nul (set /p _msg=Modding EditionSpecific-%_target%-WOW64-Package...)
call :_getver "editionspecific-professional-WOW64-package"
set "_modnew=Microsoft-Windows-EditionSpecific-%_target%-WOW64-Package~%_meds%~%_modver%"
For %%# in (%_kb%\*EditionSpecific-Professional-WOW64-Package~%_meds%~*.cat) do (copy /y "%%#" "%_sxs%\%_modnew%.cat" %_Nol%)
if exist "%_sxs%\%_modnew%.cat" (
call :_export ":%_modbld%_%_target%_specw\:.*" "%_sxs%\%_modnew%.mum" "ASCII" %_Nol%
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpec '%_sxs%\%_modnew%.mum' '%_modver%' '%_kb%'" && echo  DONE.
)
<nul (set /p _msg=Modding EditionSpecific-%_target%-Package...)
call :_getver "editionspecific-professional-package"
set "_modnew=Microsoft-Windows-EditionSpecific-%_target%-Package~%_meds%~%_modver%"
For %%# in (%_kb%\*editionspecific-professional-package~%_meds%~*.cat) do (copy /y "%%#" "%_sxs%\%_modnew%.cat" %_Nol%)
call :_export ":%_modbld%_%_target%_spec\:.*" "%_sxs%\%_modnew%.mum" "ASCII"
call :_renmod "EditionSpecific-%_target%-Package~%_meds%~" "%_sxs%"
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSpec '%_sxs%\%_modnew%.mum' '%_modver%' '%_kb%'" && echo DONE.
:22000_only
<nul (set /p _msg=Modding Microsoft-Windows-%_target%Edition...)
call :_getver "professionaledition"
set "_modnew=Microsoft-Windows-%_target%Edition~%_meds%~%_modver%"
for /f "tokens=* delims=" %%# in ('dir /b /a-d "%_kb%\*ProfessionalEdition~%_meds%~*.*" 2^>Nul') do (
  copy /y "%_kb%\%%#" "%_sxs%\%_modnew%%%~x#" %_Nol%
)
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModPro%_target% '%_sxs%\%_modnew%.mum' '%_modbld%'" && echo DONE.
Xcopy /CHIERQY "%_sxs%" "%_kb%" %_Nol%
<nul (set /p _msg=Modding %_target%edition-Wrapper and update.mum...)
call :_getver "ProfessionalEdition-Wrapper"
set "_modnew=Microsoft-Windows-%_target%Edition-Wrapper~%_meds%~%_modver%"
for /f "tokens=* delims=" %%# in ('dir /b /a-d "%_kb%\*ProfessionalEdition-Wrapper~%_meds%~*.*" 2^>Nul') do (
  copy /y "%_kb%\%%#" "%_tmp%\%_modnew%%%~x#" %_Nol%
)
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSsu '%_tmp%' 'Professional' '%_target%'" && echo DONE.
for %%# in (mum cat) do (move /y "%_tmp%\*.%%#" "%_kb%\" %_Nol%)
<nul (set /p _msg=Modding Package_for_RollupFix...)
copy /y "%_kb%\update.mum" "%_tmp%\" %_Nol%
set "0=%~f0"& powershell -nop -c "iex ([io.file]::ReadAllText($env:0) -split '[:]Mum_XML')[1];ModSsu '%_tmp%' '%_source%' '%_target%'" && echo DONE.
move /y "%_tmp%\*.mum" "%_kb%\" %_Nol%
if exist "%ROOT%\%_modbld%\update\%_ssu%.esd" (del /f /q "%ROOT%\%_modbld%\update\%_ssu%.esd")
if exist "%ROOT%\%_modbld%\update\%_wkb%.esd" (del /f /q "%ROOT%\%_modbld%\update\%_wkb%.esd")
if %_modbld% equ 22000 (if exist "%ROOT%\%_modbld%\ModLCU.esd" (%z7% x "%ROOT%\%_modbld%\ModLCU.esd" -o"%_kb%" -y %_Nol%))
echo:
if %_modbld% equ 25398 (
if not defined _secondtarg (
set "_source=ServerDatacenter"
set "_target=EnterpriseG"
set "_secondtarg=1"
goto :_StartModding
))
echo Modifications has been completed. Create update packages.
echo:
<nul (set /p _msg=Create SSU esd...)
if exist "%ROOT%\%_modbld%\update\%_ssu%.esd" (del /f /q "%ROOT%\%_modbld%\update\%_ssu%.esd")
%wlib% capture "%_fsu%" "%ROOT%\%_modbld%\update\%_ssu%.esd"  --solid --check --compress=LZMS "Edition Package" "Edition Package"
echo:
<nul (set /p _msg=Create LCU esd...)
if exist "%ROOT%\%_modbld%\update\%_wkb%.esd" (del /f /q "%ROOT%\%_modbld%\update\%_wkb%.esd")
%wlib% capture "%_kb%" "%ROOT%\%_modbld%\update\%_wkb%.esd"  --solid --check --compress=LZMS "Edition Package" "Edition Package"
echo:
echo Cleanup...
if exist "%ROOT%\%_modbld%\update\%_ssu%.esd" (rmdir /s /q "%_fsu%\" %_Nol%)
if exist "%ROOT%\%_modbld%\update\%_wkb%.esd" (rmdir /s /q "%_kb%\" "%_sxs%\" "%_tmp%\" %_Nol%)

:_End
Echo:
Echo FINISH..!!
<nul (set/p _bel=)
pause
(Goto) 2>Nul & Call "Bedi.cmd"
exit

:_Warn
Echo:
Echo:
Echo ==*^|ERROR:  %~1  ^|*==
Goto :_End

::Parameter: Limiter, Path, Encoding
:_export
Set "_trm=%~4"
If defined _trm (
set "0=%~f0"& powershell -nop -c "$f=[IO.File]::ReadAllText($env:0) -split '%~1'; [IO.File]::WriteAllText('%~2',$f[1].Trim(),[System.Text.Encoding]::%~3)"
) else (
set "0=%~f0"& powershell -nop -c "$f=[IO.File]::ReadAllText($env:0) -split '%~1'; [IO.File]::WriteAllText('%~2',$f[1].TrimStart(),[System.Text.Encoding]::%~3)"
)
Exit /b

:_getver
for /f %%# in ('dir /b /a-d "%_kb%\*%~1~%_meds%~*.*" 2^>Nul') do (
  for /f "tokens=4 delims=~" %%a in ('echo %%~n#') do (set "_modver=%%a")
)
exit /b

:_renmod
for /f %%# in ('dir /b /a-d "%~2\*%~1*.*" 2^>Nul') do (
ren "%~2\%%#" "%_modnew%%%~x#" %_Nol%
)
exit /b

:Mum_XML
Function NoBOM([String] $bomfl) {
  $Utf8NoBomEncoding = New-Object System.Text.UTF8Encoding($False)
  $MyFile = Get-Content $bomfl
  [System.IO.File]::WriteAllLines($bomfl, $MyFile, $Utf8NoBomEncoding)
}
Function ModSsu([String] $fldr, [String] $sourc, [String] $targt) {
  Get-ChildItem $fldr -Filter *.mum | ForEach-Object {
    if ($_ | Select-String -Pattern $sourc) {
      ($_ | Get-Content -Raw) -replace $sourc, $targt | Set-Content $_.FullName
    }
  }
  Remove-Variable * -EA SilentlyContinue
}
Function ModProEnterpriseS([String] $xmlFile, $builds) {
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
	NoBom "$xmlFile"
  } else { Write-Host -NoNewline "SKIP ~ Nothing to do." -f Red }
  
  Remove-Variable * -EA SilentlyContinue
}
Function ModProEnterpriseG([String] $xmlFile, $builds) {
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
	NoBom "$xmlFile"
  } else { Write-Host The $xmlFile NOT FOUND..!! -f Red }
  Remove-Variable * -EA SilentlyContinue
}
Function ModSpec([String] $xmlFile, [String] $modver, [String] $fldr) {
  if (test-path -path "$xmlFile") {
    $xml = [XML](Get-Content "$xmlFile")
	$asmIdent = $xml.assembly.assemblyIdentity
	$asmIdent.version = $modver
	$_pref = $asmIdent.publicKeyToken + "~" + $asmIdent.processorArchitecture + "~~"
	$updates = $xml.assembly.package.update
	foreach ($update in $updates) {
	  $tfile = $fldr + "\" + $update.package.assemblyIdentity.name + "~" + $_pref
	  if ($anyfile=(Get-ChildItem -path "$tfile*.cat")) {
		$newver = ($anyfile.basename).split("~")[4]
		$update.package.assemblyIdentity.version = $newver
	  }
	}
    $xml.Save("$xmlFile")
	NoBom "$xmlFile"
  } else { Write-Host -NoNewline "SKIP ~ Nothing to do." -f Red }
  Remove-Variable * -EA SilentlyContinue
}
Function ModSpp([String] $xmlFile, [String] $modver, [String] $fldr) {
  if (test-path -path "$xmlFile") {
	$xml = [XML](Get-Content "$xmlFile")
	$asmIdent = $xml.assembly.assemblyIdentity
	$asmIdent.version = $modver
	$_pref = $asmIdent.publicKeyToken + "~" + $asmIdent.processorArchitecture + "~~"
	$updates = $xml.assembly.package.update
	foreach ($update in $updates) {
	  $tfile = $fldr + "\" + $update.package.assemblyIdentity.name + "~" + $_pref
	  if ($anyfile=(Get-ChildItem -path "$tfile*.*")) {
	    $update.package.assemblyIdentity.version = $modver
		ForEach($afile in $anyfile) {
		  $newext = "." + ($afile.name).split(".")[-1]
		  $newfile = ($afile.fullname).split("~")[0] + "~" + $_pref + $modver + $newext
		  Rename-Item $afile.fullname $newfile
		  if ($newext -eq '.mum') { ModSpp "$newfile" "$modver" "$fldr" }
		}
	  }
	}
    $xml.Save("$xmlFile")
	NoBom "$xmlFile"
  } else { Write-Host -NoNewline "SKIP ~ Nothing to do." -f Red }
  Remove-Variable * -EA SilentlyContinue
}
#:Mum_XML
::=========================================================================

:22621_EnterpriseS_spec:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionSpecific-EnterpriseS" releaseType="Feature Pack">
    <update name="6eda231703402c279ad1cf8b100b5992">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-Removable-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="87330264842f72d00f1cc3a60df19bd4">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OneCore-DeviceUpdateCenter-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7d11995d19a7920b70cc9fa2f1aa1b9c">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Onecore-Identity-TenantRestrictions-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="18ec9db0673131ab38f0654d918c828e">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OSClient-Layer-Data-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="a7a4552c498461bca17a22eaee0dd7e4">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Branding-EnterpriseS-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="017db9b3d2d84badc56c70bbd5452e05">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Desktop-BCDTemplate-Client-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="cd8a864ab5044d09b084fa9680957d99">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Editions-EnterpriseS-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="98c427031d6e8f08f3ea736adfc8d516">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EnterpriseS-SPP-Components-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6886bfd5ec66bb4a84ac818243090d47">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Help-ClientUA-Client-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="30216fc1cfad5e362e77e795e233ca54">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Internet-Browser-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7457ec4d9a4c63d10b077b50059da579">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Management-SecureAssessment-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="bd05998382fed353ddc98886622c25af">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-SenseClient-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="05ac32b8f74aa7fa3de7f4110f6ff5e7">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Shell32-OEMDefaultAssociations-Legacy-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="cebf643f3a5dfd3a662bebf5c18b55b1">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Networking-MPSSVC-Rules-EnterpriseEdition-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="f0c5a871707fc2ab953b10ba553ae3b9">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Server-Help-Package.ClientEnterprise" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="4b09b442caf9e09b264375c2a75aca38">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="UserExperience-Desktop-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:22621_EnterpriseS_spec:

:22621_EnterpriseS_specw:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64" releaseType="Feature Pack">
    <update name="6d0207f250b0d7cde21bae6beef3e628">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64-removable-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="81636af2bfa2270c02f2dfc5506993ec">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Onecore-Identity-TenantRestrictions-WOW64-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="9f9a00af65e738ee3409ef252b5bbb01">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Management-SecureAssessment-WOW64-Package" version="10.0.22621.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:22621_EnterpriseS_specw:

:25398_EnterpriseS_specw:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64" releaseType="Feature Pack">
    <update name="6d0207f250b0d7cde21bae6beef3e628">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-WOW64-removable-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="81636af2bfa2270c02f2dfc5506993ec">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Onecore-Identity-TenantRestrictions-WOW64-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="9f9a00af65e738ee3409ef252b5bbb01">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Management-SecureAssessment-WOW64-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:25398_EnterpriseS_specw:

:25398_EnterpriseS_spec:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionSpecific-EnterpriseS" releaseType="Feature Pack">
    <update name="b3900add401afaf859afaaa449b29a7c">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseS-removable-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="87330264842f72d00f1cc3a60df19bd4">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OneCore-DeviceUpdateCenter-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7d11995d19a7920b70cc9fa2f1aa1b9c">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Onecore-Identity-TenantRestrictions-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="18ec9db0673131ab38f0654d918c828e">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OSClient-Layer-Data-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="a7a4552c498461bca17a22eaee0dd7e4">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Branding-EnterpriseS-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="017db9b3d2d84badc56c70bbd5452e05">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Desktop-BCDTemplate-Client-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="cd8a864ab5044d09b084fa9680957d99">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Editions-EnterpriseS-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="98c427031d6e8f08f3ea736adfc8d516">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EnterpriseS-SPP-Components-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6886bfd5ec66bb4a84ac818243090d47">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Help-ClientUA-Client-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="30216fc1cfad5e362e77e795e233ca54">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Internet-Browser-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7457ec4d9a4c63d10b077b50059da579">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Management-SecureAssessment-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="bd05998382fed353ddc98886622c25af">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-SenseClient-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="05ac32b8f74aa7fa3de7f4110f6ff5e7">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Shell32-OEMDefaultAssociations-Legacy-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="cebf643f3a5dfd3a662bebf5c18b55b1">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Networking-MPSSVC-Rules-EnterpriseEdition-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="f0c5a871707fc2ab953b10ba553ae3b9">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Server-Help-Package.ClientEnterprise" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="4b09b442caf9e09b264375c2a75aca38">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="UserExperience-Desktop-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:25398_EnterpriseS_spec:

:25398_EnterpriseG_spec:
<?xml version="1.0" encoding="utf-8" standalone="yes"?>
<assembly xmlns="urn:schemas-microsoft-com:asm.v3" manifestVersion="1.0" copyright="Copyright (c) Microsoft Corporation. All Rights Reserved.">
  <assemblyIdentity name="Microsoft-Windows-EditionSpecific-EnterpriseG-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
  <package identifier="Microsoft-Windows-EditionSpecific-EnterpriseG" releaseType="Feature Pack">
    <update name="3cb935db73961f2956db7a3764ce718f">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Client-License-Platform-Powershell-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="18ec9db0673131ab38f0654d918c828e">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-OSClient-Layer-Data-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="96a2bbd48ace00308cb4928fe8bcdcd0">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Accessories-Migration-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="33d88559267c4dc588374bd3793c8814">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Branding-EnterpriseG-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="017db9b3d2d84badc56c70bbd5452e05">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Desktop-BCDTemplate-Client-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="46ca6683372e8890316bd6826084d7e5">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Editions-EnterpriseG-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6291746d719ccdd78867d9f2169151e6">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-EnterpriseG-SPP-Components-Package" version="10.0.26100.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="6886bfd5ec66bb4a84ac818243090d47">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Help-ClientUA-Client-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="7457ec4d9a4c63d10b077b50059da579">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Microsoft-Windows-Management-SecureAssessment-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="cebf643f3a5dfd3a662bebf5c18b55b1">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Networking-MPSSVC-Rules-EnterpriseEdition-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="f0c5a871707fc2ab953b10ba553ae3b9">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="Server-Help-Package.ClientEnterprise" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
    <update name="4b09b442caf9e09b264375c2a75aca38">
      <package contained="false" integrate="hidden">
        <assemblyIdentity name="UserExperience-Desktop-Package" version="10.0.25398.1" processorArchitecture="amd64" language="neutral" buildType="release" publicKeyToken="31bf3856ad364e35" />
      </package>
    </update>
  </package>
</assembly>
:25398_EnterpriseG_spec:

