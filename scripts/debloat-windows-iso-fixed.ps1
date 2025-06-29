# Debloat Windows ISO - PowerShell Only
# Author: YourName
# Run as Administrator!

param(
    [string]$isoPath = "",
    [string]$winEdition = "",
    [string]$outputISO = "",
    [switch]$testMode = $false
)

Write-Host "=== SCRIPT STARTED ==="
Write-Host "Script path: $($MyInvocation.MyCommand.Path)"
Write-Host "Working directory: $(Get-Location)"
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "Execution policy: $(Get-ExecutionPolicy)"

# Force output flushing
$Host.UI.RawUI.FlushInputBuffer()
[System.Console]::Out.Flush()
[System.Console]::Error.Flush()

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
    
} catch {
    Write-Host "LỖI: Không mount được ISO! $_" -ForegroundColor Red
    Write-Host "Error details: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "Error type: $($_.Exception.GetType().Name)" -ForegroundColor Red
    Write-Host "Stack trace: $($_.ScriptStackTrace)" -ForegroundColor Red
    
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
        
    } catch {
        Write-Host "LỖI: Cả hai phương pháp mount đều thất bại! $_" -ForegroundColor Red
        Write-Host "Final error details: $($_.Exception.Message)" -ForegroundColor Red
        exit 1
    }
}

Write-Host "=== CHECKPOINT 1: ISO COPY COMPLETED ==="
Write-Host "Next step: Check install.wim/install.esd"
[System.Console]::Out.Flush()
[System.Console]::Error.Flush()

# 2. Check for install.wim or install.esd
Write-Host "=== KIỂM TRA INSTALL.WIM/INSTALL.ESD ==="
Write-Host "Destination directory: $dest"
Write-Host "Destination exists: $(Test-Path $dest)"

# List all files in destination first
if (Test-Path $dest) {
    Write-Host "Files in destination root:"
    Get-ChildItem $dest | ForEach-Object { 
        if ($_.PSIsContainer) {
            Write-Host "  $($_.Name) (DIR)"
        } else {
            Write-Host "  $($_.Name) ($([math]::Round($_.Length / 1MB, 2)) MB)"
        }
    }
} else {
    Write-Host "ERROR: Destination directory does not exist!" -ForegroundColor Red
    Write-Host "=== SCRIPT TERMINATING: DESTINATION NOT FOUND ==="
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
    Write-Host "=== SCRIPT TERMINATING: SOURCES DIR NOT FOUND ==="
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
            # Use DISM to export
            $result = & dism /export-image /sourceimagefile:$esd /sourceindex:1 /destinationimagefile:$wim /compress:max /checkintegrity 2>&1
            $exitCode = $LASTEXITCODE
            
            Write-Host "DISM export result:"
            $result | ForEach-Object { Write-Host "  $_" }
            Write-Host "Exit code: $exitCode"
            
            if ($exitCode -ne 0) {
                Write-Host "LỖI: Không thể chuyển đổi install.esd sang install.wim!" -ForegroundColor Red
                exit 1
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
        Write-Host "=== SCRIPT TERMINATING: NO WIM/ESD FOUND ==="
        exit 1
    }
}

Write-Host "Tìm thấy install.wim: $wim"
Write-Host "install.wim file size: $((Get-Item $wim).Length / 1GB) GB"

Write-Host "=== CHECKPOINT 2: WIM FILE FOUND ==="
Write-Host "Next step: Get WIM information"
[System.Console]::Out.Flush()
[System.Console]::Error.Flush()

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
        Write-Host "=== SCRIPT TERMINATING: DISM NOT AVAILABLE ==="
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
        Write-Host "=== SCRIPT TERMINATING: DISM GET-WIMINFO FAILED ==="
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

Write-Host "=== CHECKPOINT 3: WIM INFO COMPLETED ==="
Write-Host "Found $imageCount images in WIM"
Write-Host "Next step: Mount WIM for debloating"
[System.Console]::Out.Flush()
[System.Console]::Error.Flush()

Write-Host "=== SCRIPT FINISHED NORMALLY ==="
Write-Host "All operations completed successfully" 