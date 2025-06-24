param(
    [Parameter(Mandatory=$true)]
    [string]$InputIso,
    [Parameter(Mandatory=$false)]
    [string]$OutputIso = ''
)

# Đường dẫn các tool và file cần thiết
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FilesDir = Join-Path $ScriptRoot 'files'
$TempDir = Join-Path $env:TEMP ("EnterpriseG-" + [guid]::NewGuid().ToString())
$MountDir = Join-Path $TempDir 'mount'

Write-Host "[INFO] Starting EnterpriseG conversion script"
Write-Host "[INFO] Temp directory: $TempDir"
Write-Host "[INFO] Script root: $ScriptRoot"
Write-Host "[INFO] Files directory: $FilesDir"

# 1. Create temp directory
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null
Write-Host "[STEP 1] Extracting ISO: $InputIso"
& "$FilesDir\7z.exe" x $InputIso -o"$TempDir\iso" -y | Out-Null
Write-Host "[STEP 1] ISO extracted to $TempDir\iso"

# 2. Mount/extract install.wim
$WimPath = Get-ChildItem -Path "$TempDir\iso\sources" -Filter "install.wim" | Select-Object -First 1
if (-not $WimPath) { throw "install.wim not found in ISO!" }
Write-Host "[STEP 2] Found install.wim: $($WimPath.FullName)"
New-Item -ItemType Directory -Force -Path $MountDir | Out-Null
Write-Host "[STEP 2] Mounting install.wim to $MountDir"
dism /Mount-Wim /WimFile:"$($WimPath.FullName)" /Index:1 /MountDir:"$MountDir" | Out-Null
Write-Host "[STEP 2] install.wim mounted"

# 3. Copy debloat, activation, reg scripts
$SetupScripts = "$MountDir\Windows\Setup\Scripts"
New-Item -ItemType Directory -Force -Path $SetupScripts | Out-Null
Write-Host "[STEP 3] Copying debloat and activation scripts to $SetupScripts"
Copy-Item "$FilesDir\Scripts\SetupComplete.cmd" $SetupScripts -Force
Copy-Item "$FilesDir\Scripts\activate_kms38.cmd" $SetupScripts -Force
Copy-Item "$FilesDir\Scripts\RemoveEdge.cmd" $SetupScripts -Force
Copy-Item "$FilesDir\regedit.reg" $SetupScripts -Force
Copy-Item "$FilesDir\bypass.reg" $SetupScripts -Force
Write-Host "[STEP 3] Scripts copied"

# 3b. Remove unwanted apps (Edge, Media Player, Copilot, OneDrive)
Write-Host "[STEP 3b] Removing Edge, Media Player, Copilot, OneDrive..."
Remove-Item "$MountDir\Program Files (x86)\Microsoft\Edge" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$MountDir\Program Files (x86)\Microsoft\EdgeWebView" -Recurse -Force -ErrorAction SilentlyContinue
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
Write-Host "[STEP 3b] Unwanted apps removed"

# 4. Patch edition, SKU (Fox Khang logic)
Write-Host "[STEP 4] Patching edition and SKU for EnterpriseG..."
$WimInfo = Get-WindowsImage -ImagePath $WimPath.FullName -Index 1
$Build = $WimInfo.Version
Write-Host "[STEP 4] Detected build: $Build"
if ($Build -like "261*") {
    $SxsType = "24H2"
} elseif ($Build -like "22621*") {
    $SxsType = "Normal"
} else {
    $SxsType = "Legacy"
}
Write-Host "[STEP 4] Using SXS type: $SxsType"
$SxsSource = Join-Path $FilesDir "sxs\$SxsType"
$SxsTarget = Join-Path $MountDir "sxs"
New-Item -ItemType Directory -Force -Path $SxsTarget | Out-Null
Copy-Item "$SxsSource\*" $SxsTarget -Recurse -Force
Write-Host "[STEP 4] SXS files copied"
$MumOld = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~10.0.22621.1.mum"
$CatOld = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~10.0.22621.1.cat"
$MumNew = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~$Build.mum"
$CatNew = Join-Path $SxsTarget "Microsoft-Windows-EnterpriseGEdition~31bf3856ad364e35~amd64~~$Build.cat"
if (Test-Path $MumOld) {
    Copy-Item $MumOld $MumNew -Force
    (Get-Content $MumNew) -replace '10\\.0\\.22621\\.1', $Build | Set-Content $MumNew
    Write-Host "[STEP 4] Patched .mum for build $Build"
}
if (Test-Path $CatOld) {
    Copy-Item $CatOld $CatNew -Force
    Write-Host "[STEP 4] Patched .cat for build $Build"
}
$XmlPath = Join-Path $SxsTarget "1.xml"
if (Test-Path $XmlPath) {
    (Get-Content $XmlPath) -replace '10\\.0\\.22621\\.1', $Build | Set-Content $XmlPath
    Write-Host "[STEP 4] Patched 1.xml for build $Build"
}
dism /image:$MountDir /apply-unattend:$SxsTarget\1.xml | Out-Null
Write-Host "[STEP 4] Applied unattend XML"
$ProductKey = if ($Build -like "261*") { "FV469-WGNG4-YQP66-2B2HY-KD8YX" } else { "YYVX9-NTFWV-6MDM3-9PT4T-4M68B" }
dism /Image:$MountDir /Set-Edition:EnterpriseG /AcceptEula /ProductKey:$ProductKey | Out-Null
Write-Host "[STEP 4] Set edition to EnterpriseG"

# 5. Unmount and commit changes to WIM
Write-Host "[STEP 5] Committing changes to install.wim"
dism /Unmount-Wim /MountDir:"$MountDir" /Commit | Out-Null
Write-Host "[STEP 5] Unmounted and committed install.wim"

# 6. Repack to EnterpriseG ISO
if (-not $OutputIso) {
    $OutputIso = [System.IO.Path]::ChangeExtension($InputIso, '-enterpriseg.iso')
}
Write-Host "[STEP 6] Creating new ISO: $OutputIso"
& "$FilesDir\7z.exe" a -tiso $OutputIso "$TempDir\iso\*" | Out-Null
Write-Host "[STEP 6] ISO created: $OutputIso"

# 7. Clean up temp directory
Write-Host "[STEP 7] Cleaning up temp directory: $TempDir"
Remove-Item -Recurse -Force $TempDir
Write-Host "[OK] Done! EnterpriseG ISO file: $OutputIso" 