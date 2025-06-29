param(
    [string]$isoPath = "windows.iso",
    [string]$outputISO = "debloated-windows.iso",
    [string]$winEdition = "",
    [switch]$testMode = $false,
    [switch]$removeEdge = $true,
    [switch]$removeOneDrive = $true,
    [switch]$tpmBypass = $false
)

Write-Host "=== PROPER WINDOWS ISO DEBLOATER ==="
Write-Host "Based on: https://github.com/itsNileshHere/Windows-ISO-Debloater"
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if (-not $isAdmin) {
    Write-Host "ERROR: Script must run as Administrator!" -ForegroundColor Red
    exit 1
}

# Check ISO file
if (-not (Test-Path $isoPath)) {
    Write-Host "ERROR: ISO file not found: $isoPath" -ForegroundColor Red
    exit 1
}

Write-Host "ISO File: $isoPath"
$originalSize = (Get-Item $isoPath).Length / 1GB
Write-Host "Original size: $([math]::Round($originalSize,2)) GB"

# Create temp directories
$tempDir = "$env:SystemDrive\temp-debloat"
$mountDir = "$env:SystemDrive\temp-mount"

foreach ($dir in @($tempDir, $mountDir)) {
    if (Test-Path $dir) {
        Remove-Item $dir -Recurse -Force
    }
    New-Item -ItemType Directory -Path $dir -Force | Out-Null
}

try {
    Write-Host "=== STEP 1: MOUNT AND COPY ISO ==="
    
    # Mount ISO and copy contents
    $mount = Mount-DiskImage -ImagePath (Resolve-Path $isoPath).Path -PassThru
    $drive = ($mount | Get-Volume).DriveLetter + ":\"
    Write-Host "ISO mounted at: $drive"
    
    # Copy ISO contents (keep everything intact)
    robocopy $drive $tempDir /E /R:1 /W:1 /MT:8
    if ($LASTEXITCODE -gt 7) {
        throw "Robocopy failed with exit code $LASTEXITCODE"
    }
    
    Dismount-DiskImage -ImagePath (Resolve-Path $isoPath).Path
    Write-Host "✅ ISO contents copied successfully"
    
    Write-Host "=== STEP 2: LOCATE INSTALL.WIM ==="
    
    $installWim = "$tempDir\sources\install.wim"
    $installEsd = "$tempDir\sources\install.esd"
    
    if (Test-Path $installEsd) {
        Write-Host "Found install.esd, converting to install.wim..."
        & dism /export-image /sourceimagefile:$installEsd /sourceindex:1 /destinationimagefile:$installWim /compress:max /checkintegrity
        if ($LASTEXITCODE -ne 0) {
            throw "Failed to convert install.esd to install.wim"
        }
        Remove-Item $installEsd -Force
        Write-Host "✅ Converted install.esd to install.wim"
    }
    
    if (-not (Test-Path $installWim)) {
        throw "No install.wim or install.esd found in sources directory"
    }
    
    Write-Host "✅ Found install.wim: $([math]::Round((Get-Item $installWim).Length / 1GB, 2)) GB"
    
    Write-Host "=== STEP 3: GET WIM INFO ==="
    
    $wimInfo = & dism /get-wiminfo /wimfile:$installWim
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to get WIM info"
    }
    
    # Parse available editions
    $editions = @()
    $wimInfo | ForEach-Object {
        if ($_ -match "Index : (\d+)") {
            $index = $matches[1]
        }
        if ($_ -match "Name : (.+)") {
            $name = $matches[1].Trim()
            $editions += [PSCustomObject]@{Index = $index; Name = $name}
        }
    }
    
    Write-Host "Available Windows editions:"
    $editions | ForEach-Object { Write-Host "  [$($_.Index)] $($_.Name)" }
    
    # Select edition to debloat
    $imageIndex = 1
    if ($winEdition) {
        $selected = $editions | Where-Object { $_.Name -like "*$winEdition*" }
        if ($selected) {
            $imageIndex = $selected.Index
            Write-Host "Selected edition: $($selected.Name) (Index: $imageIndex)"
        } else {
            Write-Host "Warning: Edition '$winEdition' not found, using index 1"
        }
    } else {
        Write-Host "No edition specified, using index 1: $($editions[0].Name)"
    }
    
    if ($testMode) {
        Write-Host "=== TEST MODE: Stopping after WIM analysis ==="
        Write-Host "✅ ISO structure is valid"
        Write-Host "✅ Found $($editions.Count) Windows editions"
        Write-Host "✅ Ready for debloating"
        exit 0
    }
    
    Write-Host "=== STEP 4: MOUNT WINDOWS IMAGE ==="
    
    & dism /mount-wim /wimfile:$installWim /index:$imageIndex /mountdir:$mountDir
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to mount WIM image"
    }
    Write-Host "✅ Windows image mounted successfully"
    
    Write-Host "=== STEP 5: REMOVE BLOATWARE ==="
    
    # Define bloatware lists based on Windows-ISO-Debloater
    $appxPatternsToRemove = @(
        "Microsoft.BingNews",
        "Microsoft.BingWeather", 
        "Microsoft.549981C3F5F10",  # Cortana
        "Microsoft.WindowsAlarms",
        "Microsoft.WindowsFeedbackHub",
        "Microsoft.GetHelp",
        "Microsoft.Getstarted",
        "Microsoft.WindowsMaps",
        "Microsoft.WindowsCommunicationsApps",
        "Microsoft.ZuneMusic",
        "Microsoft.ZuneVideo", 
        "Microsoft.Xbox",
        "Microsoft.People",
        "Microsoft.YourPhone",
        "Microsoft.SkypeApp",
        "Microsoft.Todos",
        "Microsoft.Wallet",
        "Microsoft.PowerAutomateDesktop",
        "Microsoft.MicrosoftSolitaireCollection",
        "Microsoft.MicrosoftStickyNotes",
        "Microsoft.WindowsCalculator",
        "Microsoft.WindowsCamera",
        "Microsoft.WindowsStore",
        "Microsoft.WindowsAlarms",
        "Microsoft.OutlookForWindows",
        "Microsoft.Paint",
        "Microsoft.People",
        "Microsoft.Photos",
        "Microsoft.ScreenSketch",
        "Microsoft.WindowsNotepad",
        "Microsoft.WindowsTerminal",
        "Microsoft.Xbox",
        "Microsoft.ZuneMusic",
        "MicrosoftCorporationII.QuickAssist",
        "Clipchamp.Clipchamp",
        "Microsoft.Copilot"
    )
    
    $capabilitiesToRemove = @(
        "App.StepsRecorder*",
        "Language.Handwriting*", 
        "Language.OCR*",
        "Language.Speech*",
        "Language.TextToSpeech*",
        "Microsoft.Windows.WordPad*",
        "MathRecognizer*",
        "Media.WindowsMediaPlayer*",
        "Microsoft.Windows.PowerShell.ISE*",
        "Print.Fax.Scan*",
        "Print.Management.Console*"
    )
    
    $windowsPackagesToRemove = @(
        "Microsoft-Windows-InternetExplorer-Optional-Package*",
        "Microsoft-Windows-LanguageFeatures-Handwriting-*",
        "Microsoft-Windows-LanguageFeatures-OCR-*", 
        "Microsoft-Windows-LanguageFeatures-Speech-*",
        "Microsoft-Windows-LanguageFeatures-TextToSpeech-*",
        "Microsoft-Windows-WordPad-FoD-Package*",
        "Microsoft-Windows-MediaPlayer-Package*",
        "Microsoft-Windows-TabletPCMath-Package*",
        "Microsoft-Windows-StepsRecorder-Package*"
    )
    
    # Remove AppX packages
    Write-Host "Removing AppX packages..."
    $appxList = & dism /image:$mountDir /get-provisionedappxpackages
    
    foreach ($pattern in $appxPatternsToRemove) {
        $matches = $appxList | Select-String "PackageName : .*$pattern"
        foreach ($match in $matches) {
            $packageName = $match.Line -replace "PackageName : ", ""
            Write-Host "  Removing AppX: $packageName"
            & dism /image:$mountDir /remove-provisionedappxpackage /packagename:$packageName
        }
    }
    
    # Remove Windows Capabilities
    Write-Host "Removing Windows Capabilities..."
    $capList = & dism /image:$mountDir /get-capabilities
    
    foreach ($pattern in $capabilitiesToRemove) {
        $matches = $capList | Select-String "Capability Identity : .*$($pattern.Replace('*', ''))"
        foreach ($match in $matches) {
            $capName = $match.Line -replace "Capability Identity : ", ""
            Write-Host "  Removing Capability: $capName"
            & dism /image:$mountDir /remove-capability /capabilityname:$capName
        }
    }
    
    # Remove Windows Packages
    Write-Host "Removing Windows Packages..."
    $packageList = & dism /image:$mountDir /get-packages
    
    foreach ($pattern in $windowsPackagesToRemove) {
        $matches = $packageList | Select-String "Package Identity : .*$($pattern.Replace('*', ''))"
        foreach ($match in $matches) {
            $packageName = $match.Line -replace "Package Identity : ", ""
            Write-Host "  Removing Package: $packageName"
            & dism /image:$mountDir /remove-package /packagename:$packageName
        }
    }
    
    # Remove OneDrive (optional)
    if ($removeOneDrive) {
        Write-Host "Removing OneDrive..."
        $oneDriveFiles = @(
            "$mountDir\Windows\System32\OneDriveSetup.exe",
            "$mountDir\Windows\SysWOW64\OneDriveSetup.exe"
        )
        foreach ($file in $oneDriveFiles) {
            if (Test-Path $file) {
                Remove-Item $file -Force
                Write-Host "  Removed: $(Split-Path $file -Leaf)"
            }
        }
    }
    
    # Remove Edge (optional)
    if ($removeEdge) {
        Write-Host "Removing Microsoft Edge..."
        $edgeDirs = @(
            "$mountDir\Program Files\Microsoft\Edge*",
            "$mountDir\Program Files (x86)\Microsoft\Edge*"
        )
        foreach ($dir in $edgeDirs) {
            Get-Item $dir -ErrorAction SilentlyContinue | Remove-Item -Recurse -Force
        }
    }
    
    Write-Host "=== STEP 6: APPLY REGISTRY TWEAKS ==="
    
    # Load registry hives
    & reg load HKLM\WIM_SOFTWARE "$mountDir\Windows\System32\config\SOFTWARE"
    & reg load HKLM\WIM_SYSTEM "$mountDir\Windows\System32\config\SYSTEM"
    & reg load HKLM\WIM_DEFAULT "$mountDir\Windows\System32\config\DEFAULT"
    
    try {
        # Privacy and telemetry tweaks
        Write-Host "Applying privacy tweaks..."
        $regTweaks = @(
            "reg add `"HKLM\WIM_SOFTWARE\Policies\Microsoft\Windows\DataCollection`" /v AllowTelemetry /t REG_DWORD /d 0 /f",
            "reg add `"HKLM\WIM_SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection`" /v AllowTelemetry /t REG_DWORD /d 0 /f",
            "reg add `"HKLM\WIM_SOFTWARE\Policies\Microsoft\Windows\AppCompat`" /v AITEnable /t REG_DWORD /d 0 /f",
            "reg add `"HKLM\WIM_SOFTWARE\Policies\Microsoft\Windows\AppCompat`" /v DisableInventory /t REG_DWORD /d 1 /f",
            "reg add `"HKLM\WIM_SOFTWARE\Policies\Microsoft\Windows\AppCompat`" /v DisablePcaUI /t REG_DWORD /d 1 /f",
            "reg add `"HKLM\WIM_SOFTWARE\Policies\Microsoft\Windows\AppCompat`" /v DisableUAR /t REG_DWORD /d 1 /f"
        )
        
        # TPM Bypass (optional)
        if ($tpmBypass) {
            Write-Host "Applying Windows 11 TPM bypass..."
            $regTweaks += @(
                "reg add `"HKLM\WIM_SYSTEM\Setup\LabConfig`" /v BypassTPMCheck /t REG_DWORD /d 1 /f",
                "reg add `"HKLM\WIM_SYSTEM\Setup\LabConfig`" /v BypassSecureBootCheck /t REG_DWORD /d 1 /f",
                "reg add `"HKLM\WIM_SYSTEM\Setup\LabConfig`" /v BypassRAMCheck /t REG_DWORD /d 1 /f"
            )
        }
        
        foreach ($cmd in $regTweaks) {
            Invoke-Expression $cmd
        }
        
        Write-Host "✅ Registry tweaks applied"
        
    } finally {
        # Unload registry hives
        & reg unload HKLM\WIM_SOFTWARE
        & reg unload HKLM\WIM_SYSTEM  
        & reg unload HKLM\WIM_DEFAULT
    }
    
    Write-Host "=== STEP 7: UNMOUNT AND SAVE CHANGES ==="
    
    & dism /unmount-wim /mountdir:$mountDir /commit
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to unmount and commit WIM changes"
    }
    Write-Host "✅ Windows image unmounted and saved"
    
    Write-Host "=== STEP 8: CREATE DEBLOATED ISO ==="
    
    # Create bootable ISO using oscdimg
    Write-Host "Creating bootable ISO with oscdimg..."
    
    # Download oscdimg if not available
    $oscdimgPath = "$env:TEMP\oscdimg.exe"
    if (-not (Test-Path $oscdimgPath)) {
        Write-Host "Downloading oscdimg.exe..."
        $oscdimgUrl = "https://github.com/itsNileshHere/Windows-ISO-Debloater/raw/main/oscdimg.exe"
        Invoke-WebRequest -Uri $oscdimgUrl -OutFile $oscdimgPath
    }
    
    # Create bootable ISO
    $etfsbootPath = "$tempDir\boot\etfsboot.com"
    $efisysPath = "$tempDir\efi\microsoft\boot\efisys.bin"
    
    if (Test-Path $etfsbootPath) {
        Write-Host "Creating BIOS/UEFI bootable ISO..."
        $oscdimgArgs = @(
            "-m", "-o", "-u2", "-udfver102"
            "-bootdata:2#p0,e,b$etfsbootPath#pEF,e,b$efisysPath"
            $tempDir
            $outputISO
        )
        & $oscdimgPath @oscdimgArgs
    } else {
        Write-Host "Creating basic bootable ISO..."
        & $oscdimgPath -m -o -u2 -udfver102 $tempDir $outputISO
    }
    
    if ($LASTEXITCODE -ne 0) {
        throw "Failed to create ISO with oscdimg"
    }
    
    Write-Host "✅ Debloated ISO created successfully!"
    
    # Show results
    $finalSize = (Get-Item $outputISO).Length / 1GB
    $saved = $originalSize - $finalSize
    $percentage = ($saved / $originalSize) * 100
    
    Write-Host ""
    Write-Host "=== DEBLOAT COMPLETED ==="
    Write-Host "Original size: $([math]::Round($originalSize,2)) GB"
    Write-Host "Debloated size: $([math]::Round($finalSize,2)) GB"
    Write-Host "Space saved: $([math]::Round($saved,2)) GB ($([math]::Round($percentage,1))%)"
    Write-Host "Output file: $outputISO"
    
    # Set environment variable for GitHub Actions
    if ($env:GITHUB_ACTIONS) {
        "ISO_CREATED=true" | Out-File -FilePath $env:GITHUB_ENV -Append
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
} finally {
    # Cleanup
    Write-Host "Cleaning up temporary files..."
    foreach ($dir in @($tempDir, $mountDir)) {
        if (Test-Path $dir) {
            Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Write-Host "=== DEBLOAT PROCESS COMPLETED ===" 