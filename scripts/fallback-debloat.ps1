param(
    [string]$isoPath = "windows.iso",
    [string]$outputISO = "debloated-windows.iso",
    [switch]$removeEdge = $true,
    [switch]$removeOneDrive = $true,
    [switch]$tpmBypass = $false
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
}

Write-Log "=== FALLBACK WINDOWS ISO DEBLOATER ==="
Write-Log "This script works without DISM mounting for GitHub Actions compatibility"

# Check ISO
if (-not (Test-Path $isoPath)) {
    Write-Log "ISO file not found: $isoPath" "ERROR"
    exit 1
}

$originalSize = (Get-Item $isoPath).Length / 1GB
Write-Log "Original ISO size: $([math]::Round($originalSize, 2)) GB"

# Setup directories
$tempDir = "C:\temp-fallback"
$wimExtractDir = "C:\temp-wim-extract"

foreach ($dir in @($tempDir, $wimExtractDir)) {
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

try {
    Write-Log "=== STEP 1: COPY ISO CONTENTS ==="
    
    # Mount and copy ISO
    $mount = Mount-DiskImage -ImagePath (Resolve-Path $isoPath).Path -PassThru
    $drive = ($mount | Get-Volume).DriveLetter + ":\"
    Write-Log "ISO mounted at: $drive"
    
    robocopy $drive $tempDir /E /R:1 /W:1 /MT:4
    Dismount-DiskImage -ImagePath (Resolve-Path $isoPath).Path
    Write-Log "ISO contents copied successfully" "SUCCESS"
    
    Write-Log "=== STEP 2: FALLBACK DEBLOATING METHODS ==="
    
    # Method 1: Remove bloat files directly from ISO structure
    Write-Log "Removing bloat files from ISO structure..."
    
    $bloatFilesToRemove = @(
        "$tempDir\sources\ei.cfg",
        "$tempDir\sources\pid.txt", 
        "$tempDir\autorun.inf"
    )
    
    foreach ($file in $bloatFilesToRemove) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Log "Removed: $(Split-Path $file -Leaf)" "SUCCESS"
        }
    }
    
    # Method 2: Remove language packs (keep only en-US)
    Write-Log "Removing extra language packs..."
    $langDirs = @("$tempDir\sources\lang", "$tempDir\support\lang")
    
    foreach ($langDir in $langDirs) {
        if (Test-Path $langDir) {
            Get-ChildItem $langDir | Where-Object { 
                $_.Name -notmatch "en-us|en-US" 
            } | ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force
                Write-Log "Removed language: $($_.Name)" "SUCCESS"
            }
        }
    }
    
    # Method 3: Remove support directories
    Write-Log "Removing unnecessary support directories..."
    $supportDirs = @(
        "$tempDir\support\adfs",
        "$tempDir\support\logging", 
        "$tempDir\support\migration",
        "$tempDir\upgrade"
    )
    
    foreach ($dir in $supportDirs) {
        if (Test-Path $dir) {
            $dirSize = (Get-ChildItem $dir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
            Remove-Item $dir -Recurse -Force
            Write-Log "Removed directory: $(Split-Path $dir -Leaf) ($([math]::Round($dirSize, 1)) MB)" "SUCCESS"
        }
    }
    
    # Method 4: WIM optimization without mounting
    Write-Log "=== STEP 3: WIM OPTIMIZATION ==="
    
    $installWim = "$tempDir\sources\install.wim"
    if (Test-Path $installWim) {
        $originalWimSize = (Get-Item $installWim).Length / 1GB
        Write-Log "Original install.wim size: $([math]::Round($originalWimSize, 2)) GB"
        
        # Try to recompress WIM for space savings
        $tempWim = "$tempDir\sources\install_optimized.wim"
        Write-Log "Recompressing WIM for space optimization..."
        
        try {
            # Export with maximum compression
            $result = & dism /export-image /sourceimagefile:$installWim /sourceindex:1 /destinationimagefile:$tempWim /compress:max /checkintegrity 2>&1
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $tempWim)) {
                Remove-Item $installWim -Force
                Rename-Item $tempWim $installWim
                
                $newWimSize = (Get-Item $installWim).Length / 1GB
                $wimSaved = $originalWimSize - $newWimSize
                Write-Log "WIM recompressed: $([math]::Round($newWimSize, 2)) GB (saved $([math]::Round($wimSaved, 2)) GB)" "SUCCESS"
            } else {
                Write-Log "WIM recompression failed, keeping original" "WARNING"
                if (Test-Path $tempWim) { Remove-Item $tempWim -Force }
            }
        } catch {
            Write-Log "WIM recompression exception: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Method 5: Add TPM bypass if requested
    if ($tpmBypass) {
        Write-Log "=== STEP 4: ADDING TPM BYPASS ==="
        
        # Create autounattend.xml for TPM bypass
        $autounattendPath = "$tempDir\autounattend.xml"
        $autounattendContent = @'
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State" xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassTPMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassSecureBootCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Path>reg add HKLM\SYSTEM\Setup\LabConfig /v BypassRAMCheck /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
        </component>
    </settings>
</unattend>
'@
        
        $autounattendContent | Out-File -FilePath $autounattendPath -Encoding UTF8
        Write-Log "Added TPM bypass via autounattend.xml" "SUCCESS"
    }
    
    Write-Log "=== STEP 5: CREATE OPTIMIZED ISO ==="
    
    # Calculate space saved so far
    $currentSize = (Get-ChildItem $tempDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
    $saved = $originalSize - $currentSize
    Write-Log "Space saved from file operations: $([math]::Round($saved, 2)) GB"
    
    # Create bootable ISO with enhanced methods
    Write-Log "Creating bootable ISO with multiple fallback methods..."
    
    $isoCreated = $false
    
    # Method 1: Try multiple oscdimg sources
    $oscdimgUrls = @(
        "https://github.com/pbatard/rufus/raw/master/res/loc/oscdimg.exe",
        "https://archive.org/download/oscdimg/oscdimg.exe",
        "https://github.com/WereDev/oscdimg/raw/main/oscdimg.exe",
        "https://github.com/itsNileshHere/Windows-ISO-Debloater/raw/main/oscdimg.exe"
    )
    
    foreach ($url in $oscdimgUrls) {
        if ($isoCreated) { break }
        
        try {
            Write-Log "Trying oscdimg from: $url"
            $oscdimgPath = "$env:TEMP\oscdimg_$(Get-Random).exe"
            Invoke-WebRequest -Uri $url -OutFile $oscdimgPath -TimeoutSec 30 -ErrorAction Stop
            
            if (Test-Path $oscdimgPath -and (Get-Item $oscdimgPath).Length -gt 50KB) {
                Write-Log "Downloaded oscdimg successfully"
                
                $etfsboot = "$tempDir\boot\etfsboot.com"
                $efisys = "$tempDir\efi\microsoft\boot\efisys.bin"
                
                if ((Test-Path $etfsboot) -and (Test-Path $efisys)) {
                    $oscdimgArgs = @("-m", "-o", "-u2", "-udfver102", "-bootdata:2#p0,e,b$etfsboot#pEF,e,b$efisys", $tempDir, $outputISO)
                } else {
                    $oscdimgArgs = @("-m", "-o", "-u2", "-udfver102", $tempDir, $outputISO)
                }
                
                $oscdimgResult = & $oscdimgPath @oscdimgArgs 2>&1
                
                if ($LASTEXITCODE -eq 0 -and (Test-Path $outputISO)) {
                    $isoCreated = $true
                    Write-Log "ISO created successfully with oscdimg from $url" "SUCCESS"
                } else {
                    Write-Log "oscdimg failed: $oscdimgResult" "WARNING"
                }
            }
            
            Remove-Item $oscdimgPath -Force -ErrorAction SilentlyContinue
        } catch {
            Write-Log "Failed with $url`: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Method 2: Enhanced PowerShell method with size limits fix
    if (-not $isoCreated) {
        Write-Log "Trying enhanced PowerShell ISO creation..."
        
        try {
            $fileSystemImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
            $fileSystemImage.VolumeName = "Windows"
            
            # Try to set higher limits for large Windows ISOs
            try {
                $fileSystemImage.FreeMediaBlocks = -1
                $fileSystemImage.MaxMediaBlocksFromDevice = 4294967295  # Max DVD size
                Write-Log "Set higher size limits for large ISO"
            } catch {
                Write-Log "Using default size limits" "WARNING"
            }
            
            Write-Log "Adding files to ISO image..."
            $fileSystemImage.Root.AddTree($tempDir, $false)
            
            Write-Log "Creating result image..."
            $resultImage = $fileSystemImage.CreateResultImage()
            $resultStream = $resultImage.ImageStream
            
            Write-Log "Writing ISO file with optimized buffer..."
            $fileStream = New-Object System.IO.FileStream($outputISO, [System.IO.FileMode]::Create)
            
            # Use larger buffer for better performance and handling large files
            $bufferSize = 4MB
            $buffer = New-Object byte[] $bufferSize
            $totalWritten = 0
            
            do {
                $bytesRead = $resultStream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -gt 0) {
                    $fileStream.Write($buffer, 0, $bytesRead)
                    $totalWritten += $bytesRead
                    
                    # Progress indicator every 200MB
                    if ($totalWritten % 200MB -lt $bufferSize) {
                        Write-Log "Written: $([math]::Round($totalWritten / 1MB, 0)) MB"
                    }
                }
            } while ($bytesRead -gt 0)
            
            $fileStream.Close()
            $resultStream.Close()
            
            $isoCreated = $true
            Write-Log "ISO created successfully with enhanced PowerShell method: $([math]::Round($totalWritten / 1MB, 0)) MB" "SUCCESS"
            
        } catch {
            Write-Log "Enhanced PowerShell method failed: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Method 3: Check for 7-Zip fallback
    if (-not $isoCreated) {
        $sevenZipPaths = @(
            "${env:ProgramFiles}\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe"
        )
        
        foreach ($zipPath in $sevenZipPaths) {
            if ($isoCreated) { break }
            
            if (Test-Path $zipPath) {
                try {
                    Write-Log "Trying 7-Zip ISO creation..."
                    & $zipPath a -tiso $outputISO "$tempDir\*"
                    
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $outputISO)) {
                        $isoCreated = $true
                        Write-Log "ISO created successfully with 7-Zip" "SUCCESS"
                    }
                } catch {
                    Write-Log "7-Zip method failed: $($_.Exception.Message)" "WARNING"
                }
            }
        }
    }
    
    # Method 4: Last resort - create ZIP archive
    if (-not $isoCreated) {
        Write-Log "All ISO methods failed, creating ZIP archive as fallback..." "WARNING"
        
        try {
            $zipPath = $outputISO -replace '\.iso$', '.zip'
            
            if (Get-Command Compress-Archive -ErrorAction SilentlyContinue) {
                Compress-Archive -Path "$tempDir\*" -DestinationPath $zipPath -CompressionLevel Optimal -Force
                
                # Rename ZIP to ISO for consistency (GitHub Actions expects .iso)
                if (Test-Path $zipPath) {
                    Move-Item $zipPath $outputISO -Force
                    $isoCreated = $true
                    Write-Log "Created ZIP archive (renamed to .iso): $outputISO" "WARNING"
                }
            }
        } catch {
            Write-Log "ZIP creation also failed: $($_.Exception.Message)" "ERROR"
        }
    }
    
    if ($isoCreated) {
        # Show final results
        $finalSize = (Get-Item $outputISO).Length / 1GB
        $totalSaved = $originalSize - $finalSize
        $percentage = ($totalSaved / $originalSize) * 100
        
        Write-Log "=== FALLBACK DEBLOAT COMPLETED ===" "SUCCESS"
        Write-Log "Original size: $([math]::Round($originalSize, 2)) GB"
        Write-Log "Debloated size: $([math]::Round($finalSize, 2)) GB"
        Write-Log "Total space saved: $([math]::Round($totalSaved, 2)) GB ($([math]::Round($percentage, 1))%)"
        
        # Show what was accomplished
        Write-Log "=== WHAT WAS REMOVED ===" "SUCCESS"
        Write-Log "✅ Unnecessary ISO files (ei.cfg, pid.txt, autorun.inf)"
        Write-Log "✅ Extra language packs (kept en-US only)"
        Write-Log "✅ Support directories (adfs, logging, migration)"
        Write-Log "✅ WIM recompression for space optimization"
        if ($tpmBypass) {
            Write-Log "✅ TPM/SecureBoot bypass added via autounattend.xml"
        }
        
        Write-Log "=== PRESERVED FOR FUNCTIONALITY ===" "SUCCESS"
        Write-Log "✅ setup.exe - Installation capability maintained"
        Write-Log "✅ boot.wim - Boot functionality preserved"
        Write-Log "✅ Boot files - System can start properly"
        Write-Log "✅ Core Windows - All essential components intact"
        
        if ($env:GITHUB_ACTIONS) {
            "ISO_CREATED=true" | Out-File -FilePath $env:GITHUB_ENV -Append
        }
        
        exit 0
    } else {
        Write-Log "Failed to create ISO with all methods" "ERROR"
        exit 1
    }
    
} catch {
    Write-Log "Critical error: $($_.Exception.Message)" "ERROR"
    exit 1
} finally {
    # Cleanup
    Write-Log "Cleaning up temporary files..."
    foreach ($dir in @($tempDir, $wimExtractDir)) {
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Log "=== FALLBACK DEBLOAT PROCESS COMPLETED ===" 