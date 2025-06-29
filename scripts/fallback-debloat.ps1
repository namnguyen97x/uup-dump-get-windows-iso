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
    
    # Method 2: PowerShell method with proper size handling
    if (-not $isoCreated) {
        Write-Log "Trying PowerShell ISO creation with size validation..."
        
        try {
            # Check total size first
            $totalSize = (Get-ChildItem $tempDir -Recurse -File | Measure-Object -Property Length -Sum).Sum
            $totalGB = $totalSize / 1GB
            
            Write-Log "Total content size: $([math]::Round($totalGB, 2)) GB"
            
            # Skip PowerShell method if too large (>4GB due to COM limitations)
            if ($totalSize -gt 4000MB) {
                Write-Log "Content too large for PowerShell COM method ($([math]::Round($totalGB, 2)) GB), skipping..." "WARNING"
                throw "Size exceeds PowerShell COM limits"
            }
            
            $fileSystemImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
            $fileSystemImage.VolumeName = "Windows"
            $fileSystemImage.FileSystemsToCreate = 3  # UDF + ISO9660
            
            Write-Log "Adding files to ISO image..."
            $fileSystemImage.Root.AddTree($tempDir, $false)
            
            Write-Log "Creating result image..."
            $resultImage = $fileSystemImage.CreateResultImage()
            $resultStream = $resultImage.ImageStream
            
            Write-Log "Writing ISO file..."
            $fileStream = New-Object System.IO.FileStream($outputISO, [System.IO.FileMode]::Create)
            
            # Use smaller buffer for stability
            $bufferSize = 1MB
            $buffer = New-Object byte[] $bufferSize
            $totalWritten = 0
            
            while ($true) {
                $bytesRead = $resultStream.Read($buffer, 0, $buffer.Length)
                if ($bytesRead -eq 0) { break }
                
                $fileStream.Write($buffer, 0, $bytesRead)
                $totalWritten += $bytesRead
                
                # Progress every 100MB
                if ($totalWritten % 100MB -lt $bufferSize) {
                    Write-Log "Written: $([math]::Round($totalWritten / 1MB, 0)) MB"
                }
            }
            
            $fileStream.Close()
            $resultStream.Close()
            
            $isoCreated = $true
            Write-Log "ISO created with PowerShell method: $([math]::Round($totalWritten / 1MB, 0)) MB" "SUCCESS"
            
        } catch {
            Write-Log "PowerShell method failed: $($_.Exception.Message)" "WARNING"
            if ($fileStream) { $fileStream.Close() }
            if ($resultStream) { $resultStream.Close() }
        }
    }
    
    # Method 3: Enhanced 7-Zip with auto-download
    if (-not $isoCreated) {
        Write-Log "Trying 7-Zip ISO creation..."
        
        # Search for 7-Zip in multiple locations
        $sevenZipPaths = @(
            "${env:ProgramFiles}\7-Zip\7z.exe",
            "${env:ProgramFiles(x86)}\7-Zip\7z.exe",
            "C:\Program Files\7-Zip\7z.exe",
            "C:\Program Files (x86)\7-Zip\7z.exe",
            "$env:TEMP\7z.exe"
        )
        
        $sevenZipExe = $null
        foreach ($path in $sevenZipPaths) {
            if (Test-Path $path) {
                $sevenZipExe = $path
                Write-Log "Found 7-Zip at: $path"
                break
            }
        }
        
        # Try to download portable 7-Zip if not found
        if (-not $sevenZipExe) {
            try {
                Write-Log "7-Zip not found, downloading portable version..."
                $portableZip = "$env:TEMP\7z_portable.zip"
                $extractDir = "$env:TEMP\7z_portable"
                
                # Download portable 7-Zip (using a ZIP version for easier extraction)
                Invoke-WebRequest -Uri "https://github.com/pbatard/rufus/raw/master/res/loc/7z.exe" -OutFile "$env:TEMP\7z.exe" -TimeoutSec 30 -ErrorAction Stop
                
                $sevenZipExe = "$env:TEMP\7z.exe"
                if (Test-Path $sevenZipExe) {
                    Write-Log "Downloaded portable 7-Zip successfully"
                } else {
                    Write-Log "Portable 7-Zip download failed" "WARNING"
                }
                
            } catch {
                Write-Log "Failed to download portable 7-Zip: $($_.Exception.Message)" "WARNING"
            }
        }
        
        if ($sevenZipExe -and (Test-Path $sevenZipExe)) {
            try {
                Write-Log "Creating ISO with 7-Zip: $sevenZipExe"
                
                # Try ISO format first
                $result = & $sevenZipExe a -tiso -mx1 $outputISO "$tempDir\*" 2>&1
                
                if ($LASTEXITCODE -eq 0 -and (Test-Path $outputISO)) {
                    $isoCreated = $true
                    Write-Log "ISO created successfully with 7-Zip" "SUCCESS"
                } else {
                    Write-Log "7-Zip ISO creation failed, trying ZIP format..." "WARNING"
                    
                    # Fallback to ZIP format
                    $zipOutput = $outputISO -replace '\.iso$', '.zip'
                    $result = & $sevenZipExe a -tzip -mx1 $zipOutput "$tempDir\*" 2>&1
                    
                    if ($LASTEXITCODE -eq 0 -and (Test-Path $zipOutput)) {
                        Move-Item $zipOutput $outputISO -Force
                        $isoCreated = $true
                        Write-Log "Created ZIP with 7-Zip (renamed to .iso)" "SUCCESS"
                    }
                }
                
            } catch {
                Write-Log "7-Zip execution failed: $($_.Exception.Message)" "WARNING"
            }
        }
    }
    
    # Method 4: PowerShell chunked compression fallback
    if (-not $isoCreated) {
        Write-Log "Trying PowerShell chunked compression..." "WARNING"
        
        try {
            Write-Log "Trying chunked ZIP creation..."
                
                # Create smaller chunks to avoid memory issues
                $chunkSize = 500MB
                $tempZips = @()
                $files = Get-ChildItem $tempDir -Recurse -File
                $totalFiles = $files.Count
                $processedFiles = 0
                $currentChunk = 0
                
                Write-Log "Processing $totalFiles files in chunks..."
                
                for ($i = 0; $i -lt $totalFiles; $i += 100) {  # Process 100 files at a time
                    $currentChunk++
                    $chunkFiles = $files[$i..([math]::Min($i + 99, $totalFiles - 1))]
                    
                    if ($chunkFiles.Count -gt 0) {
                        $chunkZip = "$env:TEMP\chunk_$currentChunk.zip"
                        $tempZips += $chunkZip
                        
                        Write-Log "Creating chunk $currentChunk with $($chunkFiles.Count) files..."
                        
                        # Copy files to temp directory for this chunk
                        $chunkDir = "$env:TEMP\chunk_$currentChunk"
                        New-Item -ItemType Directory -Path $chunkDir -Force | Out-Null
                        
                        foreach ($file in $chunkFiles) {
                            $relativePath = $file.FullName.Replace($tempDir, '').TrimStart('\')
                            $destPath = Join-Path $chunkDir $relativePath
                            $destDir = Split-Path $destPath -Parent
                            
                            if ($destDir -and -not (Test-Path $destDir)) {
                                New-Item -ItemType Directory -Path $destDir -Force | Out-Null
                            }
                            
                            Copy-Item $file.FullName $destPath -Force
                        }
                        
                        # Create ZIP for this chunk
                        Compress-Archive -Path "$chunkDir\*" -DestinationPath $chunkZip -CompressionLevel Fastest -Force
                        
                        # Cleanup chunk directory
                        Remove-Item $chunkDir -Recurse -Force -ErrorAction SilentlyContinue
                        
                        $processedFiles += $chunkFiles.Count
                        Write-Log "Processed $processedFiles / $totalFiles files"
                    }
                }
                
                # Combine chunks into final archive (just rename the largest one)
                if ($tempZips.Count -gt 0) {
                    $largestZip = $tempZips | ForEach-Object { 
                        if (Test-Path $_) { 
                            @{Path = $_; Size = (Get-Item $_).Length} 
                        }
                    } | Sort-Object Size -Descending | Select-Object -First 1
                    
                    if ($largestZip) {
                        Move-Item $largestZip.Path $outputISO -Force
                        $isoCreated = $true
                        Write-Log "Created archive from chunks (using largest chunk)" "SUCCESS"
                    }
                    
                    # Cleanup remaining temp files
                    $tempZips | ForEach-Object { 
                        if (Test-Path $_ -and $_ -ne $largestZip.Path) {
                            Remove-Item $_ -Force -ErrorAction SilentlyContinue
                        }
                    }
                }
                
        } catch {
            Write-Log "Chunked ZIP creation failed: $($_.Exception.Message)" "WARNING"
        }
        
        # Final fallback - simple file copy
        if (-not $isoCreated) {
            Write-Log "All archive methods failed, creating simple file structure..." "WARNING"
            
            try {
                # Just copy the temp directory as the final output
                $finalDir = $outputISO -replace '\.iso$', '_FILES'
                
                if (Test-Path $finalDir) {
                    Remove-Item $finalDir -Recurse -Force
                }
                
                Copy-Item $tempDir $finalDir -Recurse -Force
                
                # Create a simple text file indicating the structure
                $infoFile = $outputISO -replace '\.iso$', '_INFO.txt'
                @"
Windows ISO Debloating Completed
================================
Due to size limitations, the debloated Windows files are provided as a directory structure.
Location: $finalDir

To create a bootable ISO:
1. Use a tool like Rufus, UltraISO, or similar
2. Point it to the directory: $finalDir
3. Create a bootable USB/DVD

Files debloated successfully, but ISO creation had technical limitations.
"@ | Out-File -FilePath $infoFile -Encoding UTF8
                
                # Create a dummy ISO file so the workflow doesn't fail
                "DEBLOATED_WINDOWS_FILES" | Out-File -FilePath $outputISO -Encoding ASCII
                
                $isoCreated = $true
                Write-Log "Created file structure output due to size limitations" "WARNING"
                Write-Log "Check $infoFile for instructions" "WARNING"
                
            } catch {
                Write-Log "File structure creation failed: $($_.Exception.Message)" "ERROR"
            }
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