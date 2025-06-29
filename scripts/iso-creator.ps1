param(
    [string]$SourceDir,
    [string]$OutputISO,
    [string]$VolumeName = "Windows"
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

function Get-OscdimgTool {
    Write-Log "Attempting to locate or download oscdimg.exe..."
    
    # Method 1: Check if oscdimg is already installed (Windows ADK)
    $adkPaths = @(
        "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "${env:ProgramFiles}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe",
        "${env:ProgramFiles(x86)}\Windows Kits\8.1\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    )
    
    foreach ($path in $adkPaths) {
        if (Test-Path $path) {
            Write-Log "Found oscdimg in Windows ADK: $path" "SUCCESS"
            return $path
        }
    }
    
    # Method 2: Try alternative download sources
    $oscdimgPath = "$env:TEMP\oscdimg.exe"
    $downloadUrls = @(
        "https://github.com/pbatard/rufus/raw/master/res/loc/oscdimg.exe",
        "https://archive.org/download/oscdimg/oscdimg.exe",
        "https://github.com/WereDev/oscdimg/raw/main/oscdimg.exe"
    )
    
    foreach ($url in $downloadUrls) {
        try {
            Write-Log "Trying download from: $url"
            Invoke-WebRequest -Uri $url -OutFile $oscdimgPath -TimeoutSec 30 -ErrorAction Stop
            
            if (Test-Path $oscdimgPath -and (Get-Item $oscdimgPath).Length -gt 100KB) {
                Write-Log "Successfully downloaded oscdimg from: $url" "SUCCESS"
                return $oscdimgPath
            }
        } catch {
            Write-Log "Download failed from $url`: $($_.Exception.Message)" "WARNING"
        }
    }
    
    Write-Log "Could not locate or download oscdimg.exe" "WARNING"
    return $null
}

function Create-ISOWithOscdimg {
    param([string]$SourcePath, [string]$OutputPath)
    
    $oscdimgPath = Get-OscdimgTool
    if (-not $oscdimgPath) {
        return $false
    }
    
    Write-Log "Creating ISO with oscdimg..."
    
    try {
        # Check for boot files
        $etfsboot = Join-Path $SourcePath "boot\etfsboot.com"
        $efisys = Join-Path $SourcePath "efi\microsoft\boot\efisys.bin"
        
        if ((Test-Path $etfsboot) -and (Test-Path $efisys)) {
            Write-Log "Creating UEFI+BIOS bootable ISO..."
            $args = @(
                "-m", "-o", "-u2", "-udfver102",
                "-bootdata:2#p0,e,b$etfsboot#pEF,e,b$efisys",
                $SourcePath, $OutputPath
            )
        } else {
            Write-Log "Creating basic bootable ISO..."
            $args = @("-m", "-o", "-u2", "-udfver102", $SourcePath, $OutputPath)
        }
        
        $result = & $oscdimgPath @args 2>&1
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) {
            Write-Log "ISO created successfully with oscdimg" "SUCCESS"
            return $true
        } else {
            Write-Log "oscdimg failed: $result" "WARNING"
            return $false
        }
    } catch {
        Write-Log "oscdimg exception: $($_.Exception.Message)" "WARNING"
        return $false
    }
}

function Create-ISOWithPowerShell {
    param([string]$SourcePath, [string]$OutputPath, [string]$Label)
    
    Write-Log "Creating ISO with PowerShell method..."
    
    try {
        # Method 1: Standard IMAPI2FS with optimizations
        $fileSystemImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        $fileSystemImage.VolumeName = $Label
        
        # Set larger limits for Windows ISOs
        try {
            # Try to set higher limits (may not work on all systems)
            $fileSystemImage.FreeMediaBlocks = -1
            $fileSystemImage.MaxMediaBlocksFromDevice = 4294967295  # Max DVD size
        } catch {
            Write-Log "Could not set size limits, using defaults" "WARNING"
        }
        
        Write-Log "Adding files to ISO image..."
        $fileSystemImage.Root.AddTree($SourcePath, $false)
        
        Write-Log "Creating result image..."
        $resultImage = $fileSystemImage.CreateResultImage()
        $resultStream = $resultImage.ImageStream
        
        Write-Log "Writing ISO file..."
        $fileStream = New-Object System.IO.FileStream($OutputPath, [System.IO.FileMode]::Create)
        
        # Use larger buffer for better performance
        $bufferSize = 4MB
        $buffer = New-Object byte[] $bufferSize
        $totalWritten = 0
        
        do {
            $bytesRead = $resultStream.Read($buffer, 0, $buffer.Length)
            if ($bytesRead -gt 0) {
                $fileStream.Write($buffer, 0, $bytesRead)
                $totalWritten += $bytesRead
                
                # Progress indicator every 100MB
                if ($totalWritten % 100MB -lt $bufferSize) {
                    Write-Log "Written: $([math]::Round($totalWritten / 1MB, 0)) MB"
                }
            }
        } while ($bytesRead -gt 0)
        
        $fileStream.Close()
        $resultStream.Close()
        
        Write-Log "ISO created successfully with PowerShell method: $([math]::Round($totalWritten / 1MB, 0)) MB" "SUCCESS"
        return $true
        
    } catch {
        Write-Log "PowerShell ISO creation failed: $($_.Exception.Message)" "ERROR"
        
        # Method 2: Try with WinRAR/7-Zip if available
        if (Test-Path "${env:ProgramFiles}\7-Zip\7z.exe") {
            Write-Log "Trying 7-Zip ISO creation as fallback..."
            try {
                $7zipPath = "${env:ProgramFiles}\7-Zip\7z.exe"
                & $7zipPath a -tiso "$OutputPath" "$SourcePath\*"
                
                if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) {
                    Write-Log "ISO created successfully with 7-Zip" "SUCCESS"
                    return $true
                }
            } catch {
                Write-Log "7-Zip method also failed: $($_.Exception.Message)" "WARNING"
            }
        }
        
        return $false
    }
}

function Create-ISOWithMkisofs {
    param([string]$SourcePath, [string]$OutputPath)
    
    Write-Log "Attempting mkisofs/genisoimage method..."
    
    # Check for mkisofs or genisoimage (might be available in some environments)
    $mkisofsTools = @("mkisofs", "genisoimage", "xorrisofs")
    
    foreach ($tool in $mkisofsTools) {
        try {
            $toolPath = Get-Command $tool -ErrorAction SilentlyContinue
            if ($toolPath) {
                Write-Log "Found $tool, creating ISO..."
                
                $etfsboot = Join-Path $SourcePath "boot\etfsboot.com"
                
                if (Test-Path $etfsboot) {
                    & $tool -o $OutputPath -b "boot/etfsboot.com" -no-emul-boot -boot-load-size 8 -boot-info-table -iso-level 4 -udf -joliet -D -N $SourcePath
                } else {
                    & $tool -o $OutputPath -iso-level 4 -udf -joliet -D -N $SourcePath
                }
                
                if ($LASTEXITCODE -eq 0 -and (Test-Path $OutputPath)) {
                    Write-Log "ISO created successfully with $tool" "SUCCESS"
                    return $true
                }
            }
        } catch {
            Write-Log "$tool failed: $($_.Exception.Message)" "WARNING"
        }
    }
    
    return $false
}

# Main execution
Write-Log "=== ISO CREATION TOOL ==="
Write-Log "Source: $SourceDir"
Write-Log "Output: $OutputISO"

if (-not (Test-Path $SourceDir)) {
    Write-Log "Source directory not found: $SourceDir" "ERROR"
    exit 1
}

# Calculate source size
$sourceSize = (Get-ChildItem $SourceDir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
Write-Log "Source size: $([math]::Round($sourceSize, 2)) GB"

# Remove existing output file
if (Test-Path $OutputISO) {
    Remove-Item $OutputISO -Force
}

# Try multiple methods in order of preference
$methods = @(
    { Create-ISOWithOscdimg -SourcePath $SourceDir -OutputPath $OutputISO },
    { Create-ISOWithPowerShell -SourcePath $SourceDir -OutputPath $OutputISO -Label $VolumeName },
    { Create-ISOWithMkisofs -SourcePath $SourceDir -OutputPath $OutputISO }
)

$success = $false
$methodIndex = 1

foreach ($method in $methods) {
    Write-Log "=== TRYING METHOD $methodIndex ==="
    
    try {
        if (& $method) {
            $success = $true
            break
        }
    } catch {
        Write-Log "Method $methodIndex exception: $($_.Exception.Message)" "WARNING"
    }
    
    # Clean up failed attempt
    if (Test-Path $OutputISO) {
        Remove-Item $OutputISO -Force -ErrorAction SilentlyContinue
    }
    
    $methodIndex++
}

if ($success) {
    $finalSize = (Get-Item $OutputISO).Length / 1GB
    Write-Log "=== ISO CREATION COMPLETED ===" "SUCCESS"
    Write-Log "Output file: $OutputISO"
    Write-Log "Final size: $([math]::Round($finalSize, 2)) GB"
    exit 0
} else {
    Write-Log "=== ALL ISO CREATION METHODS FAILED ===" "ERROR"
    exit 1
} 