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
reg unload HKLM\TMP
Write-Host "[STEP] Registry patched."

# --- Patch SKU/Edition (Fox Khang logic)
Write-Host "[STEP] Patching SKU/Edition..."
$WimInfo = Get-WindowsImage -ImagePath $WimPath.FullName -Index 1
$Build = $WimInfo.Version
if ($Build -like "261*") { $SxsType = "24H2" } elseif ($Build -like "22621*") { $SxsType = "Normal" } else { $SxsType = "Legacy" }
$SxsSource = Join-Path $FilesDir "sxs\$SxsType"
$SxsTarget = Join-Path $MountDir "sxs"
New-Item -ItemType Directory -Force -Path $SxsTarget | Out-Null
Copy-Item "$SxsSource\*" $SxsTarget -Recurse -Force
$MumOld = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~10.0.22621.1.mum"
$CatOld = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~10.0.22621.1.cat"
$MumNew = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~$Build.mum"
$CatNew = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~$Build.cat"
if (Test-Path $MumOld) {
    Copy-Item $MumOld $MumNew -Force
    (Get-Content $MumNew) -replace '10\.0\.22621\.1', $Build | Set-Content $MumNew
}
if (Test-Path $CatOld) {
    Copy-Item $CatOld $CatNew -Force
}
$XmlPath = Join-Path $SxsTarget "1.xml"
if (Test-Path $XmlPath) {
    (Get-Content $XmlPath) -replace '10\.0\.22621\.1', $Build | Set-Content $XmlPath
}
dism /image:$MountDir /apply-unattend:$SxsTarget\1.xml | Out-Null
$ProductKey = if ($Build -like "261*") { "FV469-WGNG4-YQP66-2B2HY-KD8YX" } else { "YYVX9-NTFWV-6MDM3-9PT4T-4M68B" }
dism /Image:$MountDir /Set-Edition:EnterpriseG /AcceptEula /ProductKey:$ProductKey | Out-Null
Write-Host "[STEP] SKU/Edition patched."

# 5. Unmount and commit changes to WIM
Write-Host "[STEP] Committing changes to install.wim..."
dism /Unmount-Wim /MountDir:"$MountDir" /Commit | Out-Null
Write-Host "[STEP] Unmounted and committed install.wim."

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