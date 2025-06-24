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

# 1b. Copy unattend.xml (tiny11builder style) vào thư mục gốc ISO nếu có file mẫu
$Unattend = Join-Path $FilesDir 'unattend.xml'
if (Test-Path $Unattend) {
    Copy-Item $Unattend -Destination $IsoExtractDir -Force
    Write-Host "[STEP] Copied unattend.xml to ISO root."
}

# 2. Find install.wim
$WimPath = Get-ChildItem -Path "$IsoExtractDir\sources" -Filter "install.wim" | Select-Object -First 1
if (-not $WimPath) { Write-Host "[ERROR] install.wim not found in ISO!"; exit 1 }

# Kiểm tra số lượng index trong install.wim
$WimInfo = dism /Get-WimInfo /WimFile:"$($WimPath.FullName)" | Out-String
$Indexes = ($WimInfo -split "Index : ") | Where-Object { $_ -match "^\d+" } | ForEach-Object { ($_ -split "\r?\n")[0].Trim() }
if ($Indexes.Count -gt 1) {
    Write-Host "[INFO] install.wim có nhiều index: $($Indexes -join ", ")"
    $TargetIndex = 1 # Có thể sửa thành tham số đầu vào nếu muốn chọn index khác
    Write-Host "[INFO] Sẽ debloat index: $TargetIndex"
} else {
    $TargetIndex = 1
}

# 3. Mount WIM
New-Item -ItemType Directory -Force -Path $MountDir | Out-Null
Write-Host "[STEP] Mounting install.wim..."
dism /Mount-Wim /WimFile:"$($WimPath.FullName)" /Index:$TargetIndex /MountDir:"$MountDir" | Out-Null
if (!(Test-Path $MountDir)) {
    Write-Host "[ERROR] Mount WIM failed!" -ForegroundColor Red
    exit 1
}

# 4. Patch/debloat/convert EnterpriseG (tiny11builder style)
Write-Host "[STEP] Debloating (tiny11builder style)..."

# Remove AppX/Provisioned Packages bằng DISM
$TinyAppxPackages = @(
    "Microsoft.MicrosoftEdge_8wekyb3d8bbwe",
    "MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy",
    "MicrosoftWindows.Client.Copilot_cw5n1h2txyewy",
    "Microsoft.Windows.Cortana_cw5n1h2txyewy",
    "Microsoft.WindowsCamera_8wekyb3d8bbwe",
    "Microsoft.Clipchamp_8wekyb3d8bbwe"
)
foreach ($pkg in $TinyAppxPackages) {
    Write-Host "[TINY11] Removing AppX (DISM): $pkg"
    dism /Image:"$MountDir" /Remove-ProvisionedAppxPackage /PackageName:$pkg | Out-Null
}

# Remove các folder hệ thống và manifest
$TinyFolders = @(
    "$MountDir\Windows\SystemApps\Microsoft.MicrosoftEdge_8wekyb3d8bbwe",
    "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.WebExperience_cw5n1h2txyewy",
    "$MountDir\Windows\SystemApps\MicrosoftWindows.Client.Copilot_cw5n1h2txyewy",
    "$MountDir\Windows\SystemApps\Microsoft.Windows.Cortana_cw5n1h2txyewy",
    "$MountDir\Windows\SystemApps\Microsoft.WindowsCamera_8wekyb3d8bbwe",
    "$MountDir\Windows\SystemApps\Microsoft.Clipchamp_8wekyb3d8bbwe"
)
foreach ($folder in $TinyFolders) {
    if (Test-Path $folder) {
        try {
            Remove-Item $folder -Recurse -Force -ErrorAction Stop
            Write-Host "[TINY11] Removed: $folder"
        } catch {
            Write-Host "[TINY11][WARN] Failed to remove: $folder" -ForegroundColor Yellow
        }
    } else {
        Write-Host "[TINY11][INFO] Not found (skip): $folder"
    }
}
# Xóa manifest liên quan
$ManifestFiles = Get-ChildItem "$MountDir\Windows\SystemApps" -Filter "*.manifest" -Recurse -ErrorAction SilentlyContinue
foreach ($mf in $ManifestFiles) {
    try {
        Remove-Item $mf.FullName -Force -ErrorAction Stop
        Write-Host "[TINY11] Removed manifest: $($mf.FullName)"
    } catch {
        Write-Host "[TINY11][WARN] Failed to remove manifest: $($mf.FullName)" -ForegroundColor Yellow
    }
}

# Remove Feature on Demand (ví dụ QuickAssist)
dism /Image:"$MountDir" /Remove-Capability /CapabilityName:App.Support.QuickAssist~~~~0.0.1.0 | Out-Null

# Patch registry block update app
reg load HKLM\TMP "$MountDir\Windows\System32\config\SOFTWARE"
reg add "HKLM\TMP\Microsoft\Windows\CurrentVersion\Policies\Explorer" /v "NoAutoInstallUpdate" /t REG_DWORD /d 1 /f
reg unload HKLM\TMP

Write-Host "[STEP] Debloat (tiny11builder) done."

# 5. Unmount and commit changes to WIM
Write-Host "[STEP] Committing changes to install.wim..."
dism /Unmount-Wim /MountDir:"$MountDir" /Commit | Out-Null
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Commit WIM failed!" -ForegroundColor Red
    exit 1
}
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

# DEBUG: In đường dẫn các file boot sector
Write-Host "[DEBUG] BootImg: $BootImg"
Write-Host "[DEBUG] EfiImg: $EfiImg"
Write-Host "[DEBUG] Oscdimg: $Oscdimg"
Write-Host "[DEBUG] OutputIso: $OutputIso"
Write-Host "[DEBUG] IsoExtractDir: $IsoExtractDir"
if (!(Test-Path $BootImg)) { Write-Host "[ERROR] BootImg not found at $BootImg!" -ForegroundColor Red; exit 1 }
if (!(Test-Path $EfiImg)) { Write-Host "[ERROR] EfiImg not found at $EfiImg!" -ForegroundColor Red; exit 1 }
if (!(Test-Path $Oscdimg)) { Write-Host "[ERROR] Oscdimg not found at $Oscdimg!" -ForegroundColor Red; exit 1 }

# Thử mở file boot sector để kiểm tra quyền truy cập
try {
    $null = Get-Content $BootImg -ErrorAction Stop
    $null = Get-Content $EfiImg -ErrorAction Stop
} catch {
    Write-Host "[ERROR] Cannot access boot sector files! $_" -ForegroundColor Red
    exit 1
}

& $Oscdimg -b$BootImg -u2 -h -m -lWIN_ENTG -bootdata:2#p0,e,b$BootImg#pEF,e,b$EfiImg "$IsoExtractDir" "$OutputIso"
if ($LASTEXITCODE -ne 0) {
    Write-Host "[ERROR] Failed to build ISO!" -ForegroundColor Red
    exit 1
}
Write-Host "[STEP] ISO created: $OutputIso"

# 7. Clean up
Write-Host "[STEP] Cleaning up temp directory: $TempDir"
Remove-Item -Recurse -Force $TempDir
Write-Host "[OK] Done! EnterpriseG ISO file: $OutputIso" 