# Debloat Windows ISO - PowerShell Only
# Author: YourName
# Run as Administrator!

param(
    [string]$isoPath = "",
    [string]$winEdition = "",
    [string]$outputISO = ""
)

Write-Host "=== DEBUG: Script Parameters ==="
Write-Host "isoPath: '$isoPath'"
Write-Host "winEdition: '$winEdition'"
Write-Host "outputISO: '$outputISO'"

# Check if running as Administrator
if (-NOT ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Host "LỖI: Script này cần chạy với quyền Administrator!" -ForegroundColor Red
    exit 1
}

# If no isoPath provided, try to find windows.iso in current directory
if (-not $isoPath) {
    Write-Host "Không có isoPath được cung cấp, tìm file windows.iso trong thư mục hiện tại..."
    if (Test-Path "windows.iso") {
        $isoPath = "windows.iso"
        Write-Host "Đã tìm thấy windows.iso"
    } else {
        Write-Host "LỖI: Không tìm thấy file ISO và không có isoPath được cung cấp!" -ForegroundColor Red
        Write-Host "Các file trong thư mục hiện tại:" -ForegroundColor Yellow
        Get-ChildItem | ForEach-Object { Write-Host "  $($_.Name)" }
        exit 1
    }
}

Write-Host "=== BẮT ĐẦU MOUNT ISO ==="
if (!(Test-Path $isoPath)) {
    Write-Host "LỖI: Không tìm thấy file ISO $isoPath" -ForegroundColor Red
    Write-Host "Thư mục hiện tại: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Các file trong thư mục:" -ForegroundColor Yellow
    Get-ChildItem | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}
$size = (Get-Item $isoPath).Length / 1GB
Write-Host "File ISO: $isoPath, Dung lượng: $([math]::Round($size,2)) GB"

# 1. Mount ISO and copy contents
$dest = "$env:SystemDrive\WIDTemp\winlite"
if (Test-Path $dest) { 
    Write-Host "Xóa thư mục temp cũ: $dest"
    Remove-Item $dest -Recurse -Force 
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null

Write-Host "Mount ISO để copy nội dung..."
try {
    $mount = Mount-DiskImage -ImagePath $isoPath -PassThru -ErrorAction Stop
    $drive = ($mount | Get-Volume).DriveLetter + ":\"
    Write-Host "ISO đã mount tại: $drive"
    
    Write-Host "Copy nội dung ISO..."
    robocopy $drive $dest /E /COPY:DAT /R:3 /W:5 /MT:8
    if ($LASTEXITCODE -gt 7) {
        Write-Host "LỖI: Robocopy failed với exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "Unmount ISO..."
    Dismount-DiskImage -ImagePath $isoPath
    Write-Host "=== ĐÃ COPY XONG ISO ==="
} catch {
    Write-Host "LỖI: Không mount được ISO! $_" -ForegroundColor Red
    exit 1
}

# 2. Check if install.wim exists
$wim = Join-Path $dest "sources\install.wim"
if (-not (Test-Path $wim)) {
    Write-Host "LỖI: Không tìm thấy install.wim tại: $wim" -ForegroundColor Red
    Write-Host "Các file trong sources:" -ForegroundColor Yellow
    if (Test-Path (Join-Path $dest "sources")) {
        Get-ChildItem (Join-Path $dest "sources") | ForEach-Object { Write-Host "  $($_.Name)" }
    }
    exit 1
}

Write-Host "Tìm thấy install.wim: $wim"

# 3. Mount install.wim
$mountdir = "$env:SystemDrive\WIDTemp\mountdir"
if (Test-Path $mountdir) { 
    Write-Host "Xóa thư mục mount cũ: $mountdir"
    Remove-Item $mountdir -Recurse -Force 
}
New-Item -ItemType Directory -Path $mountdir -Force | Out-Null

$imageIndex = 1
if ($winEdition) {
    Write-Host "Tìm Windows edition: $winEdition"
    try {
        $info = dism /get-wiminfo /wimfile:$wim | Out-String
        $match = $info -split "`n" | Where-Object { $_ -match "Name\s*:\s*$winEdition" }
        if ($match) {
            $imageIndex = [regex]::Match($match, "Index\s*:\s*(\d+)").Groups[1].Value
            Write-Host "Tìm thấy edition tại index: $imageIndex"
        }
    } catch {
        Write-Host "Không tìm thấy edition, sử dụng index 1" -ForegroundColor Yellow
    }
}

Write-Host "Mount WIM image index $imageIndex..."
try {
    Mount-WindowsImage -ImagePath $wim -Index $imageIndex -Path $mountdir -ErrorAction Stop
    Write-Host "=== ĐÃ MOUNT WIM THÀNH CÔNG ==="
} catch {
    Write-Host "LỖI: Không mount được WIM! $_" -ForegroundColor Red
    exit 1
}

# 4. Debloat: Remove AppX, Capabilities, Features, OneDrive, Edge, etc.
$appx = @(
    "Microsoft.BingNews*", "Microsoft.BingWeather*", "Microsoft.549981C3F5F10*", "Microsoft.WindowsAlarms*",
    "Microsoft.WindowsFeedbackHub*", "Microsoft.GetHelp*", "Microsoft.Getstarted*", "Microsoft.WindowsMaps*",
    "Microsoft.WindowsCommunicationsapps*", "Microsoft.ZuneMusic*", "Microsoft.ZuneVideo*", "Microsoft.Xbox*",
    "Microsoft.People*", "Microsoft.YourPhone*", "Microsoft.SkypeApp*", "Microsoft.Todos*", "Microsoft.Wallet*"
)
Write-Host "=== BẮT ĐẦU DEBLOAT ==="

# Remove AppX packages
Write-Host "Xóa AppX packages..."
foreach ($pattern in $appx) {
    Write-Host "  Đang xóa AppX: $pattern"
    try {
        Get-ProvisionedAppxPackage -Path $mountdir | Where-Object { $_.PackageName -like $pattern } | ForEach-Object {
            Remove-ProvisionedAppxPackage -Path $mountdir -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "    Cảnh báo: Không thể xóa $pattern" -ForegroundColor Yellow
    }
}

# Remove OneDrive
Write-Host "Xóa OneDrive..."
try {
    Remove-Item "$mountdir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
    Remove-Item "$mountdir\Windows\SysWOW64\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "  Cảnh báo: Không thể xóa OneDrive" -ForegroundColor Yellow
}

# Remove Edge
Write-Host "Xóa Edge..."
try {
    Remove-Item "$mountdir\Program Files\Microsoft\Edge*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$mountdir\Program Files (x86)\Microsoft\Edge*" -Recurse -Force -ErrorAction SilentlyContinue
} catch {
    Write-Host "  Cảnh báo: Không thể xóa Edge" -ForegroundColor Yellow
}

# Remove Capabilities
Write-Host "Xóa Windows Capabilities..."
$capabilities = @(
    "App.StepsRecorder*", "Language.Handwriting*", "Language.OCR*", "Language.Speech*", "Language.TextToSpeech*",
    "Microsoft.Windows.WordPad*", "MathRecognizer*", "Media.WindowsMediaPlayer*", "Microsoft.Windows.PowerShell.ISE*"
)
foreach ($cap in $capabilities) {
    Write-Host "  Đang xóa Capability: $cap"
    try {
        Get-WindowsCapability -Path $mountdir | Where-Object { $_.Name -like $cap } | ForEach-Object {
            Remove-WindowsCapability -Path $mountdir -Name $_.Name -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "    Cảnh báo: Không thể xóa $cap" -ForegroundColor Yellow
    }
}

# Remove Features/Packages
Write-Host "Xóa Windows Features..."
$features = @(
    "Microsoft-Windows-InternetExplorer-Optional-Package*", "Microsoft-Windows-LanguageFeatures-Handwriting-*",
    "Microsoft-Windows-LanguageFeatures-OCR-*", "Microsoft-Windows-LanguageFeatures-Speech*",
    "Microsoft-Windows-LanguageFeatures-TextToSpeech*", "Microsoft-Windows-WordPad-FoD-Package*",
    "Microsoft-Windows-MediaPlayer-Package*", "Microsoft-Windows-TabletPCMath-Package*",
    "Microsoft-Windows-StepsRecorder-Package*"
)
foreach ($pkg in $features) {
    Write-Host "  Đang xóa Feature: $pkg"
    try {
        Get-WindowsPackage -Path $mountdir | Where-Object { $_.PackageName -like $pkg } | ForEach-Object {
            Remove-WindowsPackage -Path $mountdir -PackageName $_.PackageName -ErrorAction SilentlyContinue
        }
    } catch {
        Write-Host "    Cảnh báo: Không thể xóa $pkg" -ForegroundColor Yellow
    }
}

Write-Host "=== ĐÃ DEBLOAT XONG, BẮT ĐẦU PATCH REGISTRY ==="

# 5. Registry Tweaks (ví dụ: tắt Telemetry, quảng cáo, bypass TPM...)
Write-Host "Patch Registry..."
try {
    reg load HKLM\zSYSTEM "$mountdir\Windows\System32\config\SYSTEM"
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f
    reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f
    reg unload HKLM\zSYSTEM
    Write-Host "Registry đã được patch thành công"
} catch {
    Write-Host "Cảnh báo: Không thể patch registry" -ForegroundColor Yellow
}

Write-Host "=== UNMOUNT WIM ==="

# 6. Unmount & commit
try {
    Dismount-WindowsImage -Path $mountdir -Save -ErrorAction Stop
    Write-Host "=== ĐÃ UNMOUNT WIM THÀNH CÔNG ==="
} catch {
    Write-Host "LỖI: Không thể unmount WIM! $_" -ForegroundColor Red
    exit 1
}

Write-Host "=== ĐÃ HOÀN THÀNH DEBLOAT ==="
Write-Host "Debloat hoàn tất! File WIM đã được cập nhật tại: $wim"
Write-Host "Bạn có thể tạo lại ISO từ thư mục: $dest" 