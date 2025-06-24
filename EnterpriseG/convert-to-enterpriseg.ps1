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

# 1. Create temp directory
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# 1. Extract original ISO
Write-Host "[+] Extracting ISO: $InputIso"
& "$FilesDir\7z.exe" x $InputIso -o"$TempDir\iso" -y | Out-Null

# 2. Mount/extract install.wim
$WimPath = Get-ChildItem -Path "$TempDir\iso\sources" -Filter "install.wim" | Select-Object -First 1
if (-not $WimPath) { throw "install.wim not found in ISO!" }
New-Item -ItemType Directory -Force -Path $MountDir | Out-Null
Write-Host "[+] Mounting install.wim"
dism /Mount-Wim /WimFile:"$($WimPath.FullName)" /Index:1 /MountDir:"$MountDir" | Out-Null

# 3. Copy debloat, activation, reg scripts
$SetupScripts = "$MountDir\Windows\Setup\Scripts"
New-Item -ItemType Directory -Force -Path $SetupScripts | Out-Null
Write-Host "[+] Copying debloat and activation scripts"
Copy-Item "$FilesDir\Scripts\SetupComplete.cmd" $SetupScripts -Force
Copy-Item "$FilesDir\Scripts\activate_kms38.cmd" $SetupScripts -Force
Copy-Item "$FilesDir\Scripts\RemoveEdge.cmd" $SetupScripts -Force
Copy-Item "$FilesDir\regedit.reg" $SetupScripts -Force

# 4. Patch edition, SKU (Fox Khang logic)
Write-Host "[+] Patching edition and SKU for EnterpriseG..."
$WimInfo = Get-WindowsImage -ImagePath $WimPath.FullName -Index 1
$Build = $WimInfo.Version
if ($Build -like "261*") {
    $SxsType = "24H2"
} elseif ($Build -like "22621*") {
    $SxsType = "Normal"
} else {
    $SxsType = "Legacy"
}
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
    (Get-Content $MumNew) -replace '10\\.0\\.22621\\.1', $Build | Set-Content $MumNew
}
if (Test-Path $CatOld) {
    Copy-Item $CatOld $CatNew -Force
}
$XmlPath = Join-Path $SxsTarget "1.xml"
if (Test-Path $XmlPath) {
    (Get-Content $XmlPath) -replace '10\\.0\\.22621\\.1', $Build | Set-Content $XmlPath
}
dism /image:$MountDir /apply-unattend:$SxsTarget\1.xml | Out-Null
$ProductKey = if ($Build -like "261*") { "FV469-WGNG4-YQP66-2B2HY-KD8YX" } else { "YYVX9-NTFWV-6MDM3-9PT4T-4M68B" }
dism /Image:$MountDir /Set-Edition:EnterpriseG /AcceptEula /ProductKey:$ProductKey | Out-Null

# 5. Unmount and commit changes to WIM
Write-Host "[+] Committing changes to install.wim"
dism /Unmount-Wim /MountDir:"$MountDir" /Commit | Out-Null

# 6. Repack to EnterpriseG ISO
if (-not $OutputIso) {
    $OutputIso = [System.IO.Path]::ChangeExtension($InputIso, '-enterpriseg.iso')
}
Write-Host "[+] Creating new ISO: $OutputIso"
& "$FilesDir\7z.exe" a -tiso $OutputIso "$TempDir\iso\*" | Out-Null

# 7. Clean up temp directory
Remove-Item -Recurse -Force $TempDir

Write-Host "[OK] Done! EnterpriseG ISO file: $OutputIso" 