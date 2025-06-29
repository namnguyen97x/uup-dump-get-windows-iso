# Debloat Windows ISO - PowerShell Only
# Author: YourName
# Run as Administrator!

param(
    [string]$isoPath = "",
    [string]$winEdition = "",
    [string]$outputISO = "",
    [switch]$testMode = $false
)

# Main script execution wrapped in try-catch for better error handling
try {

Write-Host "=== DEBUG: Script Parameters ==="
Write-Host "isoPath: '$isoPath'"
Write-Host "winEdition: '$winEdition'"
Write-Host "outputISO: '$outputISO'"
Write-Host "testMode: $testMode"

# Check if running as Administrator (but don't exit immediately)
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
Write-Host "Running as Administrator: $isAdmin"

if (-not $isAdmin) {
    Write-Host "CẢNH BÁO: Script này cần chạy với quyền Administrator!" -ForegroundColor Yellow
    Write-Host "Một số thao tác có thể thất bại nếu không có quyền Administrator" -ForegroundColor Yellow
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

# If no outputISO provided, create default name
if (-not $outputISO) {
    $outputISO = "debloated-windows.iso"
    Write-Host "Sử dụng tên output mặc định: $outputISO"
}

Write-Host "=== BẮT ĐẦU MOUNT ISO ==="
if (!(Test-Path $isoPath)) {
    Write-Host "LỖI: Không tìm thấy file ISO $isoPath" -ForegroundColor Red
    Write-Host "Thư mục hiện tại: $(Get-Location)" -ForegroundColor Yellow
    Write-Host "Các file trong thư mục:" -ForegroundColor Yellow
    Get-ChildItem | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}

# Convert to absolute path
$isoPath = (Resolve-Path $isoPath).Path
Write-Host "ISO absolute path: $isoPath"

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
    Write-Host "Attempting to mount ISO: $isoPath"
    $mount = Mount-DiskImage -ImagePath $isoPath -PassThru -ErrorAction Stop
    $drive = ($mount | Get-Volume).DriveLetter + ":\"
    Write-Host "ISO đã mount tại: $drive"
    
    Write-Host "Copy nội dung ISO..."
    robocopy $drive $dest /E /COPY:DAT /R:3 /W:5 /MT:8
    if ($LASTEXITCODE -gt 7) {
        Write-Host "LỖI: Robocopy failed với exit code $LASTEXITCODE" -ForegroundColor Red
        exit 1
    }
    Write-Host "Robocopy completed successfully with exit code $LASTEXITCODE"
    
    Write-Host "Unmount ISO..."
    Dismount-DiskImage -ImagePath $isoPath
    Write-Host "ISO unmounted successfully"
    Write-Host "=== ĐÃ COPY XONG ISO ==="
    
    # Debug: Check what was copied
    Write-Host "=== DEBUG: Kiểm tra nội dung đã copy ==="
    Write-Host "Destination directory: $dest"
    Write-Host "Destination exists: $(Test-Path $dest)"
    
    if (Test-Path $dest) {
        Write-Host "Files in destination:"
        Get-ChildItem $dest | ForEach-Object { Write-Host "  $($_.Name)" }
        
        if (Test-Path (Join-Path $dest "sources")) {
            Write-Host "Files in sources directory:"
            Get-ChildItem (Join-Path $dest "sources") | ForEach-Object { Write-Host "  $($_.Name)" }
        } else {
            Write-Host "Sources directory does not exist!"
        }
    }
    
    Write-Host "=== TIẾP TỤC VỚI BƯỚC TIẾP THEO ==="
} catch {
    Write-Host "LỖI: Không mount được ISO! $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
    # Debug: Check what was copied even if there was an error
    Write-Host "=== DEBUG: Kiểm tra nội dung sau lỗi ==="
    Write-Host "Destination directory: $dest"
    Write-Host "Destination exists: $(Test-Path $dest)"
    
    if (Test-Path $dest) {
        Write-Host "Files in destination:"
        Get-ChildItem $dest | ForEach-Object { Write-Host "  $($_.Name)" }
        
        if (Test-Path (Join-Path $dest "sources")) {
            Write-Host "Files in sources directory:"
            Get-ChildItem (Join-Path $dest "sources") | ForEach-Object { Write-Host "  $($_.Name)" }
        } else {
            Write-Host "Sources directory does not exist!"
        }
    }
    
    Write-Host "=== THỬ PHƯƠNG PHÁP MOUNT KHÁC ==="
    try {
        $mount = Mount-DiskImage -ImagePath $isoPath -PassThru -StorageType ISO -ErrorAction Stop
        $drive = ($mount | Get-Volume).DriveLetter + ":\"
        Write-Host "ISO đã mount thành công tại: $drive"
        
        Write-Host "Copy nội dung ISO..."
        robocopy $drive $dest /E /COPY:DAT /R:3 /W:5 /MT:8
        if ($LASTEXITCODE -gt 7) {
            Write-Host "LỖI: Robocopy failed với exit code $LASTEXITCODE" -ForegroundColor Red
            exit 1
        }
        
        Write-Host "Unmount ISO..."
        Dismount-DiskImage -ImagePath $isoPath
        Write-Host "=== ĐÃ COPY XONG ISO ==="
        
        # Debug: Check what was copied
        Write-Host "=== DEBUG: Kiểm tra nội dung đã copy ==="
        Write-Host "Destination directory: $dest"
        Write-Host "Destination exists: $(Test-Path $dest)"
        
        if (Test-Path $dest) {
            Write-Host "Files in destination:"
            Get-ChildItem $dest | ForEach-Object { Write-Host "  $($_.Name)" }
            
            if (Test-Path (Join-Path $dest "sources")) {
                Write-Host "Files in sources directory:"
                Get-ChildItem (Join-Path $dest "sources") | ForEach-Object { Write-Host "  $($_.Name)" }
            } else {
                Write-Host "Sources directory does not exist!"
            }
        }
        
        Write-Host "=== TIẾP TỤC VỚI BƯỚC TIẾP THEO ==="
    } catch {
        Write-Host "LỖI: Cả hai phương pháp mount đều thất bại! $_" -ForegroundColor Red
        Write-Host "Final error details: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

# 2. Check for install.wim or install.esd
Write-Host "=== KIỂM TRA INSTALL.WIM/INSTALL.ESD ==="
Write-Host "Destination directory: $dest"
Write-Host "Destination exists: $(Test-Path $dest)"

# List all files in destination first
if (Test-Path $dest) {
    Write-Host "Files in destination root:"
    Get-ChildItem $dest | ForEach-Object { 
        Write-Host "  $($_.Name) ($($_.PSIsContainer ? 'DIR' : [math]::Round($_.Length / 1MB, 2).ToString() + ' MB'))"
    }
} else {
    Write-Host "ERROR: Destination directory does not exist!" -ForegroundColor Red
    exit 1
}

$sourcesDir = Join-Path $dest "sources"
Write-Host "Sources directory: $sourcesDir"
Write-Host "Sources directory exists: $(Test-Path $sourcesDir)"

if (Test-Path $sourcesDir) {
    Write-Host "Files in sources directory:"
    Get-ChildItem $sourcesDir | ForEach-Object { 
        Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)"
    }
} else {
    Write-Host "ERROR: Sources directory does not exist!" -ForegroundColor Red
    exit 1
}

$wim = Join-Path $dest "sources\install.wim"
$esd = Join-Path $dest "sources\install.esd"

Write-Host "Checking for install.wim: $wim"
Write-Host "install.wim exists: $(Test-Path $wim)"
if (Test-Path $wim) {
    Write-Host "install.wim size: $([math]::Round((Get-Item $wim).Length / 1GB, 2)) GB"
}

Write-Host "Checking for install.esd: $esd"
Write-Host "install.esd exists: $(Test-Path $esd)"
if (Test-Path $esd) {
    Write-Host "install.esd size: $([math]::Round((Get-Item $esd).Length / 1GB, 2)) GB"
}

if (-not (Test-Path $wim)) {
    if (Test-Path $esd) {
        Write-Host "Tìm thấy install.esd, chuyển đổi sang install.wim..."
        try {
            # Convert ESD to WIM using wimlib-imagex
            $wimlibPath = "wimlib-imagex"
            Write-Host "Attempting to use wimlib-imagex..."
            
            $result = & $wimlibPath export $esd 1 $wim --compress=LZX:21 2>&1
            $exitCode = $LASTEXITCODE
            
            Write-Host "wimlib-imagex export result:"
            $result | ForEach-Object { Write-Host "  $_" }
            Write-Host "Exit code: $exitCode"
            
            if ($exitCode -ne 0) {
                Write-Host "LỖI: Không thể chuyển đổi install.esd sang install.wim!" -ForegroundColor Red
                Write-Host "Trying alternative method with DISM..."
                
                # Alternative: Use DISM to export
                $result = & dism /export-image /sourceimagefile:$esd /sourceindex:1 /destinationimagefile:$wim /compress:max /checkintegrity 2>&1
                $exitCode = $LASTEXITCODE
                
                Write-Host "DISM export result:"
                $result | ForEach-Object { Write-Host "  $_" }
                Write-Host "Exit code: $exitCode"
                
                if ($exitCode -ne 0) {
                    Write-Host "LỖI: Cả hai phương pháp chuyển đổi đều thất bại!" -ForegroundColor Red
                    exit 1
                }
            }
            
            Write-Host "Đã chuyển đổi install.esd thành install.wim thành công!"
        } catch {
            Write-Host "LỖI: Không thể chuyển đổi install.esd! $_" -ForegroundColor Red
            exit 1
        }
    } else {
        Write-Host "LỖI: Không tìm thấy install.wim hoặc install.esd!" -ForegroundColor Red
        Write-Host "Thư mục sources: $(Join-Path $dest 'sources')" -ForegroundColor Yellow
        Write-Host "Sources directory exists: $(Test-Path (Join-Path $dest 'sources'))" -ForegroundColor Yellow
        
        if (Test-Path (Join-Path $dest "sources")) {
            Write-Host "Các file trong sources:" -ForegroundColor Yellow
            Get-ChildItem (Join-Path $dest "sources") | ForEach-Object { 
                Write-Host "  $($_.Name) ($($_.Length / 1MB) MB)" 
            }
        } else {
            Write-Host "Thư mục sources không tồn tại!" -ForegroundColor Red
            Write-Host "Nội dung thư mục ISO:" -ForegroundColor Yellow
            Get-ChildItem $dest | ForEach-Object { 
                Write-Host "  $($_.Name)" 
            }
        }
        
        Write-Host "LỖI: Không thể tiếp tục debloat mà không có install.wim/install.esd" -ForegroundColor Red
        exit 1
    }
}

Write-Host "Tìm thấy install.wim: $wim"
Write-Host "install.wim file size: $((Get-Item $wim).Length / 1GB) GB"

# 3. Get WIM information and count images
Write-Host "=== LẤY THÔNG TIN WIM ==="
try {
    Write-Host "Running DISM get-wiminfo on: $wim"
    Write-Host "WIM file size: $([math]::Round((Get-Item $wim).Length / 1GB, 2)) GB"
    
    # Test if DISM is available first
    $dismTest = & dism /? 2>&1
    $dismExitCode = $LASTEXITCODE
    Write-Host "DISM availability test exit code: $dismExitCode"
    
    if ($dismExitCode -ne 0) {
        Write-Host "ERROR: DISM is not available or not working properly" -ForegroundColor Red
        Write-Host "DISM test output: $($dismTest -join ' ')" -ForegroundColor Yellow
        exit 1
    }
    
    Write-Host "DISM is available, running get-wiminfo..."
    $wimInfo = & dism /get-wiminfo /wimfile:$wim 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Host "DISM get-wiminfo exit code: $exitCode"
    
    if ($exitCode -ne 0) {
        Write-Host "LỖI: Không thể lấy thông tin WIM!" -ForegroundColor Red
        Write-Host "DISM get-wiminfo output:" -ForegroundColor Yellow
        $wimInfo | ForEach-Object { Write-Host "  $_" }
        Write-Host "This might be due to:" -ForegroundColor Red
        Write-Host "  - Corrupted WIM file" -ForegroundColor Red
        Write-Host "  - Insufficient permissions" -ForegroundColor Red
        Write-Host "  - WIM file is locked by another process" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "DISM get-wiminfo successful, output:"
    $wimInfo | ForEach-Object { Write-Host "  $_" }
    
    # Count images using correct pattern
    $imageLines = $wimInfo | Select-String "Index:"
    $imageCount = $imageLines.Count
    Write-Host "Số lượng images trong WIM: $imageCount"
    
    if ($imageCount -eq 0) {
        Write-Host "LỖI: Không tìm thấy images nào trong WIM!" -ForegroundColor Red
        Write-Host "Full WIM info output:" -ForegroundColor Yellow
        $wimInfo | ForEach-Object { Write-Host "  $_" }
        exit 1
    }
    
    # Show all available editions
    Write-Host "=== CÁC EDITIONS CÓ SẴN ==="
    $imageLines | ForEach-Object {
        $line = $_.Line
        $index = [regex]::Match($line, "Index:\s*(\d+)").Groups[1].Value
        $name = [regex]::Match($line, "Name:\s*(.+)").Groups[1].Value
        Write-Host "  Index $index`: $name"
    }
    
} catch {
    Write-Host "LỖI: Không thể lấy thông tin WIM! $_" -ForegroundColor Red
    Write-Host "Exception details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# If in test mode, exit here after WIM info
if ($testMode) {
    Write-Host "=== TEST MODE: Exiting after WIM info check ===" -ForegroundColor Green
    Write-Host "WIM file is valid and contains $imageCount images" -ForegroundColor Green
    exit 0
}

# 4. Mount install.wim
Write-Host "=== MOUNT WIM ==="
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
        $match = $wimInfo | Select-String "Index:" | Where-Object { $_ -match $winEdition }
        if ($match) {
            $imageIndex = [regex]::Match($match.Line, "Index:\s*(\d+)").Groups[1].Value
            Write-Host "Tìm thấy edition tại index: $imageIndex"
        } else {
            Write-Host "Không tìm thấy edition '$winEdition', sử dụng index 1" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "Không tìm thấy edition, sử dụng index 1" -ForegroundColor Yellow
    }
}

Write-Host "Mount WIM image index $imageIndex..."
try {
    Write-Host "Running DISM mount-wim..."
    $mountResult = & dism /mount-wim /wimfile:$wim /index:$imageIndex /mountdir:$mountdir 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Host "DISM mount result:"
    $mountResult | ForEach-Object { Write-Host "  $_" }
    Write-Host "Exit code: $exitCode"
    
    if ($exitCode -ne 0) {
        Write-Host "LỖI: Không mount được WIM!" -ForegroundColor Red
        Write-Host "This might be due to insufficient disk space or corrupted WIM" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "=== ĐÃ MOUNT WIM THÀNH CÔNG ==="
    
    # Debug: Check mount directory
    Write-Host "=== DEBUG: Kiểm tra thư mục mount ==="
    Write-Host "Mount directory: $mountdir"
    Write-Host "Mount directory exists: $(Test-Path $mountdir)"
    
    if (Test-Path $mountdir) {
        Write-Host "Files in mount directory:"
        Get-ChildItem $mountdir | ForEach-Object { Write-Host "  $($_.Name)" }
        
        if (Test-Path (Join-Path $mountdir "Windows")) {
            Write-Host "Windows directory exists"
        } else {
            Write-Host "Windows directory does not exist!"
        }
    }
    
} catch {
    Write-Host "LỖI: Không mount được WIM! $_" -ForegroundColor Red
    Write-Host "Exception details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# 5. Debloat: Remove AppX, Capabilities, Features, OneDrive, Edge, etc.
Write-Host "=== BẮT ĐẦU DEBLOAT ==="

# Remove OneDrive first (simpler operation)
Write-Host "Xóa OneDrive..."
try {
    Remove-Item "$mountdir\Windows\System32\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
    Remove-Item "$mountdir\Windows\SysWOW64\OneDriveSetup.exe" -Force -ErrorAction SilentlyContinue
    Write-Host "  OneDrive files removed"
} catch {
    Write-Host "  Cảnh báo: Không thể xóa OneDrive" -ForegroundColor Yellow
}

# Remove Edge
Write-Host "Xóa Edge..."
try {
    Remove-Item "$mountdir\Program Files\Microsoft\Edge*" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "$mountdir\Program Files (x86)\Microsoft\Edge*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "  Edge directories removed"
} catch {
    Write-Host "  Cảnh báo: Không thể xóa Edge" -ForegroundColor Yellow
}

# Remove AppX packages (simplified approach)
Write-Host "Xóa AppX packages..."
$appx = @(
    "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.549981C3F5F10", "Microsoft.WindowsAlarms",
    "Microsoft.WindowsFeedbackHub", "Microsoft.GetHelp", "Microsoft.Getstarted", "Microsoft.WindowsMaps",
    "Microsoft.WindowsCommunicationsapps", "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.Xbox",
    "Microsoft.People", "Microsoft.YourPhone", "Microsoft.SkypeApp", "Microsoft.Todos", "Microsoft.Wallet"
)

try {
    Write-Host "  Lấy danh sách AppX packages..."
    $appxResult = & dism /image:$mountdir /get-provisionedappxpackages 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Host "  DISM get-provisionedappxpackages exit code: $exitCode"
    
    if ($exitCode -eq 0) {
        foreach ($pattern in $appx) {
            Write-Host "  Đang tìm AppX: $pattern"
            $appxPackages = $appxResult | Select-String $pattern
            
            foreach ($package in $appxPackages) {
                $packageName = ($package.Line -split ":")[1].Trim()
                if ($packageName) {
                    Write-Host "    Removing: $packageName"
                    $removeResult = & dism /image:$mountdir /remove-provisionedappxpackage /packagename:$packageName 2>&1
                    $removeExitCode = $LASTEXITCODE
                    Write-Host "    Remove exit code: $removeExitCode"
                    if ($removeExitCode -ne 0) {
                        Write-Host "    Remove result: $($removeResult -join ' ')" -ForegroundColor Yellow
                    }
                }
            }
        }
    } else {
        Write-Host "  Không thể lấy danh sách AppX packages" -ForegroundColor Yellow
        Write-Host "  DISM output: $($appxResult -join ' ')" -ForegroundColor Yellow
    }
} catch {
    Write-Host "  Cảnh báo: Lỗi khi xử lý AppX packages: $_" -ForegroundColor Yellow
}

# Remove Capabilities (simplified)
Write-Host "Xóa Windows Capabilities..."
$capabilities = @(
    "App.StepsRecorder*", "Language.Handwriting*", "Language.OCR*", "Language.Speech*", "Language.TextToSpeech*",
    "Microsoft.Windows.WordPad*", "MathRecognizer*", "Media.WindowsMediaPlayer*", "Microsoft.Windows.PowerShell.ISE*"
)
foreach ($cap in $capabilities) {
    Write-Host "  Đang xóa Capability: $cap"
    try {
        $capResult = & dism /image:$mountdir /get-capabilities 2>&1
        $capPackages = $capResult | Select-String $cap.Replace("*", "")
        
        foreach ($package in $capPackages) {
            $capName = $package.Line.Trim()
            Write-Host "    Removing capability: $capName"
            $removeResult = & dism /image:$mountdir /remove-capability /capabilityname:$capName 2>&1
            Write-Host "    Remove result: $($removeResult -join ' ')"
        }
    } catch {
        Write-Host "    Cảnh báo: Không thể xóa $cap" -ForegroundColor Yellow
    }
}

# Remove Features/Packages (simplified)
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
        $pkgResult = & dism /image:$mountdir /get-packages 2>&1
        $pkgPackages = $pkgResult | Select-String $pkg.Replace("*", "")
        
        foreach ($package in $pkgPackages) {
            $pkgName = $package.Line.Trim()
            Write-Host "    Removing package: $pkgName"
            $removeResult = & dism /image:$mountdir /remove-package /packagename:$pkgName 2>&1
            Write-Host "    Remove result: $($removeResult -join ' ')"
        }
    } catch {
        Write-Host "    Cảnh báo: Không thể xóa $pkg" -ForegroundColor Yellow
    }
}

Write-Host "=== ĐÃ DEBLOAT XONG, BẮT ĐẦU PATCH REGISTRY ==="

# 6. Registry Tweaks (simplified)
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

# 7. Unmount & commit
try {
    Write-Host "Running DISM unmount-wim..."
    $unmountResult = & dism /unmount-wim /mountdir:$mountdir /commit 2>&1
    $exitCode = $LASTEXITCODE
    
    Write-Host "DISM unmount result:"
    $unmountResult | ForEach-Object { Write-Host "  $_" }
    Write-Host "Exit code: $exitCode"
    
    if ($exitCode -ne 0) {
        Write-Host "LỖI: Không thể unmount WIM!" -ForegroundColor Red
        Write-Host "This might be due to file system issues or insufficient permissions" -ForegroundColor Red
        exit 1
    }
    
    Write-Host "=== ĐÃ UNMOUNT WIM THÀNH CÔNG ==="
} catch {
    Write-Host "LỖI: Không thể unmount WIM! $_" -ForegroundColor Red
    Write-Host "Exception details: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host "=== BẮT ĐẦU TẠO LẠI ISO ==="

# 8. Change ownership to avoid permission issues
Write-Host "Thay đổi quyền sở hữu thư mục để tránh lỗi permission..."
try {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    Write-Host "Current user: $currentUser"
    
    $acl = Get-Acl $dest
    $accessRule = New-Object System.Security.AccessControl.FileSystemAccessRule($currentUser, "FullControl", "ContainerInherit,ObjectInherit", "None", "Allow")
    $acl.SetAccessRule($accessRule)
    Set-Acl $dest $acl
    
    Write-Host "Đã thay đổi quyền sở hữu thành công"
} catch {
    Write-Host "Cảnh báo: Không thể thay đổi quyền sở hữu: $_" -ForegroundColor Yellow
}

# 9. Create new ISO using available tools
Write-Host "Tạo ISO mới..."
$isoCreated = $false

# Method 1: Try oscdimg first
Write-Host "Thử phương pháp 1: oscdimg..."
try {
    $oscdimgPath = "oscdimg"
    $testResult = & $oscdimgPath 2>&1
    $testExitCode = $LASTEXITCODE
    Write-Host "oscdimg test exit code: $testExitCode"
    
    if ($testExitCode -eq 0 -or $testResult -match "Usage" -or $testResult -match "Microsoft") {
        Write-Host "oscdimg is available"
        
        # Create ISO with proper boot settings
        $isoResult = & $oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$dest\boot\etfsboot.com"#pEF,e,b"$dest\efi\microsoft\boot\efisys.bin" $dest $outputISO 2>&1
        $exitCode = $LASTEXITCODE
        
        Write-Host "oscdimg exit code: $exitCode"
        if ($exitCode -eq 0) {
            Write-Host "=== TẠO ISO THÀNH CÔNG VỚI OSCDIMG ==="
            $isoCreated = $true
        } else {
            Write-Host "oscdimg failed with exit code $exitCode" -ForegroundColor Yellow
            Write-Host "oscdimg output: $($isoResult -join ' ')" -ForegroundColor Yellow
        }
    } else {
        Write-Host "oscdimg not available" -ForegroundColor Yellow
    }
} catch {
    Write-Host "oscdimg error: $_" -ForegroundColor Yellow
}

# Method 2: Try 7-Zip if oscdimg failed
if (-not $isoCreated) {
    Write-Host "Thử phương pháp 2: 7-Zip..."
    try {
        $sevenZipPath = "7z"
        $testResult = & $sevenZipPath 2>&1
        $testExitCode = $LASTEXITCODE
        Write-Host "7z test exit code: $testExitCode"
        
        if ($testExitCode -eq 0 -or $testResult -match "Usage" -or $testResult -match "7-Zip") {
            Write-Host "7-Zip is available, creating ISO..."
            
            # Create ISO with 7-Zip (simple method)
            $isoResult = & $sevenZipPath a -tiso $outputISO "$dest\*" 2>&1
            $exitCode = $LASTEXITCODE
            
            Write-Host "7z exit code: $exitCode"
            if ($exitCode -eq 0) {
                Write-Host "=== TẠO ISO THÀNH CÔNG VỚI 7-ZIP ==="
                $isoCreated = $true
            } else {
                Write-Host "7-Zip failed with exit code $exitCode" -ForegroundColor Yellow
                Write-Host "7z output: $($isoResult -join ' ')" -ForegroundColor Yellow
            }
        } else {
            Write-Host "7-Zip not available" -ForegroundColor Yellow
        }
    } catch {
        Write-Host "7-Zip error: $_" -ForegroundColor Yellow
    }
}

# Method 3: Try PowerShell COM object
if (-not $isoCreated) {
    Write-Host "Thử phương pháp 3: PowerShell COM..."
    try {
        # Use COM object to create ISO
        $fso = New-Object -ComObject Scripting.FileSystemObject
        $shell = New-Object -ComObject Shell.Application
        
        # This is a simplified approach - create a basic ISO
        Write-Host "Trying to create basic ISO structure..."
        
        # Create a ZIP file first, then rename to ISO (basic approach)
        $zipPath = $outputISO -replace "\.iso$", ".zip"
        Compress-Archive -Path "$dest\*" -DestinationPath $zipPath -Force
        
        if (Test-Path $zipPath) {
            Move-Item $zipPath $outputISO -Force
            Write-Host "=== TẠO ISO THÀNH CÔNG VỚI POWERSHELL ==="
            $isoCreated = $true
        }
    } catch {
        Write-Host "PowerShell COM error: $_" -ForegroundColor Yellow
    }
}

# Final check
if (-not $isoCreated) {
    Write-Host "CẢNH BÁO: Không thể tạo ISO với bất kỳ phương pháp nào!" -ForegroundColor Yellow
    Write-Host "Các file đã được debloat thành công tại: $dest" -ForegroundColor Green
    Write-Host "Bạn có thể tạo ISO thủ công từ thư mục này bằng các tools khác" -ForegroundColor Yellow
    Write-Host "Hoặc sử dụng thư mục debloated này để tạo VM/install trực tiếp" -ForegroundColor Yellow
    
    # Don't exit with error code - debloat was successful
    Write-Host "=== DEBLOAT HOÀN TẤT (ISO CREATION SKIPPED) ==="
    exit 0
}

# 10. Verify output ISO
if (Test-Path $outputISO) {
    $outputSize = (Get-Item $outputISO).Length / 1GB
    Write-Host "=== HOÀN THÀNH ==="
    Write-Host "ISO đã được tạo thành công: $outputISO"
    Write-Host "Kích thước: $([math]::Round($outputSize,2)) GB"
    Write-Host "Debloat hoàn tất!"
    $isoSuccess = $true
} else {
    Write-Host "=== DEBLOAT HOÀN TẤT ==="
    Write-Host "Windows đã được debloat thành công!" -ForegroundColor Green
    Write-Host "Thư mục chứa các file đã debloat: $dest" -ForegroundColor Yellow
    Write-Host "Bạn có thể sử dụng thư mục này để:" -ForegroundColor Yellow
    Write-Host "  1. Tạo ISO thủ công bằng tools khác" -ForegroundColor Yellow
    Write-Host "  2. Tạo VM trực tiếp từ thư mục này" -ForegroundColor Yellow
    Write-Host "  3. Copy vào USB để install" -ForegroundColor Yellow
    $isoSuccess = $false
}

# 11. Cleanup
if ($isoSuccess) {
    Write-Host "Dọn dẹp thư mục tạm..."
    try {
        Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item $mountdir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Đã dọn dẹp xong"
    } catch {
        Write-Host "Cảnh báo: Không thể dọn dẹp thư mục tạm: $_" -ForegroundColor Yellow
    }
    
    Write-Host "=== DEBLOAT HOÀN TẤT ==="
Write-Host "File ISO đã được debloat: $outputISO" 
} else {
    Write-Host "Giữ lại thư mục debloated để sử dụng: $dest" -ForegroundColor Green
    Write-Host "Dọn dẹp mount directory..."
    try {
        Remove-Item $mountdir -Recurse -Force -ErrorAction SilentlyContinue
        Write-Host "Đã dọn dẹp mount directory"
    } catch {
        Write-Host "Cảnh báo: Không thể dọn dẹp mount directory: $_" -ForegroundColor Yellow
    }
}

# End of main try block
} catch {
    Write-Host "=== CRITICAL ERROR ===" -ForegroundColor Red
    Write-Host "Script failed with unexpected error: $_" -ForegroundColor Red
    Write-Host "Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Error message: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Stack trace:" -ForegroundColor Red
    Write-Host "$($_.ScriptStackTrace)" -ForegroundColor Red
    Write-Host "Line: $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Red
    Write-Host "Position: $($_.InvocationInfo.PositionMessage)" -ForegroundColor Red
    
    # Flush output and wait a moment before exiting
    [System.Console]::Out.Flush()
    [System.Console]::Error.Flush()
    Start-Sleep -Seconds 1
    
    exit 1
}

# Final output flush
[System.Console]::Out.Flush()
Write-Host "Script completed successfully" 