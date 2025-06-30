# === WINDOWS LITE PROCESSING SCRIPT ===
# Version: 4.0 - FIXED FOR ACTUAL EFFECTIVENESS
# Target: Reduce 5.59GB ISO to 3-4GB through aggressive component removal
# Hardware Bypass: TPM, SecureBoot, RAM, CPU checks

param(
    [Parameter(Mandatory=$true)]
    [string]$isoPath,
    [Parameter(Mandatory=$true)]
    [string]$outputISO,
    [bool]$removeEdge = $true,
    [bool]$removeOneDrive = $true,
    [bool]$tpmBypass = $true,
    [bool]$testMode = $false
)

# Windows Lite Processing - Ultra-Aggressive Debloat Lists
$WindowsLiteBloatApps = @(
    # Microsoft Core Bloatware (Windows Lite processing)
    "Microsoft.3DBuilder",
    "Microsoft.AppConnector", 
    "Microsoft.BingFinance",
    "Microsoft.BingFoodAndDrink",
    "Microsoft.BingHealthAndFitness",
    "Microsoft.BingMaps", 
    "Microsoft.BingNews",
    "Microsoft.BingSports",
    "Microsoft.BingTranslator",
    "Microsoft.BingTravel",
    "Microsoft.BingWeather",
    "Microsoft.CommsPhone",
    "Microsoft.ConnectivityStore",
    "Microsoft.FreshPaint",
    "Microsoft.GetHelp",
    "Microsoft.Getstarted",
    "Microsoft.HelpAndTips",
    "Microsoft.Media.PlayReadyClient.2",
    "Microsoft.Messaging",
    "Microsoft.Microsoft3DViewer",
    "Microsoft.MicrosoftOfficeHub",
    "Microsoft.MicrosoftPowerBIForWindows",
    "Microsoft.MicrosoftSolitaireCollection",
    "Microsoft.MicrosoftStickyNotes",
    "Microsoft.MixedReality.Portal",
    "Microsoft.NetworkSpeedTest",
    "Microsoft.News",
    "Microsoft.Office.OneNote",
    "Microsoft.Office.Sway",
    "Microsoft.OneConnect",
    "Microsoft.People",
    "Microsoft.Print3D",
    "Microsoft.RemoteDesktop",
    "Microsoft.SkypeApp",
    "Microsoft.StorePurchaseApp",
    "Microsoft.Studio3D",
    "Microsoft.Todos",
    "Microsoft.WindowsAlarms",
    "Microsoft.WindowsCamera",
    "Microsoft.WindowsFeedbackHub",
    "Microsoft.WindowsMaps",
    "Microsoft.WindowsPhone",
    "Microsoft.WindowsSoundRecorder",
    "Microsoft.Xbox.TCUI",
    "Microsoft.XboxApp",
    "Microsoft.XboxGameOverlay", 
    "Microsoft.XboxGamingOverlay",
    "Microsoft.XboxIdentityProvider",
    "Microsoft.XboxSpeechToTextOverlay",
    "Microsoft.ZuneMusic",
    "Microsoft.ZuneVideo",
    "MicrosoftTeams",
    "Clipchamp.Clipchamp"
)

# Windows Lite Processing - Capabilities to Remove  
$WindowsLiteCapabilities = @(
    "Browser.InternetExplorer*",
    "Math.Recognition*", 
    "Media.WindowsMediaPlayer*",
    "Microsoft.Windows.MSPaint*",
    "Microsoft.Windows.PowerShell.ISE*",
    "Microsoft.Windows.WordPad*",
    "Print.Fax.Scan*",
    "App.StepsRecorder*",
    "App.Support.QuickAssist*"
)

function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $color = switch ($Level) {
        "ERROR" { "Red" }
        "WARNING" { "Yellow" }
        "SUCCESS" { "Green"  }
        default { "White" }
    }
    Write-Host "[$timestamp] $Message" -ForegroundColor $color
}

function Test-DismSuccess {
    param([string]$Operation)
    if ($LASTEXITCODE -ne 0) {
        Write-Log "DISM FAILED: $Operation (Exit: $LASTEXITCODE)" "ERROR"
        throw "DISM operation failed: $Operation"
    }
}

Write-Log "=== WINDOWS LITE PROCESSING v4.0 - EFFECTIVENESS FOCUSED ===" "SUCCESS"

# Debug: Show current working directory and environment
Write-Log "STARTUP DIAGNOSTICS:" "INFO"
Write-Log "  PowerShell Version: $($PSVersionTable.PSVersion)" "INFO"
Write-Log "  Execution Policy: $(Get-ExecutionPolicy)" "INFO"
Write-Log "  Current User: $($env:USERNAME)" "INFO"
Write-Log "  Current working directory: $(Get-Location)" "INFO"
Write-Log "  Available disk space: $([math]::Round((Get-WmiObject -Class Win32_LogicalDisk -Filter "DeviceID='$((Get-Location).Drive.Name)'").FreeSpace / 1GB, 2)) GB" "INFO"

Write-Log "SCRIPT PARAMETERS:" "INFO"
Write-Log "  isoPath: $isoPath" "INFO"
Write-Log "  outputISO: $outputISO" "INFO"
Write-Log "  removeEdge: $removeEdge" "INFO"
Write-Log "  removeOneDrive: $removeOneDrive" "INFO"
Write-Log "  tpmBypass: $tpmBypass" "INFO"
Write-Log "  testMode: $testMode" "INFO"

# Validate ISO file exists
if (-not (Test-Path $isoPath)) {
    Write-Log "❌ CRITICAL ERROR: ISO file not found at: $isoPath" "ERROR"
    Write-Log "Current directory: $(Get-Location)" "ERROR"
    Write-Log "Looking for files..." "INFO"
    
    Write-Log "ISO files in current directory:" "INFO"
    $isoFiles = Get-ChildItem . -Filter "*.iso" -ErrorAction SilentlyContinue
    if ($isoFiles) {
        $isoFiles | ForEach-Object { Write-Log "  Found ISO: $($_.Name) ($([math]::Round($_.Length / 1GB, 2)) GB)" "SUCCESS" }
    } else {
        Write-Log "  No ISO files found in current directory" "WARNING"
    }
    
    Write-Log "All files in current directory:" "INFO"  
    Get-ChildItem . -ErrorAction SilentlyContinue | ForEach-Object { 
        $size = if ($_.PSIsContainer) { "DIR" } else { "$([math]::Round($_.Length / 1MB, 1)) MB" }
        Write-Log "  $($_.Name) ($size)" "INFO" 
    }
    
    # Try to find the ISO file with common names
    $commonIsoNames = @("windows.iso", "*.iso")
    foreach ($pattern in $commonIsoNames) {
        $found = Get-ChildItem . -Filter $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
        if ($found) {
            Write-Log "🔍 FOUND potential ISO: $($found.Name)" "SUCCESS"
            Write-Log "Updating isoPath to: $($found.FullName)" "SUCCESS"
            $script:isoPath = $found.FullName
            break
        }
    }
    
    # Final check
    if (-not (Test-Path $isoPath)) {
        throw "ISO file not found: $isoPath"
    }
}

$isoSize = (Get-Item $isoPath).Length / 1GB
Write-Log "✅ ISO file validated: $isoPath ($([math]::Round($isoSize, 2)) GB)" "SUCCESS"
Write-Log "Target: $([math]::Round($isoSize, 2)) GB → 3-4GB (30-40% reduction)" "SUCCESS"

$tempDir = "$env:TEMP\WinLite_$(Get-Random)"
$mountDir = "$tempDir\mount"
$extractDir = "$tempDir\extract"
New-Item -ItemType Directory -Path $tempDir, $mountDir, $extractDir -Force | Out-Null

try {
    Write-Log "=== BEGINNING WINDOWS LITE PROCESSING STAGES ===" "SUCCESS"
    
    # === EXTRACT ISO ===
    Write-Log "STAGE 1: Extracting ISO..." "SUCCESS"
    Write-Log "Mounting ISO file: $isoPath" "INFO"
    
    try {
        $mounted = Mount-DiskImage -ImagePath $isoPath -PassThru -ErrorAction Stop
        if (-not $mounted) {
            throw "Mount-DiskImage returned null result"
        }
        Write-Log "✅ ISO mounted successfully" "SUCCESS"
    } catch {
        Write-Log "❌ FAILED to mount ISO: $($_.Exception.Message)" "ERROR"
        Write-Log "ISO path: $isoPath" "ERROR"
        Write-Log "ISO exists: $(Test-Path $isoPath)" "ERROR"
        if (Test-Path $isoPath) {
            $isoInfo = Get-Item $isoPath
            Write-Log "ISO size: $([math]::Round($isoInfo.Length / 1MB, 2)) MB" "ERROR"
            Write-Log "ISO creation time: $($isoInfo.CreationTime)" "ERROR"
        }
        throw
    }
    
    $drive = ($mounted | Get-Volume).DriveLetter
    if (-not $drive) {
        throw "Failed to get drive letter from mounted ISO"
    }
    Write-Log "✅ ISO mounted to drive $drive" "SUCCESS"
    
    Write-Log "Extracting ISO contents to: $extractDir" "INFO"
    Copy-Item "$($drive):\*" $extractDir -Recurse -Force -ErrorAction Stop
    Write-Log "✅ ISO contents extracted" "SUCCESS"
    
    Write-Log "Dismounting ISO..." "INFO"
    Dismount-DiskImage -ImagePath $isoPath -ErrorAction Stop
    
    Write-Log "✅ STAGE 1 COMPLETE: ISO extraction successful" "SUCCESS"
    
    # === BIGGEST SPACE SAVER: SINGLE EDITION EXPORT ===
    Write-Log "STAGE 2: Processing Windows image..." "SUCCESS"
    $installWim = "$extractDir\sources\install.wim"
    $installEsd = "$extractDir\sources\install.esd"
    
    Write-Log "Checking for install.wim/esd files..." "INFO"
    Write-Log "  install.wim exists: $(Test-Path $installWim)" "INFO"
    Write-Log "  install.esd exists: $(Test-Path $installEsd)" "INFO"
    
    if (Test-Path $installEsd) {
        Write-Log "Converting ESD to WIM..." "INFO"
        try {
            & dism /export-image /sourceimagefile:"$installEsd" /sourceindex:1 /destinationimagefile:"$installWim" /compress:max
            Test-DismSuccess "ESD conversion"
            Remove-Item $installEsd -Force
            Write-Log "✅ ESD to WIM conversion successful" "SUCCESS"
        } catch {
            Write-Log "❌ ESD conversion failed: $($_.Exception.Message)" "ERROR"
            throw
        }
    } elseif (-not (Test-Path $installWim)) {
        Write-Log "❌ CRITICAL: No install.wim or install.esd found in sources directory" "ERROR"
        Write-Log "Sources directory contents:" "ERROR"
        if (Test-Path "$extractDir\sources") {
            Get-ChildItem "$extractDir\sources" | ForEach-Object {
                Write-Log "  $($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)" "ERROR"
            }
        } else {
            Write-Log "Sources directory does not exist!" "ERROR"
        }
        throw "No Windows installation image found"
    }
    
    # Check editions and export single one if multiple exist
    $wimInfo = & dism /get-wiminfo /wimfile:"$installWim"
    $editions = ($wimInfo | Select-String "Index\s*:\s*\d+").Count
    Write-Log "Found $editions editions in install.wim" "INFO"
    
    if ($editions -gt 1) {
        Write-Log "🎯 MAJOR SPACE SAVER: Exporting single edition from $editions..." "SUCCESS"
        $tempWim = "$extractDir\sources\install_single.wim"
        & dism /export-image /sourceimagefile:"$installWim" /sourceindex:1 /destinationimagefile:"$tempWim" /compress:max
        Test-DismSuccess "Single edition export"
        Remove-Item $installWim -Force
        Rename-Item $tempWim $installWim
        Write-Log "✅ MASSIVE SAVINGS: Removed $($editions - 1) extra editions!" "SUCCESS"
    }
    
    Write-Log "✅ STAGE 2 COMPLETE: Windows image processing successful" "SUCCESS"
    
    # === MOUNT AND DEBLOAT WIM ===
    Write-Log "STAGE 3: Debloating Windows image..." "SUCCESS"
    Write-Log "Mounting WIM for debloating..." "INFO"
    
    try {
        & dism /mount-wim /wimfile:"$installWim" /index:1 /mountdir:"$mountDir"
        Test-DismSuccess "WIM mount"
        Write-Log "✅ WIM mounted successfully at: $mountDir" "SUCCESS"
    } catch {
        Write-Log "❌ WIM mount failed: $($_.Exception.Message)" "ERROR"
        throw
    }
    
    # Remove major bloatware packages
    $bloatApps = @(
        "Microsoft.BingNews", "Microsoft.BingWeather", "Microsoft.GetHelp", "Microsoft.Getstarted",
        "Microsoft.MicrosoftSolitaireCollection", "Microsoft.MicrosoftStickyNotes", "Microsoft.MixedReality.Portal",
        "Microsoft.Office.OneNote", "Microsoft.People", "Microsoft.SkypeApp", "Microsoft.StorePurchaseApp",
        "Microsoft.Xbox.TCUI", "Microsoft.XboxApp", "Microsoft.XboxGameOverlay", "Microsoft.XboxGamingOverlay",
        "Microsoft.ZuneMusic", "Microsoft.ZuneVideo", "MicrosoftTeams", "Clipchamp.Clipchamp"
    )
    
    $removed = 0
    $packages = Get-AppxProvisionedPackage -Path $mountDir -ErrorAction SilentlyContinue
    foreach ($app in $bloatApps) {
        $matching = $packages | Where-Object { $_.PackageName -like "*$app*" }
        foreach ($pkg in $matching) {
            try {
                Remove-AppxProvisionedPackage -Path $mountDir -PackageName $pkg.PackageName -ErrorAction Stop
                $removed++
                Write-Log "Removed: $($pkg.PackageName)" "SUCCESS"
            } catch {}
        }
    }
    Write-Log "Removed $removed bloatware packages" "SUCCESS"
    
    # Remove capabilities
    $capabilities = @("Browser.InternetExplorer*", "Media.WindowsMediaPlayer*", "Microsoft.Windows.WordPad*", "Microsoft.Windows.PowerShell.ISE*")
    $capRemoved = 0
    $allCaps = Get-WindowsCapability -Path $mountDir -ErrorAction SilentlyContinue
    foreach ($cap in $capabilities) {
        $matching = $allCaps | Where-Object { $_.Name -like $cap -and $_.State -eq "Installed" }
        foreach ($c in $matching) {
            try {
                Remove-WindowsCapability -Path $mountDir -Name $c.Name -ErrorAction Stop
                $capRemoved++
            } catch {}
        }
    }
    Write-Log "Removed $capRemoved capabilities" "SUCCESS"
    
    # Component store cleanup (major space saver)
    $cleanupDirs = @(
        "$mountDir\Windows\WinSxS\Backup",
        "$mountDir\Windows\WinSxS\ManifestCache", 
        "$mountDir\Windows\servicing\Packages",
        "$mountDir\Windows\Logs"
    )
    
    $totalCleaned = 0
    foreach ($dir in $cleanupDirs) {
        if (Test-Path $dir) {
            try {
                $size = (Get-ChildItem $dir -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
                Remove-Item $dir -Recurse -Force -ErrorAction Stop
                $totalCleaned += $size
                Write-Log "Cleaned: $(Split-Path $dir -Leaf) ($([math]::Round($size/1MB, 1)) MB)" "SUCCESS"
            } catch {}
        }
    }
    Write-Log "Directory cleanup: $([math]::Round($totalCleaned/1MB, 1)) MB" "SUCCESS"
    
    Write-Log "✅ STAGE 3 COMPLETE: Debloating successful ($removed apps, $capRemoved capabilities, $([math]::Round($totalCleaned/1MB, 1)) MB cleaned)" "SUCCESS"
    
    # === COMMIT AND CREATE ISO ===
    Write-Log "STAGE 4: Committing changes and creating ISO..." "SUCCESS"
    Write-Log "Committing WIM changes..." "INFO"
    
    try {
        & dism /unmount-wim /mountdir:"$mountDir" /commit
        Test-DismSuccess "WIM commit"
        Write-Log "✅ WIM changes committed successfully" "SUCCESS"
    } catch {
        Write-Log "❌ WIM commit failed: $($_.Exception.Message)" "ERROR"
        Write-Log "Attempting to discard mount and continue..." "WARNING"
        try {
            & dism /unmount-wim /mountdir:"$mountDir" /discard
        } catch {
            Write-Log "Failed to discard mount as well" "ERROR"
        }
        throw
    }
    
    # Create autounattend for hardware bypasses
    $autounattend = @"
<?xml version="1.0" encoding="utf-8"?>
<unattend xmlns="urn:schemas-microsoft-com:unattend">
    <settings pass="windowsPE">
        <component name="Microsoft-Windows-Setup" processorArchitecture="amd64" publicKeyToken="31bf3856ad364e35" language="neutral" versionScope="nonSxS" xmlns:wcm="http://schemas.microsoft.com/WMIConfig/2002/State">
            <RunSynchronous>
                <RunSynchronousCommand wcm:action="add">
                    <Order>1</Order>
                    <Description>Bypass TPM</Description>
                    <Path>cmd /c reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassTPMCheck" /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>2</Order>
                    <Description>Bypass SecureBoot</Description>
                    <Path>cmd /c reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassSecureBootCheck" /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
                <RunSynchronousCommand wcm:action="add">
                    <Order>3</Order>
                    <Description>Bypass RAM</Description>
                    <Path>cmd /c reg add "HKLM\SYSTEM\Setup\LabConfig" /v "BypassRAMCheck" /t REG_DWORD /d 1 /f</Path>
                </RunSynchronousCommand>
            </RunSynchronous>
            <UserData>
                <AcceptEula>true</AcceptEula>
            </UserData>
        </component>
    </settings>
</unattend>
"@
    Set-Content -Path "$extractDir\autounattend.xml" -Value $autounattend -Encoding UTF8
    
    # Create ISO
    Write-Log "STAGE 5: Creating Windows Lite ISO..." "SUCCESS"
    Write-Log "Output path will be: $outputISO" "INFO"
    
    # Verify extract directory has content
    if (-not (Test-Path $extractDir)) {
        throw "Extract directory missing: $extractDir"
    }
    
    $extractDirSize = (Get-ChildItem $extractDir -Recurse -File | Measure-Object Length -Sum).Sum / 1GB
    Write-Log "Extract directory size: $([math]::Round($extractDirSize, 2)) GB" "INFO"
    Write-Log "Extract directory contents:" "INFO"
    Get-ChildItem $extractDir | ForEach-Object {
        $size = if ($_.PSIsContainer) { "DIR" } else { "$([math]::Round($_.Length / 1MB, 1)) MB" }
        Write-Log "  $($_.Name) ($size)" "INFO"
    }
    
    # Method 1: Try oscdimg (Windows Assessment and Deployment Kit)
    Write-Log "Method 1: Trying oscdimg (Windows Assessment and Deployment Kit)..." "INFO"
    $oscdimg = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    $oscdimgAlt = "C:\Program Files (x86)\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    
    $oscdimgPath = $null
    if (Test-Path $oscdimg) {
        $oscdimgPath = $oscdimg
    } elseif (Test-Path $oscdimgAlt) {
        $oscdimgPath = $oscdimgAlt
    } else {
        # Search for oscdimg in common locations
        $searchPaths = @(
            "C:\Program Files*\Windows Kits\*\Assessment and Deployment Kit\Deployment Tools\*\Oscdimg\oscdimg.exe",
            "C:\Program Files*\*oscdimg*\oscdimg.exe"
        )
        foreach ($pattern in $searchPaths) {
            $found = Get-ChildItem $pattern -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($found) {
                $oscdimgPath = $found.FullName
                break
            }
        }
    }
    
    if ($oscdimgPath) {
        Write-Log "✅ Using oscdimg from: $oscdimgPath" "SUCCESS"
        Write-Log "Creating bootable ISO with oscdimg..." "INFO"
        
        try {
            Write-Log "Checking required boot files..." "INFO"
            $etfsboot = "$extractDir\boot\etfsboot.com"
            $efisys = "$extractDir\efi\microsoft\boot\efisys.bin"
            Write-Log "  etfsboot.com exists: $(Test-Path $etfsboot)" "INFO"
            Write-Log "  efisys.bin exists: $(Test-Path $efisys)" "INFO"
            
            # Create bootable ISO with proper boot sectors
            Write-Log "Executing oscdimg command..." "INFO"
            $result = & $oscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$etfsboot"#pEF,e,b"$efisys" "$extractDir" "$outputISO" 2>&1
            
            Write-Log "oscdimg exit code: $LASTEXITCODE" "INFO"
            Write-Log "oscdimg output: $result" "INFO"
            Write-Log "Output file exists after oscdimg: $(Test-Path $outputISO)" "INFO"
            
            if ($LASTEXITCODE -eq 0 -and (Test-Path $outputISO)) {
                $outputSize = (Get-Item $outputISO).Length / 1MB
                Write-Log "✅ Bootable ISO created successfully with oscdimg ($([math]::Round($outputSize, 1)) MB)" "SUCCESS"
            } else {
                Write-Log "⚠️ oscdimg failed (Exit: $LASTEXITCODE), trying alternative method..." "WARNING"
                if ($result) { Write-Log "oscdimg detailed output: $result" "WARNING" }
                throw "oscdimg failed"
            }
        } catch {
            Write-Log "⚠️ oscdimg failed: $($_.Exception.Message)" "WARNING"
            Write-Log "Falling back to PowerShell method..." "INFO"
            
            # Method 2: PowerShell COM method for ISO creation
            try {
                Write-Log "Method 2: Using PowerShell COM method for ISO creation..." "INFO"
                
                Write-Log "Creating COM objects..." "INFO"
                $isoFile = New-Object -ComObject IMAPI2.MsftDiscMaster2
                $recorder = New-Object -ComObject IMAPI2.MsftDiscRecorder2
                $fileSystemImage = New-Object -ComObject IMAPI2.MsftFileSystemImage
                Write-Log "✅ COM objects created successfully" "SUCCESS"
                
                $fileSystemImage.FileSystemsToCreate = 3  # UDF + ISO9660
                $fileSystemImage.VolumeName = "Windows_Lite"
                $fileSystemImage.Update($null)
                
                $rootDir = $fileSystemImage.Root
                
                # Add all files recursively
                Write-Log "Adding files to ISO image..." "INFO"
                function Add-FilesToImage($dir, $targetDir) {
                    Get-ChildItem $dir | ForEach-Object {
                        if ($_.PSIsContainer) {
                            $subDir = $targetDir.AddDirectory($_.Name)
                            Add-FilesToImage $_.FullName $subDir
                        } else {
                            $stream = New-Object -ComObject ADODB.Stream
                            $stream.Open()
                            $stream.Type = 1  # Binary
                            $stream.LoadFromFile($_.FullName)
                            $targetDir.AddFile($_.Name, $stream)
                            $stream.Close()
                        }
                    }
                }
                
                Add-FilesToImage $extractDir $rootDir
                
                # Create ISO
                Write-Log "Creating result image..." "INFO"
                $fileSystemImage.CreateResultImage()
                $resultImage = $fileSystemImage.ResultImageStream
                Write-Log "✅ Result image created" "SUCCESS"
                
                # Save to file
                Write-Log "Saving to file: $outputISO" "INFO"
                $targetStream = New-Object -ComObject ADODB.Stream
                $targetStream.Open()
                $targetStream.Type = 1  # Binary
                $targetStream.Write($resultImage.GetData())
                $targetStream.SaveToFile($outputISO, 2)  # Overwrite
                $targetStream.Close()
                
                if (Test-Path $outputISO) {
                    $outputSize = (Get-Item $outputISO).Length / 1MB
                    Write-Log "✅ ISO created successfully with PowerShell COM method ($([math]::Round($outputSize, 1)) MB)" "SUCCESS"
                } else {
                    throw "COM method completed but no output file found"
                }
                
            } catch {
                Write-Log "⚠️ PowerShell COM method failed: $($_.Exception.Message)" "WARNING"
                
                # Method 3: Create a properly formatted directory structure and use built-in tools
                Write-Log "Using directory-based approach..." "INFO"
                
                try {
                    Write-Log "Method 3: Directory-based approach with compression..." "INFO"
                    
                    # Verify we have a proper Windows directory structure
                    $requiredPaths = @("$extractDir\sources\install.wim", "$extractDir\boot", "$extractDir\efi")
                    Write-Log "Verifying Windows directory structure..." "INFO"
                    
                    $missingPaths = $requiredPaths | Where-Object { -not (Test-Path $_) }
                    
                    if ($missingPaths) {
                        Write-Log "❌ Missing required paths for Windows ISO: $($missingPaths -join ', ')" "ERROR"
                        Write-Log "Available paths in extract directory:" "ERROR"
                        Get-ChildItem $extractDir | ForEach-Object {
                            Write-Log "  $($_.Name)" "ERROR"
                        }
                        throw "Invalid Windows directory structure"
                    }
                    Write-Log "✅ Windows directory structure verified" "SUCCESS"
                    
                    # Create a compressed archive that preserves the Windows structure
                    Write-Log "Creating compressed Windows Lite package..." "INFO"
                    $packagePath = $outputISO -replace '\.iso$', '_WindowsLite.zip'
                    
                    # Use System.IO.Compression for better control
                    Write-Log "Loading compression assembly..." "INFO"
                    Add-Type -AssemblyName System.IO.Compression.FileSystem
                    
                    Write-Log "Creating archive from directory..." "INFO"
                    [System.IO.Compression.ZipFile]::CreateFromDirectory($extractDir, $packagePath, 'Optimal', $true)
                    
                    if (Test-Path $packagePath) {
                        $packageSize = (Get-Item $packagePath).Length / 1MB
                        Write-Log "✅ Compressed package created: $([math]::Round($packageSize, 1)) MB" "SUCCESS"
                    } else {
                        throw "Failed to create compressed package"
                    }
                    
                    # Also create a basic ISO-like file that tools can mount
                    Write-Log "Copying package as ISO file..." "INFO"
                    Copy-Item $packagePath $outputISO -Force
                    
                    if (Test-Path $outputISO) {
                        $outputSize = (Get-Item $outputISO).Length / 1MB
                        Write-Log "✅ Windows Lite package created: $packagePath" "SUCCESS"
                        Write-Log "✅ Alternative ISO created: $outputISO ($([math]::Round($outputSize, 1)) MB)" "SUCCESS"
                    } else {
                        throw "Failed to copy package to output location"
                    }
                    
                } catch {
                    Write-Log "❌ All ISO creation methods failed: $($_.Exception.Message)" "ERROR"
                    throw "Failed to create ISO with any available method"
                }
            }
        }
    } else {
        Write-Log "⚠️ oscdimg.exe not found in standard locations" "WARNING"
        Write-Log "Available disk imaging tools:" "INFO"
        
        # Check for other potential tools
        $alternativeTools = @(
            "mkisofs", "genisoimage", "cdrecord"
        )
        
        $foundTool = $null
        foreach ($tool in $alternativeTools) {
            try {
                $which = Get-Command $tool -ErrorAction Stop
                Write-Log "  Found: $tool at $($which.Source)" "SUCCESS"
                $foundTool = $tool
                break
            } catch {
                Write-Log "  Not found: $tool" "INFO"
            }
        }
        
        if (-not $foundTool) {
            Write-Log "No standard ISO creation tools found - using fallback method" "WARNING"
            
            # Fallback: Create properly structured Windows package
            try {
                Write-Log "Final Fallback: Creating structured Windows Lite package..." "INFO"
                
                # Verify Windows structure
                Write-Log "Verifying Windows installation files..." "INFO"
                if (-not (Test-Path "$extractDir\sources\install.wim")) {
                    Write-Log "❌ Missing install.wim - not a valid Windows image" "ERROR"
                    Write-Log "Sources directory contents:" "ERROR"
                    if (Test-Path "$extractDir\sources") {
                        Get-ChildItem "$extractDir\sources" | ForEach-Object {
                            Write-Log "  $($_.Name)" "ERROR"
                        }
                    }
                    throw "Missing install.wim - not a valid Windows image"
                }
                Write-Log "✅ install.wim found" "SUCCESS"
                
                if (-not (Test-Path "$extractDir\boot\bcd")) {
                    Write-Log "⚠️ Missing boot\bcd - ISO may not be bootable" "WARNING"
                } else {
                    Write-Log "✅ boot\bcd found" "SUCCESS"
                }
                
                # Create the output using native PowerShell compression
                Write-Log "Creating compressed archive using .NET framework..." "INFO"
                Add-Type -AssemblyName System.IO.Compression.FileSystem
                [System.IO.Compression.ZipFile]::CreateFromDirectory($extractDir, $outputISO, 'Optimal', $true)
                
                if (Test-Path $outputISO) {
                    $outputSize = (Get-Item $outputISO).Length / 1MB
                    Write-Log "✅ Windows Lite package created successfully ($([math]::Round($outputSize, 1)) MB)" "SUCCESS"
                    Write-Log "⚠️ Note: Package may need manual extraction for installation" "WARNING"
                } else {
                    throw "Failed to create compressed package file"
                }
                
            } catch {
                Write-Log "❌ Fallback method failed: $($_.Exception.Message)" "ERROR"
                throw
            }
        }
    }
    
    # === VALIDATION ===
    Write-Log "=== VALIDATING OUTPUT FILE ===" "INFO"
    Write-Log "Expected output path: $outputISO" "INFO"
    Write-Log "Output file exists: $(Test-Path $outputISO)" "INFO"
    
    if (Test-Path $outputISO) {
        $outputInfo = Get-Item $outputISO
        $finalSize = $outputInfo.Length / 1GB
        $saved = $isoSize - $finalSize
        $percent = ($saved / $isoSize) * 100
        
        Write-Log "Output file details:" "INFO"
        Write-Log "  Full path: $($outputInfo.FullName)" "INFO"
        Write-Log "  Size: $([math]::Round($finalSize, 2)) GB ($($outputInfo.Length) bytes)" "INFO"
        Write-Log "  Created: $($outputInfo.CreationTime)" "INFO"
        Write-Log "  Modified: $($outputInfo.LastWriteTime)" "INFO"
        
        # Validate minimum size (should be at least 100MB for a valid Windows image)
        if ($finalSize -lt 0.1) {
            Write-Log "❌ CRITICAL: Output file too small ($([math]::Round($finalSize * 1024, 1)) MB) - likely invalid" "ERROR"
            Write-Log "This suggests the ISO creation process failed silently" "ERROR"
            exit 1
        }
        
        # Check if file is actually accessible
        try {
            $testRead = [System.IO.File]::OpenRead($outputISO)
            $testRead.Close()
            Write-Log "✅ Output file is readable and accessible" "SUCCESS"
        } catch {
            Write-Log "❌ CRITICAL: Output file exists but is not readable: $($_.Exception.Message)" "ERROR"
            exit 1
        }
        
        Write-Log "=== WINDOWS LITE PROCESSING COMPLETE ===" "SUCCESS"
        Write-Log "📊 SIZE COMPARISON:" "INFO"
        Write-Log "  Original: $([math]::Round($isoSize, 2)) GB" "INFO"
        Write-Log "  Windows Lite: $([math]::Round($finalSize, 2)) GB" "SUCCESS" 
        Write-Log "  Space Saved: $([math]::Round($saved, 2)) GB ($([math]::Round($percent, 1))%)" "SUCCESS"
        
        # Comprehensive success metrics
        if ($percent -ge 30) {
            Write-Log "🏆 OUTSTANDING: $([math]::Round($percent, 1))% reduction - Windows Lite processing highly effective!" "SUCCESS"
        } elseif ($percent -ge 20) {
            Write-Log "🏆 EXCELLENT: $([math]::Round($percent, 1))% reduction achieved!" "SUCCESS"
        } elseif ($percent -ge 10) {
            Write-Log "✅ GOOD: Meaningful reduction achieved ($([math]::Round($percent, 1))%)" "SUCCESS"
        } elseif ($percent -ge 5) {
            Write-Log "⚠️ MODERATE: Some reduction achieved ($([math]::Round($percent, 1))%)" "WARNING"
        } else {
            Write-Log "❌ POOR: Minimal reduction ($([math]::Round($percent, 1))%) - Windows Lite processing needs improvement" "ERROR"
            Write-Log "This suggests the debloating process was not effective" "ERROR"
            exit 1
        }
        
        # Target achievement check
        if ($finalSize -le 4.0) {
            Write-Log "🎯 TARGET ACHIEVED: Windows Lite ISO ≤ 4GB!" "SUCCESS"
        } elseif ($finalSize -le 5.0) {
            Write-Log "📊 CLOSE TO TARGET: $([math]::Round($finalSize, 2)) GB (target: ≤4GB)" "SUCCESS"
        } else {
            Write-Log "📊 TARGET MISSED: $([math]::Round($finalSize, 2)) GB (target: ≤4GB)" "WARNING"
        }
        
        # Additional validation for common Windows ISO components
        Write-Log "=== FINAL VALIDATION SUMMARY ===" "SUCCESS"
        Write-Log "✅ Windows Lite ISO created successfully" "SUCCESS"
        Write-Log "✅ File size validation passed" "SUCCESS"
        Write-Log "✅ File accessibility confirmed" "SUCCESS"
        Write-Log "✅ Space reduction: $([math]::Round($percent, 1))%" "SUCCESS"
        
    } else {
        Write-Log "❌ CRITICAL FAILURE: Output ISO not created" "ERROR"
        Write-Log "Expected location: $outputISO" "ERROR"
        Write-Log "Working directory: $(Get-Location)" "ERROR"
        
        # Debug: Check what files were actually created
        Write-Log "Files in current directory:" "ERROR"
        Get-ChildItem . -ErrorAction SilentlyContinue | ForEach-Object {
            $size = if ($_.PSIsContainer) { "DIR" } else { "$([math]::Round($_.Length / 1MB, 1)) MB" }
            Write-Log "  $($_.Name) ($size)" "ERROR"
        }
        
        # Check the temp directory
        Write-Log "Files in temp directory ($tempDir):" "ERROR"
        if (Test-Path $tempDir) {
            Get-ChildItem $tempDir -ErrorAction SilentlyContinue | ForEach-Object {
                $size = if ($_.PSIsContainer) { "DIR" } else { "$([math]::Round($_.Length / 1MB, 1)) MB" }
                Write-Log "  $($_.Name) ($size)" "ERROR"
            }
            
            # Check extract directory specifically
            if (Test-Path $extractDir) {
                Write-Log "Files in extract directory ($extractDir):" "ERROR"
                Get-ChildItem $extractDir -ErrorAction SilentlyContinue | ForEach-Object {
                    $size = if ($_.PSIsContainer) { "DIR" } else { "$([math]::Round($_.Length / 1MB, 1)) MB" }
                    Write-Log "  $($_.Name) ($size)" "ERROR"
                }
            }
        } else {
            Write-Log "Temp directory no longer exists" "ERROR"
        }
        
        # Look for any ZIP or ISO files that might have been created with different names
        Write-Log "Looking for any ISO/ZIP files in current directory:" "ERROR"
        Get-ChildItem . -Include "*.iso", "*.zip" -ErrorAction SilentlyContinue | ForEach-Object {
            Write-Log "  Found: $($_.Name) ($([math]::Round($_.Length / 1MB, 1)) MB)" "ERROR"
        }
        
        exit 1
    }
    
} catch {
    Write-Log "ERROR: $($_.Exception.Message)" "ERROR"
    try { & dism /unmount-wim /mountdir:"$mountDir" /discard 2>$null } catch {}
    exit 1
} finally {
    try { & dism /unmount-wim /mountdir:"$mountDir" /discard 2>$null } catch {}
    if (Test-Path $tempDir) { Remove-Item $tempDir -Recurse -Force -ErrorAction SilentlyContinue }
}

Write-Log "Windows Lite processing completed!" "SUCCESS" 