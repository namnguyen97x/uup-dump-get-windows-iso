# Debloat Windows ISO - PowerShell Only
# Author: YourName
# Run as Administrator!

param(
    [string]$isoPath = "",
    [string]$winEdition = "",
    [string]$outputISO = ""
)

# 1. Mount ISO and copy contents
if (-not $isoPath) {
    Add-Type -AssemblyName System.Windows.Forms
    $dialog = New-Object System.Windows.Forms.OpenFileDialog
    $dialog.Filter = "ISO files (*.iso)|*.iso"
    $dialog.Title = "Select Windows ISO File"
    if ($dialog.ShowDialog() -eq [System.Windows.Forms.DialogResult]::OK) {
        $isoPath = $dialog.FileName
    } else {
        Write-Host "No ISO selected. Exiting." -ForegroundColor Red
        exit
    }
}
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

# 3. Debloat: Remove AppX, Capabilities, Features, OneDrive, Edge, etc.
$appx = @(
    "Microsoft.BingNews*", "Microsoft.BingWeather*", "Microsoft.549981C3F5F10*", "Microsoft.WindowsAlarms*",
    "Microsoft.WindowsFeedbackHub*", "Microsoft.GetHelp*", "Microsoft.Getstarted*", "Microsoft.WindowsMaps*",
    "Microsoft.WindowsCommunicationsapps*", "Microsoft.ZuneMusic*", "Microsoft.ZuneVideo*", "Microsoft.Xbox*",
    "Microsoft.People*", "Microsoft.YourPhone*", "Microsoft.SkypeApp*", "Microsoft.Todos*", "Microsoft.Wallet*"
)
foreach ($pattern in $appx) {
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

# 4. Registry Tweaks (ví dụ: tắt Telemetry, quảng cáo, bypass TPM...)
reg load HKLM\zSYSTEM "$mountdir\Windows\System32\config\SYSTEM"
reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f
reg add "HKLM\zSYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f
reg unload HKLM\zSYSTEM

# 5. Unmount & commit
Dismount-WindowsImage -Path $mountdir -Save

# 6. Tạo lại ISO (dùng oscdimg hoặc tool khác)
Write-Host "Debloat hoàn tất! Bạn có thể tạo lại ISO từ thư mục $dest." 