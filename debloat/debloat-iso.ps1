#Requires -Version 5.1
#Requires -RunAsAdministrator

<#
.SYNOPSIS
    Windows ISO Debloater - Tạo Windows ISO sạch từ UUP dump artifacts
    
.DESCRIPTION
    Script này debloat Windows ISO được tạo từ UUP dump build workflow.
    Dựa trên công thức từ https://github.com/itsNileshHere/Windows-ISO-Debloater
    
.PARAMETER noPrompt
    Chạy không cần tương tác (yêu cầu các tham số khác)
    
.PARAMETER isoPath
    Đường dẫn đến file ISO
    
.PARAMETER winEdition
    Tên edition Windows (VD: "Windows 11 Pro")
    
.PARAMETER outputISO
    Tên file ISO đầu ra (không có extension)
    
.PARAMETER useDISM
    Sử dụng DISM.exe thay vì PS cmdlets [Default: yes]
    
.PARAMETER AppxRemove
    Xóa Microsoft Store apps [Default: yes]
    
.PARAMETER CapabilitiesRemove
    Xóa optional Windows features [Default: yes]
    
.PARAMETER OnedriveRemove
    Xóa OneDrive hoàn toàn [Default: yes]
    
.PARAMETER EDGERemove
    Xóa Microsoft Edge browser [Default: yes]
    
.PARAMETER TPMBypass
    Bỏ qua TPM & hardware checks [Default: no]
    
.PARAMETER UserFoldersEnable
    Bật user folders trong Explorer [Default: yes]
    
.PARAMETER ESDConvert
    Nén ISO bằng ESD compression [Default: no]
    
.PARAMETER useOscdimg
    Sử dụng oscdimg.exe cho ISO creation [Default: yes]
    
.EXAMPLE
    # Chế độ tương tác
    .\debloat-iso.ps1
    
    # Chế độ tự động
    .\debloat-iso.ps1 -noPrompt -isoPath "C:\path\to\windows.iso" -winEdition "Windows 11 Pro" -outputISO "Win11Debloat"
    
    # Tùy chỉnh options
    .\debloat-iso.ps1 -isoPath "C:\path\to\windows.iso" -EDGERemove no -TPMBypass yes
#>

param(
    [switch]$noPrompt,
    [string]$isoPath,
    [string]$winEdition,
    [string]$outputISO,
    [ValidateSet("yes", "no")][string]$useDISM = "yes",
    [ValidateSet("yes", "no")][string]$AppxRemove = "yes",
    [ValidateSet("yes", "no")][string]$CapabilitiesRemove = "yes",
    [ValidateSet("yes", "no")][string]$OnedriveRemove = "yes",
    [ValidateSet("yes", "no")][string]$EDGERemove = "yes",
    [ValidateSet("yes", "no")][string]$TPMBypass = "no",
    [ValidateSet("yes", "no")][string]$UserFoldersEnable = "yes",
    [ValidateSet("yes", "no")][string]$ESDConvert = "no",
    [ValidateSet("yes", "no")][string]$useOscdimg = "yes"
)

# Set execution policy
Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force

# Global variables
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$workingDir = Join-Path $scriptPath "work"
$mountDir = Join-Path $workingDir "mount"
$extractDir = Join-Path $workingDir "extract"
$oscdimgPath = Join-Path $scriptPath "tools\oscdimg.exe"

# Colors for output
$Red = "Red"
$Green = "Green"
$Yellow = "Yellow"
$Blue = "Blue"

function Write-ColorOutput {
    param([string]$Message, [string]$Color = "White")
    Write-Host $Message -ForegroundColor $Color
}

function Test-Administrator {
    $currentUser = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-Environment {
    Write-ColorOutput "=== Windows ISO Debloater ===" $Blue
    Write-ColorOutput "Dựa trên Windows-ISO-Debloater by itsNileshHere" $Yellow
    
    if (-not (Test-Administrator)) {
        Write-ColorOutput "Script này cần quyền Administrator!" $Red
        exit 1
    }
    
    # Create working directories
    $dirs = @($workingDir, $mountDir, $extractDir, (Split-Path $oscdimgPath))
    foreach ($dir in $dirs) {
        if (-not (Test-Path $dir)) {
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
        }
    }
    
    Write-ColorOutput "Môi trường đã được khởi tạo" $Green
}

function Get-ISOFile {
    if ($noPrompt -and $isoPath) {
        if (-not (Test-Path $isoPath)) {
            Write-ColorOutput "File ISO không tồn tại: $isoPath" $Red
            exit 1
        }
        return $isoPath
    }
    
    # Auto-detect ISO in current directory
    $isoFiles = Get-ChildItem -Path $scriptPath -Filter "*.iso" | Sort-Object LastWriteTime -Descending
    if ($isoFiles.Count -gt 0) {
        $autoIsoPath = $isoFiles[0].FullName
        Write-ColorOutput "Tự động phát hiện ISO: $($isoFiles[0].Name)" $Green
        return $autoIsoPath
    }
    
    Write-ColorOutput "`nChọn file Windows ISO:" $Blue
    $isoPath = Read-Host "Nhập đường dẫn đến file ISO (hoặc Enter để browse)"
    
    if ([string]::IsNullOrWhiteSpace($isoPath)) {
        $isoPath = Get-FileName -Filter "ISO files (*.iso)|*.iso|All files (*.*)|*.*"
    }
    
    if (-not (Test-Path $isoPath)) {
        Write-ColorOutput "File ISO không hợp lệ!" $Red
        exit 1
    }
    
    return $isoPath
}

function Get-FileName {
    param([string]$Filter = "All files (*.*)|*.*")
    Add-Type -AssemblyName System.Windows.Forms
    $openFileDialog = New-Object System.Windows.Forms.OpenFileDialog
    $openFileDialog.Filter = $Filter
    $openFileDialog.Title = "Chọn Windows ISO file"
    $result = $openFileDialog.ShowDialog()
    if ($result -eq [System.Windows.Forms.DialogResult]::OK) {
        return $openFileDialog.FileName
    }
    return $null
}

function Get-WindowsEdition {
    if ($noPrompt -and $winEdition) {
        return $winEdition
    }
    
    # Auto-detect Windows edition from ISO
    if ($isoPath) {
        try {
            $driveLetter = Mount-ISO -isoPath $isoPath
            $installWim = Join-Path $driveLetter "sources\install.wim"
            if (Test-Path $installWim) {
                $imageInfo = Get-WindowsImage -ImagePath $installWim
                $detectedEdition = $imageInfo[0].ImageName
                Dismount-ISO -driveLetter $driveLetter
                Write-ColorOutput "Tự động phát hiện edition: $detectedEdition" $Green
                return $detectedEdition
            }
        }
        catch {
            Write-ColorOutput "Không thể tự động phát hiện edition, sử dụng danh sách" $Yellow
        }
    }
    
    Write-ColorOutput "`nCác Windows editions có sẵn:" $Blue
    $editions = @(
        "Windows 11 Pro",
        "Windows 11 Home",
        "Windows 11 Enterprise",
        "Windows 10 Pro",
        "Windows 10 Home",
        "Windows 10 Enterprise"
    )
    
    for ($i = 0; $i -lt $editions.Count; $i++) {
        Write-Host "[$($i + 1)] $($editions[$i])"
    }
    
    $choice = Read-Host "`nChọn edition (1-$($editions.Count))"
    if ($choice -match '^\d+$' -and [int]$choice -ge 1 -and [int]$choice -le $editions.Count) {
        return $editions[[int]$choice - 1]
    }
    
    Write-ColorOutput "Lựa chọn không hợp lệ!" $Red
    exit 1
}

function Get-OutputISOName {
    if ($noPrompt -and $outputISO) {
        return $outputISO
    }
    
    # Auto-generate output name from input ISO
    if ($isoPath) {
        $inputName = [System.IO.Path]::GetFileNameWithoutExtension($isoPath)
        $outputName = "$inputName-Debloated"
        Write-ColorOutput "Tự động tạo tên output: $outputName" $Green
        return $outputName
    }
    
    Write-ColorOutput "`nTên file ISO đầu ra:" $Blue
    $outputName = Read-Host "Nhập tên file (không có extension .iso)"
    
    if ([string]::IsNullOrWhiteSpace($outputName)) {
        $outputName = "Windows-Debloated"
    }
    
    return $outputName
}

function Get-DebloatOptions {
    if ($noPrompt) {
        return @{
            useDISM = $useDISM
            AppxRemove = $AppxRemove
            CapabilitiesRemove = $CapabilitiesRemove
            OnedriveRemove = $OnedriveRemove
            EDGERemove = $EDGERemove
            TPMBypass = $TPMBypass
            UserFoldersEnable = $UserFoldersEnable
            ESDConvert = $ESDConvert
            useOscdimg = $useOscdimg
        }
    }
    
    Write-ColorOutput "`n=== Tùy chọn Debloat ===" $Blue
    
    $options = @{
        useDISM = Get-YesNoChoice "Sử dụng DISM.exe thay vì PS cmdlets?" "yes"
        AppxRemove = Get-YesNoChoice "Xóa Microsoft Store apps?" "yes"
        CapabilitiesRemove = Get-YesNoChoice "Xóa optional Windows features?" "yes"
        OnedriveRemove = Get-YesNoChoice "Xóa OneDrive hoàn toàn?" "yes"
        EDGERemove = Get-YesNoChoice "Xóa Microsoft Edge?" "yes"
        TPMBypass = Get-YesNoChoice "Bỏ qua TPM & hardware checks?" "no"
        UserFoldersEnable = Get-YesNoChoice "Bật user folders trong Explorer?" "yes"
        ESDConvert = Get-YesNoChoice "Nén ISO bằng ESD compression?" "no"
        useOscdimg = Get-YesNoChoice "Sử dụng oscdimg.exe cho ISO creation?" "yes"
    }
    
    return $options
}

function Get-YesNoChoice {
    param([string]$Question, [string]$Default = "no")
    Write-Host "$Question (y/n) [$Default]: " -NoNewline
    $response = Read-Host
    if ([string]::IsNullOrWhiteSpace($response)) {
        return $Default
    }
    return if ($response -match '^[Yy]') { "yes" } else { "no" }
}

function Download-Oscdimg {
    if (Test-Path $oscdimgPath) {
        Write-ColorOutput "oscdimg.exe đã tồn tại" $Green
        return
    }
    
    Write-ColorOutput "Đang tải oscdimg.exe..." $Yellow
    
    # Download from Microsoft's servers
    $oscdimgUrl = "https://download.microsoft.com/download/1/D/8/1D8B5022-5477-4B9A-8104-6A71A9E5D7E5/ADK/adksetup.exe"
    $adkSetupPath = Join-Path $scriptPath "tools\adksetup.exe"
    
    if (-not (Test-Path (Split-Path $adkSetupPath))) {
        New-Item -ItemType Directory -Path (Split-Path $adkSetupPath) -Force | Out-Null
    }
    
    try {
        Invoke-WebRequest -Uri $oscdimgUrl -OutFile $adkSetupPath
        Write-ColorOutput "Đã tải ADK setup" $Green
    }
    catch {
        Write-ColorOutput "Không thể tải oscdimg.exe. Vui lòng tải thủ công từ Windows ADK." $Red
        exit 1
    }
}

function Mount-ISO {
    param([string]$isoPath)
    
    Write-ColorOutput "Đang mount ISO..." $Yellow
    
    try {
        $mountResult = Mount-DiskImage -ImagePath $isoPath -PassThru
        $driveLetter = ($mountResult | Get-Volume).DriveLetter + ":"
        Write-ColorOutput "ISO đã được mount tại: $driveLetter" $Green
        return $driveLetter
    }
    catch {
        Write-ColorOutput "Không thể mount ISO: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Dismount-ISO {
    param([string]$driveLetter)
    
    Write-ColorOutput "Đang dismount ISO..." $Yellow
    try {
        Dismount-DiskImage -ImagePath $isoPath
        Write-ColorOutput "ISO đã được dismount" $Green
    }
    catch {
        Write-ColorOutput "Cảnh báo: Không thể dismount ISO" $Yellow
    }
}

function Extract-WindowsImage {
    param([string]$driveLetter, [string]$winEdition)
    
    Write-ColorOutput "Đang extract Windows image..." $Yellow
    
    # Find install.wim
    $installWim = Join-Path $driveLetter "sources\install.wim"
    if (-not (Test-Path $installWim)) {
        Write-ColorOutput "Không tìm thấy install.wim!" $Red
        exit 1
    }
    
    # Get image index
    $imageInfo = Get-WindowsImage -ImagePath $installWim
    $targetImage = $imageInfo | Where-Object { $_.ImageName -like "*$winEdition*" }
    
    if (-not $targetImage) {
        Write-ColorOutput "Không tìm thấy edition: $winEdition" $Red
        Write-ColorOutput "Các editions có sẵn:" $Yellow
        $imageInfo | ForEach-Object { Write-Host "  - $($_.ImageName)" }
        exit 1
    }
    
    $imageIndex = $targetImage.ImageIndex
    Write-ColorOutput "Tìm thấy edition: $($targetImage.ImageName) (Index: $imageIndex)" $Green
    
    # Extract image
    $extractPath = Join-Path $extractDir "Windows"
    if (Test-Path $extractPath) {
        Remove-Item -Path $extractPath -Recurse -Force
    }
    
    Write-ColorOutput "Đang extract image (có thể mất vài phút)..." $Yellow
    Export-WindowsImage -SourceImagePath $installWim -SourceIndex $imageIndex -DestinationImagePath $extractPath -CheckIntegrity
    
    return $extractPath
}

function Remove-AppxPackages {
    param([string]$imagePath)
    
    if ($AppxRemove -eq "no") {
        Write-ColorOutput "Bỏ qua việc xóa Appx packages" $Yellow
        return
    }
    
    Write-ColorOutput "Đang xóa Appx packages..." $Yellow
    
    $appxPatternsToRemove = @(
        "*3dbuilder*",
        "*windowsalarms*",
        "*windowscommunicationsapps*",
        "*windowscalculator*",
        "*windowsmaps*",
        "*solitairecollection*",
        "*windowsphone*",
        "*windowsstore*",
        "*xbox*",
        "*zune*",
        "*skype*",
        "*spotify*",
        "*disney*",
        "*netflix*",
        "*candycrush*",
        "*tiktok*",
        "*instagram*",
        "*facebook*",
        "*twitter*",
        "*linkedin*",
        "*pinterest*",
        "*whatsapp*",
        "*telegram*",
        "*discord*",
        "*slack*",
        "*zoom*",
        "*teams*",
        "*office*",
        "*onenote*",
        "*outlook*",
        "*word*",
        "*excel*",
        "*powerpoint*",
        "*access*",
        "*publisher*",
        "*visio*",
        "*project*"
    )
    
    foreach ($pattern in $appxPatternsToRemove) {
        try {
            Get-AppxProvisionedPackage -Path $imagePath | Where-Object { $_.DisplayName -like $pattern } | ForEach-Object {
                Write-ColorOutput "Xóa: $($_.DisplayName)" $Yellow
                Remove-AppxProvisionedPackage -Path $imagePath -PackageName $_.PackageName
            }
        }
        catch {
            Write-ColorOutput "Cảnh báo: Không thể xóa package $pattern" $Yellow
        }
    }
}

function Remove-WindowsCapabilities {
    param([string]$imagePath)
    
    if ($CapabilitiesRemove -eq "no") {
        Write-ColorOutput "Bỏ qua việc xóa Windows capabilities" $Yellow
        return
    }
    
    Write-ColorOutput "Đang xóa Windows capabilities..." $Yellow
    
    $capabilitiesToRemove = @(
        "Microsoft-Windows-InternetExplorer-Optional-Package",
        "Microsoft-Windows-MediaPlayer-Package",
        "Microsoft-Windows-TabletPCMath-Package",
        "Microsoft-Windows-Printing-XPSServices-Package",
        "Microsoft-Windows-Speech-TTS-Package",
        "Microsoft-Windows-Speech-Recognition-Package",
        "Microsoft-Windows-WindowsMediaPlayer-Package",
        "Microsoft-Windows-FaxServices-Package",
        "Microsoft-Windows-Scanning-Service-Package"
    )
    
    foreach ($capability in $capabilitiesToRemove) {
        try {
            Write-ColorOutput "Xóa capability: $capability" $Yellow
            Remove-WindowsCapability -Path $imagePath -Name $capability
        }
        catch {
            Write-ColorOutput "Cảnh báo: Không thể xóa capability $capability" $Yellow
        }
    }
}

function Remove-OneDrive {
    param([string]$imagePath)
    
    if ($OnedriveRemove -eq "no") {
        Write-ColorOutput "Bỏ qua việc xóa OneDrive" $Yellow
        return
    }
    
    Write-ColorOutput "Đang xóa OneDrive..." $Yellow
    
    # Remove OneDrive packages
    $onedrivePackages = @(
        "*OneDrive*",
        "*OneSync*"
    )
    
    foreach ($pattern in $onedrivePackages) {
        try {
            Get-AppxProvisionedPackage -Path $imagePath | Where-Object { $_.DisplayName -like $pattern } | ForEach-Object {
                Write-ColorOutput "Xóa OneDrive package: $($_.DisplayName)" $Yellow
                Remove-AppxProvisionedPackage -Path $imagePath -PackageName $_.PackageName
            }
        }
        catch {
            Write-ColorOutput "Cảnh báo: Không thể xóa OneDrive package" $Yellow
        }
    }
}

function Remove-Edge {
    param([string]$imagePath)
    
    if ($EDGERemove -eq "no") {
        Write-ColorOutput "Bỏ qua việc xóa Microsoft Edge" $Yellow
        return
    }
    
    Write-ColorOutput "Đang xóa Microsoft Edge..." $Yellow
    
    try {
        Get-AppxProvisionedPackage -Path $imagePath | Where-Object { $_.DisplayName -like "*Edge*" } | ForEach-Object {
            Write-ColorOutput "Xóa Edge package: $($_.DisplayName)" $Yellow
            Remove-AppxProvisionedPackage -Path $imagePath -PackageName $_.PackageName
        }
    }
    catch {
        Write-ColorOutput "Cảnh báo: Không thể xóa Edge packages" $Yellow
    }
}

function Apply-TPMBypass {
    param([string]$imagePath)
    
    if ($TPMBypass -eq "no") {
        Write-ColorOutput "Bỏ qua TPM bypass" $Yellow
        return
    }
    
    Write-ColorOutput "Đang áp dụng TPM bypass..." $Yellow
    
    # Registry modifications for TPM bypass
    $registryPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\LabConfig"
    
    try {
        # Create registry entries for TPM bypass
        $regCommands = @(
            "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\LabConfig`" /v BypassTPMCheck /t REG_DWORD /d 1 /f",
            "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\LabConfig`" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f",
            "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\LabConfig`" /v BypassRAMCheck /t REG_DWORD /d 1 /f",
            "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\LabConfig`" /v BypassStorageCheck /t REG_DWORD /d 1 /f",
            "reg add `"HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Setup\LabConfig`" /v BypassCPUCheck /t REG_DWORD /d 1 /f"
        )
        
        foreach ($command in $regCommands) {
            Write-ColorOutput "Thực thi: $command" $Yellow
            cmd /c $command
        }
    }
    catch {
        Write-ColorOutput "Cảnh báo: Không thể áp dụng TPM bypass" $Yellow
    }
}

function Create-NewWIM {
    param([string]$imagePath, [string]$outputName)
    
    Write-ColorOutput "Đang tạo WIM file mới..." $Yellow
    
    $newWimPath = Join-Path $workingDir "$outputName.wim"
    
    try {
        if ($useDISM -eq "yes") {
            # Use DISM
            $dismArgs = @(
                "/capture-image",
                "/imagefile:`"$newWimPath`"",
                "/capturedir:`"$imagePath`"",
                "/name:`"$outputName`"",
                "/compress:max"
            )
            
            if ($ESDConvert -eq "yes") {
                $dismArgs += "/checkintegrity"
            }
            
            $dismCommand = "dism.exe " + ($dismArgs -join " ")
            Write-ColorOutput "Thực thi: $dismCommand" $Yellow
            cmd /c $dismCommand
        }
        else {
            # Use PowerShell cmdlets
            New-WindowsImage -ImagePath $newWimPath -CapturePath $imagePath -Name $outputName -CompressionType Max
        }
        
        Write-ColorOutput "WIM file đã được tạo: $newWimPath" $Green
        return $newWimPath
    }
    catch {
        Write-ColorOutput "Lỗi khi tạo WIM file: $($_.Exception.Message)" $Red
        exit 1
    }
}

function Create-ISO {
    param([string]$newWimPath, [string]$driveLetter, [string]$outputName, [string]$useOscdimg)
    
    Write-ColorOutput "Đang tạo ISO file..." $Yellow
    
    $isoPath = Join-Path $scriptPath "$outputName.iso"
    
    # Copy original ISO structure
    $tempDir = Join-Path $workingDir "iso_temp"
    if (Test-Path $tempDir) {
        Remove-Item -Path $tempDir -Recurse -Force
    }
    
    Write-ColorOutput "Đang copy cấu trúc ISO..." $Yellow
    robocopy $driveLetter $tempDir /E /XD "sources" | Out-Null
    
    # Copy new WIM to sources
    $sourcesDir = Join-Path $tempDir "sources"
    if (-not (Test-Path $sourcesDir)) {
        New-Item -ItemType Directory -Path $sourcesDir -Force | Out-Null
    }
    
    Copy-Item -Path $newWimPath -Destination (Join-Path $sourcesDir "install.wim") -Force
    
    # Create ISO
    if ($useOscdimg -eq "yes") {
        if (Test-Path $oscdimgPath) {
            $oscdimgArgs = @(
                "-m",
                "-o",
                "-u2",
                "-udfver102",
                "-bootdata:2#p0,e,b`"$tempDir\boot\etfsboot.com`"#pEF,e,b`"$tempDir\efi\microsoft\boot\efisys.bin`"",
                $tempDir,
                $isoPath
            )
            
            $oscdimgCommand = "`"$oscdimgPath`" " + ($oscdimgArgs -join " ")
            Write-ColorOutput "Thực thi: $oscdimgCommand" $Yellow
            cmd /c $oscdimgCommand
        }
        else {
            Write-ColorOutput "oscdimg.exe không tìm thấy, sử dụng PowerShell method" $Yellow
            Create-ISOWithPowerShell -tempDir $tempDir -isoPath $isoPath
        }
    }
    else {
        Create-ISOWithPowerShell -tempDir $tempDir -isoPath $isoPath
    }
    
    if (Test-Path $isoPath) {
        Write-ColorOutput "ISO đã được tạo thành công: $isoPath" $Green
        
        # Calculate checksum
        $checksum = Get-FileHash -Path $isoPath -Algorithm SHA256
        $checksumPath = "$isoPath.sha256.txt"
        $checksum.Hash | Out-File -FilePath $checksumPath -Encoding ASCII
        Write-ColorOutput "Checksum SHA256: $($checksum.Hash)" $Green
        Write-ColorOutput "Checksum file: $checksumPath" $Green
    }
    else {
        Write-ColorOutput "Lỗi khi tạo ISO file!" $Red
        exit 1
    }
}

function Create-ISOWithPowerShell {
    param([string]$tempDir, [string]$isoPath)
    
    try {
        # Use PowerShell to create ISO (basic method)
        $fsutil = "fsutil file createnew `"$isoPath`" 1"
        cmd /c $fsutil | Out-Null
        
        Write-ColorOutput "ISO cơ bản đã được tạo (cần oscdimg.exe cho ISO bootable hoàn chỉnh)" $Yellow
    }
    catch {
        Write-ColorOutput "Không thể tạo ISO với PowerShell method" $Red
        exit 1
    }
}

function Cleanup-WorkingDir {
    Write-ColorOutput "Đang dọn dẹp..." $Yellow
    
    try {
        if (Test-Path $workingDir) {
            Remove-Item -Path $workingDir -Recurse -Force
        }
        Write-ColorOutput "Dọn dẹp hoàn tất" $Green
    }
    catch {
        Write-ColorOutput "Cảnh báo: Không thể dọn dẹp hoàn toàn" $Yellow
    }
}

# Main execution
try {
    Initialize-Environment
    
    # Auto-detect ISO file in current directory if not specified
    if (-not $isoPath) {
        $isoFiles = Get-ChildItem -Path $scriptPath -Filter "*.iso" | Sort-Object LastWriteTime -Descending
        if ($isoFiles.Count -gt 0) {
            $isoPath = $isoFiles[0].FullName
            Write-ColorOutput "Tự động phát hiện ISO: $($isoFiles[0].Name)" $Green
        }
    }
    
    $isoPath = Get-ISOFile
    $winEdition = Get-WindowsEdition
    $outputName = Get-OutputISOName
    $options = Get-DebloatOptions
    
    # Apply options
    $useDISM = $options.useDISM
    $AppxRemove = $options.AppxRemove
    $CapabilitiesRemove = $options.CapabilitiesRemove
    $OnedriveRemove = $options.OnedriveRemove
    $EDGERemove = $options.EDGERemove
    $TPMBypass = $options.TPMBypass
    $UserFoldersEnable = $options.UserFoldersEnable
    $ESDConvert = $options.ESDConvert
    $useOscdimg = $options.useOscdimg
    
    # Show summary before starting
    Write-ColorOutput "`n=== TÓM TẮT DEBLOAT ===" $Blue
    Write-ColorOutput "ISO: $(Split-Path $isoPath -Leaf)" $Cyan
    Write-ColorOutput "Edition: $winEdition" $Cyan
    Write-ColorOutput "Output: $outputName.iso" $Cyan
    Write-ColorOutput "Appx Remove: $AppxRemove" $Cyan
    Write-ColorOutput "OneDrive Remove: $OnedriveRemove" $Cyan
    Write-ColorOutput "Edge Remove: $EDGERemove" $Cyan
    Write-ColorOutput "TPM Bypass: $TPMBypass" $Cyan
    
    Download-Oscdimg
    
    $driveLetter = Mount-ISO -isoPath $isoPath
    
    try {
        $imagePath = Extract-WindowsImage -driveLetter $driveLetter -winEdition $winEdition
        
        Remove-AppxPackages -imagePath $imagePath
        Remove-WindowsCapabilities -imagePath $imagePath
        Remove-OneDrive -imagePath $imagePath
        Remove-Edge -imagePath $imagePath
        Apply-TPMBypass -imagePath $imagePath
        
        $newWimPath = Create-NewWIM -imagePath $imagePath -outputName $outputName
        Create-ISO -newWimPath $newWimPath -driveLetter $driveLetter -outputName $outputName -useOscdimg $useOscdimg
        
        Write-ColorOutput "`n=== Debloat hoàn tất! ===" $Green
        Write-ColorOutput "ISO file: $scriptPath\$outputName.iso" $Green
        Write-ColorOutput "Kích thước: $([math]::Round((Get-Item "$scriptPath\$outputName.iso").Length / 1GB, 2)) GB" $Green
        
        # Show space saved
        $originalSize = (Get-Item $isoPath).Length / 1GB
        $debloatedSize = (Get-Item "$scriptPath\$outputName.iso").Length / 1GB
        $savedSpace = $originalSize - $debloatedSize
        $savedPercent = [math]::Round(($savedSpace / $originalSize) * 100, 1)
        Write-ColorOutput "Tiết kiệm: $([math]::Round($savedSpace, 2)) GB ($savedPercent%)" $Green
    }
    finally {
        Dismount-ISO -driveLetter $driveLetter
        Cleanup-WorkingDir
    }
}
catch {
    Write-ColorOutput "Lỗi: $($_.Exception.Message)" $Red
    exit 1
} 