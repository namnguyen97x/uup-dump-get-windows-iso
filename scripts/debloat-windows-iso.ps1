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
try {
    Mount-DiskImage -ImagePath $isoPath -ErrorAction Stop
    Write-Host "=== ĐÃ MOUNT ISO, BẮT ĐẦU COPY ==="
} catch {
    Write-Host "LỖI: Không mount được ISO! $_" -ForegroundColor Red
    exit 1
}

# 1. Mount ISO and copy contents
$dest = "$env:SystemDrive\WIDTemp\winlite"
if (Test-Path $dest) { Remove-Item $dest -Recurse -Force }
New-Item -ItemType Directory -Path $dest | Out-Null
$mount = Mount-DiskImage -ImagePath $isoPath -PassThru
$drive = ($mount | Get-Volume).DriveLetter + ":\"
robocopy $drive $dest /E /COPY:DAT /R:3 /W:5 /MT:8
Dismount-DiskImage -ImagePath $isoPath

# 2. Mount install.wim
$wim = Join-Path $dest "sources\install.wim"
$mountdir = "$env:SystemDrive\WIDTemp\mountdir"
if (Test-Path $mountdir) { Remove-Item $mountdir -Recurse -Force }
New-Item -ItemType Directory -Path $mountdir | Out-Null
$imageIndex = 1
if ($winEdition) {
    $info = dism /get-wiminfo /wimfile:$wim | Out-String
    $match = $info -split "`n" | Where-Object { $_ -match "Name\s*:\s*$winEdition" }
    if ($match) {
        $imageIndex = [regex]::Match($match, "Index\s*:\s*(\d+)").Groups[1].Value
    }
}
Mount-WindowsImage -ImagePath $wim -Index $imageIndex -Path $mountdir
Write-Host "=== BẮT ĐẦU MOUNT WIM ==="

# 3. Debloat: Remove AppX, Capabilities, Features, OneDrive, Edge, etc.
$appx = @(
    "Microsoft.BingNews*", "Microsoft.BingWeather*", "Microsoft.549981C3F5F10*", "Microsoft.WindowsAlarms*",
    "Microsoft.WindowsFeedbackHub*", "Microsoft.GetHelp*", "Microsoft.Getstarted*", "Microsoft.WindowsMaps*",
    "Microsoft.WindowsCommunicationsapps*", "Microsoft.ZuneMusic*", "Microsoft.ZuneVideo*", "Microsoft.Xbox*",
    "Microsoft.People*", "Microsoft.YourPhone*", "Microsoft.SkypeApp*", "Microsoft.Todos*", "Microsoft.Wallet*"
)
Write-Host "=== ĐÃ MOUNT WIM, BẮT ĐẦU DEBLOAT ==="
foreach ($pattern in $appx) {
    Write-Host "Đang xóa AppX: $pattern"
    Get-ProvisionedAppxPackage -Path $mountdir | Where-Object { $_.PackageName -like $pattern } | ForEach-Object {
        Remove-ProvisionedAppxPackage -Path $mountdir -PackageName $_.PackageName
    }
}
# Remove OneDrive
Remove-Item "$mountdir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
Remove-Item "$mountdir\Windows\SysWOW64\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
# Remove Edge
Remove-Item "$mountdir\Program Files\Microsoft\Edge*" -Recurse -Force -ErrorAction SilentlyContinue
Remove-Item "$mountdir\Program Files (x86)\Microsoft\Edge*" -Recurse -Force -ErrorAction SilentlyContinue

# Remove Capabilities
$capabilities = @(
    "App.StepsRecorder*", "Language.Handwriting*", "Language.OCR*", "Language.Speech*", "Language.TextToSpeech*",
    "Microsoft.Windows.WordPad*", "MathRecognizer*", "Media.WindowsMediaPlayer*", "Microsoft.Windows.PowerShell.ISE*"
)
foreach ($cap in $capabilities) {
    Get-WindowsCapability -Path $mountdir | Where-Object { $_.Name -like $cap } | ForEach-Object {
        Remove-WindowsCapability -Path $mountdir -Name $_.Name
    }
}

# Remove Features/Packages
$features = @(
    "Microsoft-Windows-InternetExplorer-Optional-Package*", "Microsoft-Windows-LanguageFeatures-Handwriting-*",
    "Microsoft-Windows-LanguageFeatures-OCR-*", "Microsoft-Windows-LanguageFeatures-Speech-*",
    "Microsoft-Windows-LanguageFeatures-TextToSpeech-*", "Microsoft-Windows-WordPad-FoD-Package*",
    "Microsoft-Windows-MediaPlayer-Package*", "Microsoft-Windows-TabletPCMath-Package*",
    "Microsoft-Windows-StepsRecorder-Package*"
)
foreach ($pkg in $features) {
    Get-WindowsPackage -Path $mountdir | Where-Object { $_.PackageName -like $pkg } | ForEach-Object {
        Remove-WindowsPackage -Path $mountdir -PackageName $_.PackageName
    }
}
Write-Host "=== ĐÃ DEBLOAT, BẮT ĐẦU PATCH REGISTRY ==="
# 4. Registry Tweaks (ví dụ: tắt Telemetry, quảng cáo, bypass TPM...)
reg load HKLM\zSYSTEM "$mountdir\Windows\System32\config\SYSTEM"
reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f
reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f
reg unload HKLM\zSYSTEM
Write-Host "=== UNMOUNT WIM ==="

# 5. Unmount & commit
Dismount-WindowsImage -Path $mountdir -Save
Write-Host "=== ĐÃ UNMOUNT, BẮT ĐẦU TẠO ISO ==="

# 6. Tạo lại ISO (dùng oscdimg hoặc tool khác)
Write-Host "Debloat hoàn tất! Bạn có thể tạo lại ISO từ thư mục $dest."
Write-Host "=== ĐÃ HOÀN THÀNH DEBLOAT ===" 