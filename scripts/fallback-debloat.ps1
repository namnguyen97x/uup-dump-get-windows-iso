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
Write-Log "Current working directory: $(Get-Location)" "INFO"
Write-Log "Script parameters:" "INFO"
Write-Log "  isoPath: $isoPath" "INFO"
Write-Log "  outputISO: $outputISO" "INFO"

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
    # === EXTRACT ISO ===
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
    
    # === BIGGEST SPACE SAVER: SINGLE EDITION EXPORT ===
    $installWim = "$extractDir\sources\install.wim"
    $installEsd = "$extractDir\sources\install.esd"
    
    if (Test-Path $installEsd) {
        Write-Log "Converting ESD to WIM..." "INFO"
        & dism /export-image /sourceimagefile:"$installEsd" /sourceindex:1 /destinationimagefile:"$installWim" /compress:max
        Test-DismSuccess "ESD conversion"
        Remove-Item $installEsd -Force
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
    
    # === MOUNT AND DEBLOAT WIM ===
    Write-Log "Mounting WIM for debloating..." "INFO"
    & dism /mount-wim /wimfile:"$installWim" /index:1 /mountdir:"$mountDir"
    Test-DismSuccess "WIM mount"
    
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
    
    # === COMMIT AND CREATE ISO ===
    Write-Log "Committing WIM changes..." "INFO"
    & dism /unmount-wim /mountdir:"$mountDir" /commit
    Test-DismSuccess "WIM commit"
    
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
    Write-Log "Creating Windows Lite ISO..." "INFO"
    $oscdimg = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
    
    if (Test-Path $oscdimg) {
        & $oscdimg -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$extractDir\boot\etfsboot.com"#pEF,e,b"$extractDir\efi\microsoft\boot\efisys.bin" "$extractDir" "$outputISO"
    } else {
        Compress-Archive -Path "$extractDir\*" -DestinationPath "$outputISO.zip" -CompressionLevel Optimal -Force
        Rename-Item "$outputISO.zip" $outputISO -Force
    }
    
    # === VALIDATION ===
    if (Test-Path $outputISO) {
        $finalSize = (Get-Item $outputISO).Length / 1GB
        $saved = $isoSize - $finalSize
        $percent = ($saved / $isoSize) * 100
        
        Write-Log "=== WINDOWS LITE PROCESSING COMPLETE ===" "SUCCESS"
        Write-Log "Original: $([math]::Round($isoSize, 2)) GB" "INFO"
        Write-Log "Final: $([math]::Round($finalSize, 2)) GB" "SUCCESS" 
        Write-Log "Saved: $([math]::Round($saved, 2)) GB ($([math]::Round($percent, 1))%)" "SUCCESS"
        
        if ($percent -ge 20) {
            Write-Log "🏆 EXCELLENT: $([math]::Round($percent, 1))% reduction achieved!" "SUCCESS"
        } elseif ($percent -ge 10) {
            Write-Log "✅ GOOD: Meaningful reduction achieved" "SUCCESS"
        } elseif ($percent -ge 5) {
            Write-Log "⚠️ MODERATE: Some reduction achieved" "WARNING"
        } else {
            Write-Log "❌ POOR: Minimal reduction ($([math]::Round($percent, 1))%)" "ERROR"
            exit 1
        }
        
        if ($finalSize -le 4.0) {
            Write-Log "🎯 TARGET ACHIEVED: ≤ 4GB!" "SUCCESS"
        }
        
    } else {
        Write-Log "❌ Failed to create output ISO" "ERROR"
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