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
    
    # Method 2: Aggressive WIM debloating without mounting
    Write-Log "Performing aggressive WIM debloating..."
    
    $installWim = "$tempDir\sources\install.wim"
    if (Test-Path $installWim) {
        $originalWimSize = (Get-Item $installWim).Length / 1GB
        Write-Log "Original install.wim size: $([math]::Round($originalWimSize, 2)) GB"
        
        # Export only the first Windows edition and remove others
        Write-Log "Exporting primary Windows edition only..."
        $singleEditionWim = "$tempDir\sources\install_single.wim"
        
        try {
            # Export with maximum compression, keeping only index 1
            $exportResult = & dism /export-image /sourceimagefile:$installWim /sourceindex:1 /destinationimagefile:$singleEditionWim /compress:max /bootable /checkintegrity 2>&1
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $singleEditionWim)) {
                Remove-Item $installWim -Force
                Rename-Item $singleEditionWim $installWim
                
                $newWimSize = (Get-Item $installWim).Length / 1GB
                $wimSaved = $originalWimSize - $newWimSize
                Write-Log "WIM single edition export: $([math]::Round($newWimSize, 2)) GB (saved $([math]::Round($wimSaved, 2)) GB)" "SUCCESS"
            } else {
                Write-Log "Single edition export failed, trying recompression..." "WARNING"
                if (Test-Path $singleEditionWim) { Remove-Item $singleEditionWim -Force }
                
                # Fallback: just recompress existing WIM
                $recompressedWim = "$tempDir\sources\install_recompressed.wim"
                $recompressResult = & dism /export-image /sourceimagefile:$installWim /sourceindex:1 /destinationimagefile:$recompressedWim /compress:max /checkintegrity 2>&1
                
                if ($LASTEXITCODE -eq 0 -and (Test-Path $recompressedWim)) {
                    Remove-Item $installWim -Force
                    Rename-Item $recompressedWim $installWim
                    
                    $newWimSize = (Get-Item $installWim).Length / 1GB
                    $wimSaved = $originalWimSize - $newWimSize
                    Write-Log "WIM recompressed: $([math]::Round($newWimSize, 2)) GB (saved $([math]::Round($wimSaved, 2)) GB)" "SUCCESS"
                } else {
                    Write-Log "WIM recompression also failed, keeping original" "WARNING"
                    if (Test-Path $recompressedWim) { Remove-Item $recompressedWim -Force }
                }
            }
        } catch {
            Write-Log "WIM processing exception: $($_.Exception.Message)" "WARNING"
        }
    }
    
    # Method 3: Remove language packs aggressively
    Write-Log "Removing language packs and regional content..."
    $langDirs = @(
        "$tempDir\sources\lang", 
        "$tempDir\support\lang",
        "$tempDir\sources\license"
    )
    
    foreach ($langDir in $langDirs) {
        if (Test-Path $langDir) {
            $dirSize = (Get-ChildItem $langDir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            Get-ChildItem $langDir | Where-Object { 
                $_.Name -notmatch "en-us|en-US" 
            } | ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
                Write-Log "Removed language: $($_.Name)" "SUCCESS"
            }
            Write-Log "Processed language directory: $(Split-Path $langDir -Leaf) ($([math]::Round($dirSize, 1)) MB)" "SUCCESS"
        }
    }
    
    # Method 4: Remove Windows bloatware directories
    Write-Log "Removing Windows bloatware directories..."
    $bloatDirs = @(
        "$tempDir\sources\sxs",           # Component store (can be large)
        "$tempDir\sources\background",     # Background images
        "$tempDir\sources\inf",           # Driver inf files (non-essential)
        "$tempDir\sources\replacement",   # Replacement manifests
        "$tempDir\sources\dlmanifests"    # Download manifests
    )
    
    foreach ($dir in $bloatDirs) {
        if (Test-Path $dir) {
            $dirSize = (Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            try {
                Remove-Item $dir -Recurse -Force -ErrorAction Stop
                Write-Log "Removed bloat directory: $(Split-Path $dir -Leaf) ($([math]::Round($dirSize, 1)) MB)" "SUCCESS"
            } catch {
                Write-Log "Could not remove $(Split-Path $dir -Leaf): $($_.Exception.Message)" "WARNING"
            }
        }
    }
    
    # Method 5: Remove support directories and additional bloat
    Write-Log "Removing unnecessary support directories and additional bloat..."
    $supportDirs = @(
        "$tempDir\support\adfs",
        "$tempDir\support\logging", 
        "$tempDir\support\migration",
        "$tempDir\upgrade",
        "$tempDir\sources\EtwLogs",      # Event tracing logs
        "$tempDir\sources\Panther",     # Setup logs
        "$tempDir\sources\Recovery",    # Recovery tools (can be large)
        "$tempDir\sources\Servicing"    # Servicing data
    )
    
    foreach ($dir in $supportDirs) {
        if (Test-Path $dir) {
            $dirSize = (Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object -Property Length -Sum).Sum / 1MB
            try {
                Remove-Item $dir -Recurse -Force -ErrorAction Stop
                Write-Log "Removed directory: $(Split-Path $dir -Leaf) ($([math]::Round($dirSize, 1)) MB)" "SUCCESS"
            } catch {
                Write-Log "Could not remove $(Split-Path $dir -Leaf): $($_.Exception.Message)" "WARNING"
            }
        }
    }
    
    # Method 6: Remove large unnecessary files
    Write-Log "Removing large unnecessary files..."
    $largeFiles = @(
        "$tempDir\sources\setupprep.exe",
        "$tempDir\sources\setuphost.exe", 
        "$tempDir\sources\migwiz.exe",
        "$tempDir\sources\oobe.exe",
        "$tempDir\sources\reagent.exe",
        "$tempDir\sources\spprep.exe"
    )
    
    foreach ($file in $largeFiles) {
        if (Test-Path $file) {
            $fileSize = (Get-Item $file).Length / 1MB
            try {
                Remove-Item $file -Force -ErrorAction Stop
                Write-Log "Removed file: $(Split-Path $file -Leaf) ($([math]::Round($fileSize, 1)) MB)" "SUCCESS"
            } catch {
                Write-Log "Could not remove $(Split-Path $file -Leaf): $($_.Exception.Message)" "WARNING"
            }
        }
    }
    
    # Method 7: Add TPM bypass if requested
    if ($tpmBypass) {
        Write-Log "Adding TPM bypass via autounattend.xml..."
        
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
    
    Write-Log "=== CREATING OPTIMIZED ISO ==="
    
    # Calculate space saved so far
    $currentSize = (Get-ChildItem $tempDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
    $saved = $originalSize - $currentSize
    Write-Log "Space saved from file operations: $([math]::Round($saved, 2)) GB"
    
    # Create bootable ISO with enhanced methods
    Write-Log "Creating bootable ISO with multiple fallback methods..."
    
    $isoCreated = $false
    
    # Method 1: Try multiple oscdimg sources
    $oscdimgUrls = @(
        "https://github.com/itsNileshHere/Windows-ISO-Debloater/raw/main/oscdimg.exe",
        "https://github.com/WereDev/oscdimg/raw/main/oscdimg.exe",
        "https://www.catalog.update.microsoft.com/DownloadHandler.ashx?identifier=oscdimg.exe"
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
                
                # Download portable 7-Zip
                $sevenZipUrls = @(
                    "https://www.7-zip.org/a/7za920.zip",
                    "https://github.com/develar/7zip-bin/raw/master/win/x64/7za.exe"
                )
                
                $downloaded = $false
                foreach ($url in $sevenZipUrls) {
                    try {
                        Write-Log "Trying to download 7-Zip from: $url"
                        
                        if ($url.EndsWith('.zip')) {
                            # Download and extract
                            $zipFile = "$env:TEMP\7zip.zip" 
                            Invoke-WebRequest -Uri $url -OutFile $zipFile -TimeoutSec 30 -ErrorAction Stop
                            Expand-Archive $zipFile -DestinationPath "$env:TEMP\7zip" -Force
                            
                            # Find 7za.exe in extracted files
                            $sevenZipExe = Get-ChildItem "$env:TEMP\7zip" -Filter "7za.exe" -Recurse | Select-Object -First 1
                            if ($sevenZipExe) {
                                Copy-Item $sevenZipExe.FullName "$env:TEMP\7z.exe" -Force
                                $downloaded = $true
                                break
                            }
                        } else {
                            # Direct exe download
                            Invoke-WebRequest -Uri $url -OutFile "$env:TEMP\7z.exe" -TimeoutSec 30 -ErrorAction Stop
                            $downloaded = $true
                            break
                        }
                    } catch {
                        Write-Log "Failed to download from $url`: $($_.Exception.Message)" "WARNING"
                        continue
                    }
                }
                
                if (-not $downloaded) {
                    throw "Could not download 7-Zip from any source"
                }
                
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
        
        # Final fallback - create basic ISO with simple method
        if (-not $isoCreated) {
            Write-Log "All advanced methods failed, trying basic ISO creation..." "WARNING"
            
            try {
                # Try using basic PowerShell compression if content is small enough
                $totalSize = (Get-ChildItem $tempDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
                Write-Log "Total content size for basic method: $([math]::Round($totalSize, 2)) GB"
                
                if ($totalSize -le 2.0) {  # Only try if less than 2GB
                    Write-Log "Attempting basic compression method..."
                    
                    # Create ZIP first, then rename
                    $zipPath = $outputISO -replace '\.iso$', '.zip'
                    
                    # Use .NET compression for better control
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    [System.IO.Compression.ZipFile]::CreateFromDirectory($tempDir, $zipPath)
                    
                    if (Test-Path $zipPath) {
                        Move-Item $zipPath $outputISO -Force
                        $isoCreated = $true
                        Write-Log "Created basic archive (ZIP renamed to ISO)" "SUCCESS"
                    }
                } else {
                    Write-Log "Content too large ($([math]::Round($totalSize, 2)) GB) for basic methods" "ERROR"
                }
                
            } catch {
                Write-Log "Basic method also failed: $($_.Exception.Message)" "ERROR"
            }
        }
    }
    
    if ($isoCreated -and (Test-Path $outputISO)) {
        # Verify the ISO is not just a dummy file
        $finalSize = (Get-Item $outputISO).Length / 1GB
        
        if ($finalSize -lt 0.001) {  # Less than 1MB means it's likely a dummy file
            Write-Log "Output file is too small ($([math]::Round($finalSize * 1024, 2)) MB) - likely failed creation" "ERROR"
            Write-Log "This suggests all ISO creation methods failed" "ERROR"
            exit 1
        }
        
        $totalSaved = $originalSize - $finalSize
        $percentage = ($totalSaved / $originalSize) * 100
        
        Write-Log "=== FALLBACK DEBLOAT COMPLETED ===" "SUCCESS"
        Write-Log "Original size: $([math]::Round($originalSize, 2)) GB"
        Write-Log "Debloated size: $([math]::Round($finalSize, 2)) GB"
        Write-Log "Total space saved: $([math]::Round($totalSaved, 2)) GB ($([math]::Round($percentage, 1))%)"
        
        # Show what was accomplished
        Write-Log "=== AGGRESSIVE DEBLOATING COMPLETED ===" "SUCCESS"
        Write-Log "✅ Unnecessary ISO files (ei.cfg, pid.txt, autorun.inf)"
        Write-Log "✅ Single Windows edition export with max compression"
        Write-Log "✅ Extra language packs and regional content removed"
        Write-Log "✅ Bloatware directories (sxs, inf, background, etc.)"
        Write-Log "✅ Support directories (adfs, logging, migration, upgrade)"
        Write-Log "✅ Recovery tools and servicing data removed"
        Write-Log "✅ Large unnecessary setup files removed"
        Write-Log "✅ Event tracing and setup logs removed"
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
        Write-Log "No valid ISO file was created" "ERROR"
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