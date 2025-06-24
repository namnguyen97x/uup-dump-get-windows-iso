#requires -RunAsAdministrator
param(
    [string]$InputIso = $(Get-ChildItem -Filter *.iso | Select-Object -First 1).FullName,
    [string]$OutputIso = ''
)

if (-not $InputIso -or !(Test-Path $InputIso)) {
    Write-Host "[ERROR] No ISO file found!" -ForegroundColor Red
    exit 1
}

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FilesDir = Join-Path $ScriptRoot 'files'
$TempDir = Join-Path $env:TEMP ("EnterpriseG-ISO-" + [guid]::NewGuid().ToString())
$IsoExtractDir = Join-Path $TempDir 'iso'
$MountDir = Join-Path $TempDir 'mount'

Write-Host "[INFO] Input ISO: $InputIso"
Write-Host "[INFO] Temp directory: $TempDir"

# 1. Extract ISO
New-Item -ItemType Directory -Force -Path $IsoExtractDir | Out-Null
& "$FilesDir\7z.exe" x $InputIso -o"$IsoExtractDir" -y | Out-Null

# 2. Find install.wim
$WimPath = Get-ChildItem -Path "$IsoExtractDir\sources" -Filter "install.wim" | Select-Object -First 1
if (-not $WimPath) { Write-Host "[ERROR] install.wim not found in ISO!"; exit 1 }

# 3. Mount WIM
New-Item -ItemType Directory -Force -Path $MountDir | Out-Null
Write-Host "[STEP] Mounting install.wim..."
dism /Mount-Wim /WimFile:"$($WimPath.FullName)" /Index:1 /MountDir:"$MountDir" | Out-Null

# 4. Patch/debloat/convert EnterpriseG (Fox Khang style)
# --- Debloat: Remove Edge, OneDrive, Copilot, Media Player, ...
Write-Host "[STEP] Debloating..."
Remove-Item "$MountDir\Program Files (x86)\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Program Files\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.ZuneMusic_8wekyb3d8bbwe" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.ZuneVideo_8wekyb3d8bbwe" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Program Files (x86)\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Program Files\Microsoft OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Users\Default\AppData\Local\Microsoft\OneDrive" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
# Debloat bổ sung từ Fox Khang
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.CBS_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.Copilot_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.AksMsixvc_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.ParentalControls_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.XGpuEjectDialog_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.PeopleExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.SecHealthUI_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.SecureAssessmentBrowser_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.XGpuEjectDialog_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.CallingShellApp_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.NarratorQuickStart_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.OOBENetworkCaptivePortal_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.OOBENetworkConnectionFlow_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.ParentalControls_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.PeopleExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.PinningConfirmationDialog_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.SecHealthUI_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.SecureAssessmentBrowser_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.ShellExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.StartMenuExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.XGpuEjectDialog_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.CallingShellApp_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.CloudExperienceHost_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.ContentDeliveryManager_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.NarratorQuickStart_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.OOBENetworkCaptivePortal_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Windows\SystemApps\Microsoft.Windows.OOBENetworkConnectionFlow_cw5n1h2txyewy" -Recurse -Force -ErrorAction SilentlyContinue
Write-Host "[STEP] Debloat done."

# --- Patch registry: bypass, OOBE, branding, ...
Write-Host "[STEP] Patching registry..."
reg load HKLM\TMP "$MountDir\Windows\System32\config\SYSTEM"
reg add "HKLM\TMP\Setup\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f
reg unload HKLM\TMP
reg load HKLM\TMP "$MountDir\Windows\System32\config\SOFTWARE"
reg add "HKLM\TMP\Microsoft\Windows NT\CurrentVersion" /v RegisteredOrganization /t REG_SZ /d "Produced by iamkudo" /f
reg add "HKLM\TMP\Microsoft\Windows\CurrentVersion\OOBE" /v BypassNRO /t REG_DWORD /d 1 /f
reg add "HKLM\TMP\Microsoft\Windows\CurrentVersion\OOBE" /v SkipMachineOOBE /t REG_DWORD /d 1 /f
reg add "HKLM\TMP\Microsoft\Windows\CurrentVersion\OOBE" /v SkipUserOOBE /t REG_DWORD /d 1 /f
# Patch bổ sung từ Fox Khang (Defender, Telemetry, Ads, Copilot, Widgets, ...)
reg add "HKLM\TMP\Microsoft\Windows NT\CurrentVersion" /v EditionSubManufacturer /t REG_SZ /d "Microsoft Corporation" /f
reg add "HKLM\TMP\Microsoft\Windows NT\CurrentVersion" /v EditionSubVersion /t REG_SZ /d "EnterpriseG" /f
reg add "HKLM\TMP\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "SettingsPageVisibility" /t REG_SZ /d "hide:activation;gaming-gamebar;gaming-gamedvr;gaming-gamemode;quietmomentsgame" /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v DisableAntiSpyware /t REG_DWORD /d 1 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v DisableAntiVirus /t REG_DWORD /d 1 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v DisableRealtimeMonitoring /t REG_DWORD /d 1 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v DisableSpecialRunningModes /t REG_DWORD /d 1 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v ServiceKeepAlive /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartup /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnBoot /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnLogon /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnStartup /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnShutdown /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnSleep /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnWake /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnResume /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnSuspend /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHibernate /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridBoot /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdown /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridSleep /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridResume /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridSuspend /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridHibernate /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridWake /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownResume /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownSuspend /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownHibernate /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownWake /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownShutdown /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownSleep /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownResume /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownSuspend /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownHibernate /t REG_DWORD /d 0 /f
reg add "HKLM\TMP\Policies\Microsoft\Windows Defender" /v AllowFastServiceStartupOnHybridShutdownWake /t REG_DWORD /d 0 /f
reg unload HKLM\TMP
Write-Host "[STEP] Registry patched."

# 5. Unmount and commit changes to WIM
Write-Host "[STEP] Committing changes to install.wim..."
dism /Unmount-Wim /MountDir:"$MountDir" /Commit | Out-Null
Write-Host "[STEP] Unmounted and committed install.wim."

# 5b. Optimize WIM và set image property
Write-Host "[STEP] Optimizing WIM..."
$Wimlib = "$FilesDir\wimlib-imagex.exe"
& $Wimlib optimize $WimPath.FullName | Out-Null
Write-Host "[STEP] Setting WIM image properties..."
& $Wimlib info $WimPath.FullName 1 --image-property NAME="Windows EnterpriseG" --image-property DESCRIPTION="Windows EnterpriseG" --image-property FLAGS="EnterpriseG" --image-property DISPLAYNAME="Windows EnterpriseG" --image-property DISPLAYDESCRIPTION="Windows EnterpriseG" | Out-Null

# 6. Build new ISO
if (-not $OutputIso) {
    $OutputIso = [System.IO.Path]::ChangeExtension($InputIso, '-EnterpriseG.iso')
}
Write-Host "[STEP] Building new ISO: $OutputIso"
$Oscdimg = "$FilesDir\oscdimg\oscdimg.exe"
$BootImg = "$FilesDir\oscdimg\etfsboot.com"
$EfiImg = "$FilesDir\oscdimg\efisys.bin"
& $Oscdimg -b$BootImg -u2 -h -m -lWIN_ENTG -bootdata:2#p0,e,b$BootImg#pEF,e,b$EfiImg "$IsoExtractDir" "$OutputIso"
Write-Host "[STEP] ISO created: $OutputIso"

# 7. Clean up
Write-Host "[STEP] Cleaning up temp directory: $TempDir"
Remove-Item -Recurse -Force $TempDir
Write-Host "[OK] Done! EnterpriseG ISO file: $OutputIso" 