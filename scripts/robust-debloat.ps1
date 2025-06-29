param(
    [string]$isoPath = "windows.iso",
    [string]$outputISO = "debloated-windows.iso",
    [string]$winEdition = "",
    [switch]$testMode = $false,
    [switch]$removeEdge = $true,
    [switch]$removeOneDrive = $true,
    [switch]$tpmBypass = $false
)

# Global error tracking
$script:ErrorCount = 0
$script:WarningCount = 0

function Write-StatusLog {
    param([string]$Message, [string]$Level = "INFO")
    
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green" }
        default { "White" }
    }
    
    Write-Host "[$timestamp] [$Level] $Message" -ForegroundColor $color
    
    if ($Level -eq "ERROR") { $script:ErrorCount++ }
    if ($Level -eq "WARNING") { $script:WarningCount++ }
}

function Test-AdminRights {
    $isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
    if (-not $isAdmin) {
        Write-StatusLog "Script must run as Administrator!" "ERROR"
        exit 1
    }
    Write-StatusLog "Running with Administrator privileges" "SUCCESS"
}

function Test-DiskSpace {
    param([string]$Path, [int]$RequiredGB)
    
    $drive = Split-Path $Path -Qualifier
    $freeSpace = (Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$drive'").FreeSpace / 1GB
    
    Write-StatusLog "Available disk space on $drive`: $([math]::Round($freeSpace, 2)) GB"
    
    if ($freeSpace -lt $RequiredGB) {
        Write-StatusLog "Insufficient disk space. Required: ${RequiredGB}GB, Available: $([math]::Round($freeSpace, 2))GB" "ERROR"
        return $false
    }
    return $true
}

function Initialize-WorkEnvironment {
    param([string[]]$Directories)
    
    Write-StatusLog "Initializing work environment..."
    
    foreach ($dir in $Directories) {
        try {
            if (Test-Path $dir) {
                Write-StatusLog "Cleaning existing directory: $dir"
                
                # Force cleanup with retries
                for ($i = 1; $i -le 3; $i++) {
                    try {
                        takeown /f $dir /r /d y 2>$null | Out-Null
                        icacls $dir /grant administrators:F /t 2>$null | Out-Null
                        Remove-Item $dir -Recurse -Force -ErrorAction Stop
                        break
                    } catch {
                        Write-StatusLog "Cleanup attempt $i failed: $($_.Exception.Message)" "WARNING"
                        Start-Sleep -Seconds 2
                        if ($i -eq 3) { throw }
                    }
                }
            }
            
            Write-StatusLog "Creating directory: $dir"
            New-Item -ItemType Directory -Path $dir -Force | Out-Null
            
            # Set comprehensive permissions
            icacls $dir /grant administrators:F /t 2>$null | Out-Null
            icacls $dir /grant "NT AUTHORITY\SYSTEM":F /t 2>$null | Out-Null
            icacls $dir /grant everyone:F /t 2>$null | Out-Null
            
            Write-StatusLog "Directory initialized: $dir" "SUCCESS"
            
        } catch {
            Write-StatusLog "Failed to initialize directory $dir`: $($_.Exception.Message)" "ERROR"
            throw
        }
    }
}

function Copy-ISOContents {
    param([string]$IsoPath, [string]$Destination)
    
    Write-StatusLog "Starting ISO copy process..."
    
    try {
        # Mount ISO
        Write-StatusLog "Mounting ISO: $IsoPath"
        $mount = Mount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path -PassThru -ErrorAction Stop
        $drive = ($mount | Get-Volume).DriveLetter + ":\"
        Write-StatusLog "ISO mounted at: $drive" "SUCCESS"
        
        # Verify mount
        if (-not (Test-Path $drive)) {
            throw "ISO mount failed - drive not accessible"
        }
        
        # Check source size
        $sourceSize = (Get-ChildItem $drive -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-StatusLog "Source ISO content size: $([math]::Round($sourceSize, 2)) GB"
        
        # Copy with robocopy and detailed logging
        Write-StatusLog "Copying ISO contents with robocopy..."
        $robocopyArgs = @($drive, $Destination, "/E", "/R:3", "/W:5", "/MT:4", "/NP", "/NDL", "/NC", "/NS")
        
        $robocopyResult = & robocopy @robocopyArgs 2>&1
        $robocopyExitCode = $LASTEXITCODE
        
        Write-StatusLog "Robocopy exit code: $robocopyExitCode"
        
        # Robocopy exit codes: 0-7 are success, 8+ are errors
        if ($robocopyExitCode -gt 7) {
            Write-StatusLog "Robocopy failed with exit code $robocopyExitCode" "ERROR"
            $robocopyResult | ForEach-Object { Write-StatusLog "Robocopy: $_" "ERROR" }
            throw "Robocopy operation failed"
        }
        
        Write-StatusLog "Robocopy completed successfully" "SUCCESS"
        
        # Dismount ISO
        Dismount-DiskImage -ImagePath (Resolve-Path $IsoPath).Path
        Write-StatusLog "ISO dismounted" "SUCCESS"
        
        # Verify copy
        if (-not (Test-Path (Join-Path $Destination "sources"))) {
            throw "Copy verification failed - sources directory missing"
        }
        
        $destSize = (Get-ChildItem $Destination -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
        Write-StatusLog "Copied content size: $([math]::Round($destSize, 2)) GB" "SUCCESS"
        
    } catch {
        Write-StatusLog "ISO copy failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Find-InstallWim {
    param([string]$BasePath)
    
    Write-StatusLog "Locating Windows installation image..."
    
    $installWim = Join-Path $BasePath "sources\install.wim"
    $installEsd = Join-Path $BasePath "sources\install.esd"
    
    if (Test-Path $installEsd) {
        Write-StatusLog "Found install.esd, converting to install.wim..."
        
        try {
            $convertResult = & dism /export-image /sourceimagefile:$installEsd /sourceindex:1 /destinationimagefile:$installWim /compress:max /checkintegrity 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Remove-Item $installEsd -Force
                Write-StatusLog "Successfully converted install.esd to install.wim" "SUCCESS"
            } else {
                Write-StatusLog "ESD to WIM conversion failed" "ERROR"
                $convertResult | ForEach-Object { Write-StatusLog "DISM: $_" "ERROR" }
                throw "ESD conversion failed"
            }
        } catch {
            Write-StatusLog "ESD conversion exception: $($_.Exception.Message)" "ERROR"
            throw
        }
    }
    
    if (Test-Path $installWim) {
        # Set permissions on WIM file
        takeown /f $installWim 2>$null | Out-Null
        icacls $installWim /grant administrators:F 2>$null | Out-Null
        icacls $installWim /grant everyone:F 2>$null | Out-Null
        
        $wimSize = (Get-Item $installWim).Length / 1GB
        Write-StatusLog "Found install.wim: $([math]::Round($wimSize, 2)) GB" "SUCCESS"
        return $installWim
    }
    
    throw "No install.wim or install.esd found in sources directory"
}

function Get-WindowsEditions {
    param([string]$WimPath)
    
    Write-StatusLog "Analyzing Windows editions..."
    
    try {
        $wimInfo = & dism /get-wiminfo /wimfile:$WimPath 2>&1
        
        if ($LASTEXITCODE -ne 0) {
            Write-StatusLog "Failed to get WIM info" "ERROR"
            $wimInfo | ForEach-Object { Write-StatusLog "DISM: $_" "ERROR" }
            throw "WIM info retrieval failed"
        }
        
        $editions = @()
        $currentIndex = $null
        
        foreach ($line in $wimInfo) {
            if ($line -match "Index\s*:\s*(\d+)") {
                $currentIndex = $matches[1]
            }
            if ($line -match "Name\s*:\s*(.+)" -and $currentIndex) {
                $name = $matches[1].Trim()
                $editions += [PSCustomObject]@{Index = $currentIndex; Name = $name}
                $currentIndex = $null
            }
        }
        
        Write-StatusLog "Found $($editions.Count) Windows editions:" "SUCCESS"
        $editions | ForEach-Object { Write-StatusLog "  [$($_.Index)] $($_.Name)" }
        
        return $editions
        
    } catch {
        Write-StatusLog "Edition analysis failed: $($_.Exception.Message)" "ERROR"
        throw
    }
}

function Mount-WindowsImage {
    param([string]$WimPath, [int]$ImageIndex, [string]$MountDir)
    
    Write-StatusLog "Mounting Windows image for modification..."
    
    # Clean any existing mounts
    Write-StatusLog "Cleaning existing DISM mounts..."
    & dism /cleanup-wim 2>$null | Out-Null
    & dism /cleanup-mountpoints 2>$null | Out-Null
    
    # Try multiple mount strategies
    $mountStrategies = @(
        @{args = @("/mount-wim", "/wimfile:$WimPath", "/index:$ImageIndex", "/mountdir:$MountDir"); desc = "Basic mount"},
        @{args = @("/mount-wim", "/wimfile:$WimPath", "/index:$ImageIndex", "/mountdir:$MountDir", "/CheckIntegrity"); desc = "Mount with integrity check"},
        @{args = @("/mount-wim", "/wimfile:$WimPath", "/index:$ImageIndex", "/mountdir:$MountDir", "/ReadOnly"); desc = "Read-only mount"}
    )
    
    foreach ($strategy in $mountStrategies) {
        Write-StatusLog "Attempting $($strategy.desc)..."
        
        try {
            $mountResult = & dism @($strategy.args) 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-StatusLog "WIM mounted successfully with $($strategy.desc)" "SUCCESS"
                return $true
            } else {
                Write-StatusLog "$($strategy.desc) failed with exit code $LASTEXITCODE" "WARNING"
                $mountResult | ForEach-Object { Write-StatusLog "DISM: $_" "WARNING" }
                
                # Cleanup before next attempt
                & dism /unmount-wim /mountdir:$MountDir /discard 2>$null | Out-Null
                Start-Sleep -Seconds 3
            }
        } catch {
            Write-StatusLog "$($strategy.desc) exception: $($_.Exception.Message)" "WARNING"
        }
    }
    
    Write-StatusLog "All mount strategies failed" "ERROR"
    return $false
}

function Remove-WindowsBloatware {
    param([string]$MountDir)
    
    Write-StatusLog "Starting bloatware removal process..."
    
    # AppX packages to remove
    $appxPatterns = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.549981C3F5F10",
        "Microsoft.WindowsAlarms", "Microsoft.WindowsFeedbackHub", "Microsoft.GetHelp",
        "Microsoft.Getstarted", "Microsoft.WindowsMaps", "Microsoft.WindowsCommunicationsApps",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "Microsoft.Xbox", "Microsoft.People",
        "Microsoft.YourPhone", "Microsoft.SkypeApp", "Microsoft.Todos", "Microsoft.Wallet",
        "Microsoft.MicrosoftSolitaireCollection", "Clipchamp.Clipchamp", "Microsoft.Copilot"
    )
    
    # Remove AppX packages
    Write-StatusLog "Removing AppX packages..."
    $appxRemoved = 0
    
    try {
        $appxList = & dism /image:$MountDir /get-provisionedappxpackages 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            foreach ($pattern in $appxPatterns) {
                $matches = $appxList | Select-String "PackageName\s*:\s*.*$pattern"
                foreach ($match in $matches) {
                    $packageName = ($match.Line -split ":\s*", 2)[1].Trim()
                    Write-StatusLog "Removing AppX: $packageName"
                    
                    $removeResult = & dism /image:$MountDir /remove-provisionedappxpackage /packagename:$packageName 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $appxRemoved++
                    } else {
                        Write-StatusLog "Failed to remove $packageName" "WARNING"
                    }
                }
            }
            Write-StatusLog "Removed $appxRemoved AppX packages" "SUCCESS"
        } else {
            Write-StatusLog "Could not list AppX packages" "WARNING"
        }
    } catch {
        Write-StatusLog "AppX removal exception: $($_.Exception.Message)" "WARNING"
    }
    
    # Windows Capabilities to remove
    $capabilities = @(
        "App.StepsRecorder", "Language.Handwriting", "Language.OCR",
        "Language.Speech", "Language.TextToSpeech", "Microsoft.Windows.WordPad",
        "MathRecognizer", "Media.WindowsMediaPlayer", "Microsoft.Windows.PowerShell.ISE"
    )
    
    Write-StatusLog "Removing Windows capabilities..."
    $capRemoved = 0
    
    try {
        $capList = & dism /image:$MountDir /get-capabilities 2>&1
        
        if ($LASTEXITCODE -eq 0) {
            foreach ($capability in $capabilities) {
                $matches = $capList | Select-String "Capability Identity\s*:\s*.*$capability"
                foreach ($match in $matches) {
                    $capName = ($match.Line -split ":\s*", 2)[1].Trim()
                    Write-StatusLog "Removing capability: $capName"
                    
                    $removeResult = & dism /image:$MountDir /remove-capability /capabilityname:$capName 2>&1
                    if ($LASTEXITCODE -eq 0) {
                        $capRemoved++
                    } else {
                        Write-StatusLog "Failed to remove $capName" "WARNING"
                    }
                }
            }
            Write-StatusLog "Removed $capRemoved capabilities" "SUCCESS"
        } else {
            Write-StatusLog "Could not list capabilities" "WARNING"
        }
    } catch {
        Write-StatusLog "Capability removal exception: $($_.Exception.Message)" "WARNING"
    }
    
    # File-based removals
    if ($removeOneDrive) {
        Write-StatusLog "Removing OneDrive..."
        $oneDriveFiles = @(
            "$MountDir\Windows\System32\OneDriveSetup.exe",
            "$MountDir\Windows\SysWOW64\OneDriveSetup.exe"
        )
        
        foreach ($file in $oneDriveFiles) {
            if (Test-Path $file) {
                Remove-Item $file -Force -ErrorAction SilentlyContinue
                Write-StatusLog "Removed: $(Split-Path $file -Leaf)" "SUCCESS"
            }
        }
    }
    
    if ($removeEdge) {
        Write-StatusLog "Removing Microsoft Edge..."
        $edgeDirs = @(
            "$MountDir\Program Files\Microsoft\Edge",
            "$MountDir\Program Files (x86)\Microsoft\Edge"
        )
        
        foreach ($dir in $edgeDirs) {
            if (Test-Path $dir) {
                Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
                Write-StatusLog "Removed Edge directory: $(Split-Path $dir -Leaf)" "SUCCESS"
            }
        }
    }
}

function Apply-RegistryTweaks {
    param([string]$MountDir)
    
    Write-StatusLog "Applying registry tweaks..."
    
    try {
        # Load registry hives
        Write-StatusLog "Loading registry hives..."
        & reg load HKLM\WIM_SOFTWARE "$MountDir\Windows\System32\config\SOFTWARE" 2>$null | Out-Null
        & reg load HKLM\WIM_SYSTEM "$MountDir\Windows\System32\config\SYSTEM" 2>$null | Out-Null
        
        # Privacy tweaks
        $regCommands = @(
            "reg add `"HKLM\WIM_SOFTWARE\Policies\Microsoft\Windows\DataCollection`" /v AllowTelemetry /t REG_DWORD /d 0 /f",
            "reg add `"HKLM\WIM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection`" /v AllowTelemetry /t REG_DWORD /d 0 /f"
        )
        
        if ($tpmBypass) {
            $regCommands += @(
                "reg add `"HKLM\WIM_SYSTEM\Setup\LabConfig`" /v BypassTPMCheck /t REG_DWORD /d 1 /f",
                "reg add `"HKLM\WIM_SYSTEM\Setup\LabConfig`" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f",
                "reg add `"HKLM\WIM_SYSTEM\Setup\LabConfig`" /v BypassRAMCheck /t REG_DWORD /d 1 /f"
            )
        }
        
        foreach ($cmd in $regCommands) {
            Invoke-Expression $cmd 2>$null | Out-Null
        }
        
        Write-StatusLog "Registry tweaks applied" "SUCCESS"
        
    } catch {
        Write-StatusLog "Registry tweaks failed: $($_.Exception.Message)" "WARNING"
    } finally {
        # Unload registry hives
        & reg unload HKLM\WIM_SOFTWARE 2>$null | Out-Null
        & reg unload HKLM\WIM_SYSTEM 2>$null | Out-Null
    }
}

function Dismount-WindowsImage {
    param([string]$MountDir, [bool]$Commit = $true)
    
    Write-StatusLog "Dismounting Windows image..."
    
    try {
        if ($Commit) {
            $dismountResult = & dism /unmount-wim /mountdir:$MountDir /commit 2>&1
        } else {
            $dismountResult = & dism /unmount-wim /mountdir:$MountDir /discard 2>&1
        }
        
        if ($LASTEXITCODE -eq 0) {
            Write-StatusLog "Windows image dismounted successfully" "SUCCESS"
        } else {
            Write-StatusLog "Dismount returned exit code $LASTEXITCODE" "WARNING"
            $dismountResult | ForEach-Object { Write-StatusLog "DISM: $_" "WARNING" }
            
            # Force cleanup
            & dism /cleanup-wim 2>$null | Out-Null
            & dism /cleanup-mountpoints 2>$null | Out-Null
        }
    } catch {
        Write-StatusLog "Dismount exception: $($_.Exception.Message)" "WARNING"
    }
}

function Create-BootableISO {
    param([string]$SourceDir, [string]$OutputPath)
    
    Write-StatusLog "Creating bootable ISO..."
    
    try {
        # Try oscdimg first
        $oscdimgPath = "$env:TEMP\oscdimg.exe"
        
        if (-not (Test-Path $oscdimgPath)) {
            Write-StatusLog "Downloading oscdimg.exe..."
            try {
                Invoke-WebRequest -Uri "https://github.com/itsNileshHere/Windows-ISO-Debloater/raw/main/oscdimg.exe" -OutFile $oscdimgPath -ErrorAction Stop
            } catch {
                Write-StatusLog "oscdimg download failed: $($_.Exception.Message)" "WARNING"
            }
        }
        
        if (Test-Path $oscdimgPath) {
            Write-StatusLog "Creating ISO with oscdimg..."
            
            $etfsboot = "$SourceDir\boot\etfsboot.com"
            $efisys = "$SourceDir\efi\microsoft\boot\efisys.bin"
            
            if ((Test-Path $etfsboot) -and (Test-Path $efisys)) {
                $oscdimgArgs = @("-m", "-o", "-u2", "-udfver102", "-bootdata:2#p0,e,b$etfsboot#pEF,e,b$efisys", $SourceDir, $OutputPath)
            } else {
                $oscdimgArgs = @("-m", "-o", "-u2", "-udfver102", $SourceDir, $OutputPath)
            }
            
            $oscdimgResult = & $oscdimgPath @oscdimgArgs 2>&1
            
            if ($LASTEXITCODE -eq 0) {
                Write-StatusLog "ISO created successfully with oscdimg" "SUCCESS"
                return $true
            } else {
                Write-StatusLog "oscdimg failed: $oscdimgResult" "WARNING"
            }
        }
        
        # Fallback to PowerShell method
        Write-StatusLog "Trying PowerShell ISO creation method..."
        
        $fileSystemImage = New-Object -ComObject IMAPI2FS.MsftFileSystemImage
        $fileSystemImage.VolumeName = "Windows"
        $fileSystemImage.Root.AddTree($SourceDir, $false)
        
        $resultImage = $fileSystemImage.CreateResultImage()
        $resultStream = $resultImage.ImageStream
        
        $fileStream = New-Object System.IO.FileStream($OutputPath, [System.IO.FileMode]::Create)
        $buffer = New-Object byte[] 1MB
        
        do {
            $bytesRead = $resultStream.Read($buffer, 0, $buffer.Length)
            $fileStream.Write($buffer, 0, $bytesRead)
        } while ($bytesRead -gt 0)
        
        $fileStream.Close()
        $resultStream.Close()
        
        Write-StatusLog "ISO created successfully with PowerShell method" "SUCCESS"
        return $true
        
    } catch {
        Write-StatusLog "ISO creation failed: $($_.Exception.Message)" "ERROR"
        return $false
    }
}

# Main execution
Write-StatusLog "=== ROBUST WINDOWS ISO DEBLOATER ==="
Write-StatusLog "PowerShell Version: $($PSVersionTable.PSVersion)"

try {
    # Step 1: Validate environment
    Test-AdminRights
    
    if (-not (Test-Path $isoPath)) {
        Write-StatusLog "ISO file not found: $isoPath" "ERROR"
        exit 1
    }
    
    $originalSize = (Get-Item $isoPath).Length / 1GB
    Write-StatusLog "Original ISO size: $([math]::Round($originalSize, 2)) GB"
    
    # Step 2: Check disk space (need 3x ISO size for safety)
    $requiredSpace = [math]::Ceiling($originalSize * 3)
    if (-not (Test-DiskSpace -Path "C:\" -RequiredGB $requiredSpace)) {
        exit 1
    }
    
    # Step 3: Initialize work environment
    $tempDir = "C:\temp-debloat"
    $mountDir = "C:\temp-mount"
    Initialize-WorkEnvironment -Directories @($tempDir, $mountDir)
    
    # Step 4: Copy ISO contents
    Copy-ISOContents -IsoPath $isoPath -Destination $tempDir
    
    # Step 5: Find and process Windows image
    $installWim = Find-InstallWim -BasePath $tempDir
    $editions = Get-WindowsEditions -WimPath $installWim
    
    # Select edition
    $imageIndex = 1
    if ($winEdition) {
        $selected = $editions | Where-Object { $_.Name -like "*$winEdition*" }
        if ($selected) {
            $imageIndex = $selected.Index
            Write-StatusLog "Selected edition: $($selected.Name) (Index: $imageIndex)" "SUCCESS"
        } else {
            Write-StatusLog "Edition '$winEdition' not found, using index 1" "WARNING"
        }
    } else {
        Write-StatusLog "Using first edition: $($editions[0].Name)" "SUCCESS"
    }
    
    if ($testMode) {
        Write-StatusLog "=== TEST MODE: Validation completed successfully ===" "SUCCESS"
        Write-StatusLog "Errors: $script:ErrorCount, Warnings: $script:WarningCount"
        exit 0
    }
    
    # Step 6: Mount and modify Windows image
    if (Mount-WindowsImage -WimPath $installWim -ImageIndex $imageIndex -MountDir $mountDir) {
        Remove-WindowsBloatware -MountDir $mountDir
        Apply-RegistryTweaks -MountDir $mountDir
        Dismount-WindowsImage -MountDir $mountDir -Commit $true
    } else {
        Write-StatusLog "Failed to mount Windows image - creating unmodified ISO" "WARNING"
    }
    
    # Step 7: Create output ISO
    if (Create-BootableISO -SourceDir $tempDir -OutputPath $outputISO) {
        $finalSize = (Get-Item $outputISO).Length / 1GB
        $saved = $originalSize - $finalSize
        $percentage = ($saved / $originalSize) * 100
        
        Write-StatusLog "=== DEBLOAT COMPLETED ===" "SUCCESS"
        Write-StatusLog "Original size: $([math]::Round($originalSize, 2)) GB"
        Write-StatusLog "Final size: $([math]::Round($finalSize, 2)) GB"
        Write-StatusLog "Space saved: $([math]::Round($saved, 2)) GB ($([math]::Round($percentage, 1))%)"
        Write-StatusLog "Errors: $script:ErrorCount, Warnings: $script:WarningCount"
        
        if ($env:GITHUB_ACTIONS) {
            "ISO_CREATED=true" | Out-File -FilePath $env:GITHUB_ENV -Append
        }
    } else {
        Write-StatusLog "Failed to create output ISO" "ERROR"
        exit 1
    }
    
} catch {
    Write-StatusLog "Critical error: $($_.Exception.Message)" "ERROR"
    exit 1
} finally {
    # Cleanup
    Write-StatusLog "Cleaning up..."
    
    # Force cleanup
    & dism /cleanup-wim 2>$null | Out-Null
    & dism /cleanup-mountpoints 2>$null | Out-Null
    
    foreach ($dir in @($tempDir, $mountDir)) {
        if (Test-Path $dir) {
            try {
                takeown /f $dir /r /d y 2>$null | Out-Null
                icacls $dir /grant administrators:F /t 2>$null | Out-Null
                Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
            } catch {
                Write-StatusLog "Cleanup warning for $dir`: $($_.Exception.Message)" "WARNING"
            }
        }
    }
    
    Write-StatusLog "Cleanup completed"
} 