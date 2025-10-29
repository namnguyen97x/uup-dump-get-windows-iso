<#
Wrapper script to adapt a UUP ISO to Bedi's expected layout and run Bedi.cmd non-interactively.

Usage example:
  .\bedi-ci-wrapper.ps1 -IsoPath "Bedi\uup.iso" -Build 22000 -WimIndex 1 -TargetSKU EnterpriseG
#>
param(
  [Parameter(Mandatory=$true)][string]$IsoPath,
  [Parameter(Mandatory=$true)][string]$Build,
  [int]$WimIndex = 1,
  [string]$TargetSKU = 'EnterpriseG'
)

$ErrorActionPreference = 'Stop'
Write-Host "Bedi CI wrapper starting..."

# Script and repo layout
$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition    # this directory = Bedi
$bediRoot = (Resolve-Path -Path $scriptRoot).ProviderPath             # Bedi folder
$filesDir = Join-Path $bediRoot 'Files'
$buildDir = Join-Path $bediRoot $Build

if (-not (Test-Path $bediRoot)) { throw "Bedi folder not found at $bediRoot" }
if (-not (Test-Path $filesDir)) { New-Item -ItemType Directory -Path $filesDir | Out-Null }
if (-not (Test-Path $buildDir)) { New-Item -ItemType Directory -Path $buildDir | Out-Null }

# Admin check
$principal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
  Write-Warning "Script is not running as Administrator. Many DISM/mount actions require elevated privileges. Run on an elevated session or self-hosted runner with admin rights."
}

# Resolve ISO path (allow repo-relative or absolute)
$isoResolved = $IsoPath
if (-not (Test-Path $isoResolved)) {
  $try = Join-Path $bediRoot $IsoPath
  if (Test-Path $try) { $isoResolved = $try } else { throw "ISO not found at $IsoPath or $try. Place UUP ISO in the repo (e.g. Bedi/uup.iso) or provide absolute path." }
}
Write-Host "ISO resolved to: $isoResolved"

# Find newly added drive after mount
$before = (Get-PSDrive -PSProvider FileSystem).Root
Write-Host "Mounting ISO..."
Mount-DiskImage -ImagePath $isoResolved -PassThru | Out-Null
Start-Sleep -Seconds 1
$after = (Get-PSDrive -PSProvider FileSystem).Root
$news = Compare-Object -ReferenceObject $before -DifferenceObject $after | Where-Object { $_.SideIndicator -eq '=>' } | Select-Object -ExpandProperty InputObject

# Determine drive root with robust string handling
if ($news -and $news.Count -gt 0) {
  $driveRoot = [string]$news[0]
} else {
  Write-Warning "Could not detect new drive letter automatically. You may need to mount ISO manually. Continuing assuming $isoResolved is accessible."
  $newDrives = $after | Where-Object { $_ -notin $before }
  if ($newDrives -and $newDrives.Count -gt 0) {
    $driveRoot = [string]$newDrives[0]
  } else {
    throw "Could not determine mounted drive letter. Please mount the ISO manually and provide the drive letter."
  }
}

# Ensure driveRoot is a valid string and trim trailing backslash
if (-not $driveRoot -or $driveRoot -eq '') {
  throw "Could not determine mounted drive letter. Please mount the ISO manually and provide the drive letter."
}
$driveLetter = $driveRoot.TrimEnd('\')
# Normalize to root path like 'E:\' to ensure Join-Path builds absolute paths
if ($driveLetter.Length -eq 1 -and $driveLetter -match '^[A-Za-z]$') {
  $driveLetter = "${driveLetter}:\"
}
Write-Host "ISO mounted at $driveLetter"

try {
  $sources = Join-Path $driveLetter 'sources'
  $installWim = Join-Path $bediRoot 'install.wim'
  $installEsdOnIso = Join-Path $sources 'install.esd'
  $installWimOnIso = Join-Path $sources 'install.wim'

  # Validate ISO structure before processing
  Write-Host "Validating ISO structure..."
  Write-Host "Drive letter: $driveLetter"
  Write-Host "Sources path: $sources"
  Write-Host "Install WIM path: $installWimOnIso"
  Write-Host "Install ESD path: $installEsdOnIso"
  
  if (-not (Test-Path $sources)) {
    Write-Host "Sources folder not found at: $sources"
    Write-Host "Checking what's actually in the root directory..."
    if (Test-Path $driveLetter) {
      Get-ChildItem -Path $driveLetter | ForEach-Object { Write-Host "  - $($_.Name)" }
    }
    throw "Sources folder not found at: $sources. This indicates the ISO is not a valid Windows installation ISO."
  }
  
  Write-Host "Sources folder found. Checking contents..."
  Get-ChildItem -Path $sources | ForEach-Object { Write-Host "  - $($_.Name)" }
  
  # Check for basic Windows ISO structure
  $requiredFiles = @('boot.wim')
  $missingFiles = @()
  foreach ($file in $requiredFiles) {
    $filePath = Join-Path $sources $file
    if (-not (Test-Path $filePath)) {
      $missingFiles += $file
    }
  }
  
  if ($missingFiles.Count -gt 0) {
    Write-Warning "Missing required Windows ISO files: $($missingFiles -join ', ')"
    Write-Warning "This may indicate the UUP conversion process failed or the ISO is corrupted."
  }

  Write-Host "Checking for install files..."
  Write-Host "Testing install.wim: $installWimOnIso"
  Write-Host "Test-Path result: $(Test-Path $installWimOnIso)"
  Write-Host "Testing install.esd: $installEsdOnIso"  
  Write-Host "Test-Path result: $(Test-Path $installEsdOnIso)"

  if (Test-Path $installWimOnIso) {
    Write-Host "Found install.wim on ISO. Copying to Bedi root..."
    Copy-Item -Path $installWimOnIso -Destination $installWim -Force
  } elseif (Test-Path $installEsdOnIso) {
    Write-Host "Found install.esd on ISO. Attempting ESD -> WIM conversion if wimlib present..."
    $esd = $installEsdOnIso
    $wimlib = Join-Path $filesDir 'wimlib-imagex.exe'
    if (-not (Test-Path $wimlib)) {
      Copy-Item -Path $esd -Destination (Join-Path $bediRoot 'install.esd') -Force
      Write-Warning "wimlib-imagex.exe missing: copied install.esd as-is. Add wimlib into Bedi/Files to enable ESD->WIM conversion."
    } else {
      Write-Host "Converting ESD -> WIM (index $WimIndex)... this may take some time."
      & $wimlib export $esd $WimIndex $installWim
      Write-Host "ESD exported to install.wim"
    }
  } else {
    # Provide detailed diagnostics about what's actually in the sources folder
    Write-Host "ERROR: Neither install.wim nor install.esd found in ISO's sources folder ($sources)."
    Write-Host "Checking what files are actually present in sources folder..."
    
    if (Test-Path $sources) {
      $sourceFiles = Get-ChildItem -Path $sources -File | Select-Object Name, Length
      Write-Host "Files found in sources folder:"
      foreach ($file in $sourceFiles) {
        Write-Host "  - $($file.Name) ($([math]::Round($file.Length/1MB, 2)) MB)"
      }
      
      # Check for alternative installation file names
      $altFiles = @('install.swm', 'install2.swm', 'install3.swm', 'install4.swm', 'boot.wim')
      foreach ($altFile in $altFiles) {
        $altPath = Join-Path $sources $altFile
        if (Test-Path $altPath) {
          Write-Host "  Found alternative file: $altFile"
        }
      }
    } else {
      Write-Host "Sources folder does not exist at: $sources"
    }
    
    throw "UUP ISO appears to be incomplete or corrupted. Expected install.wim or install.esd in sources folder but found none."
  }

  # Copy clients.esd if present
  $clientsEsdOnIso = Join-Path $sources 'clients.esd'
  if (Test-Path $clientsEsdOnIso) {
    Write-Host "Found clients.esd on ISO. Copying to $buildDir"
    Copy-Item -Path $clientsEsdOnIso -Destination (Join-Path $buildDir 'clients.esd') -Force
  }

  # Copy likely sxs/fod/lp folders if present
  $possible = @('sxs','fods','fod','lp','packages')
  foreach ($f in $possible) {
    $src = Join-Path $sources $f
    if (Test-Path $src) {
      Write-Host "Copying $f from ISO sources to $buildDir\$f ..."
      Copy-Item -Path $src -Destination (Join-Path $buildDir $f) -Recurse -Force -ErrorAction SilentlyContinue
    }
  }
  
  # Check language pack for EnterpriseG
  if ($TargetSKU -eq 'EnterpriseG') {
    $lpPath = Join-Path $sources 'lp'
    if (Test-Path $lpPath) {
      $lpFiles = Get-ChildItem -Path $lpPath -Filter "*en-us*" -Recurse
      if ($lpFiles.Count -eq 0) {
        Write-Warning "No en-US language pack found in ISO. EnterpriseG requires en-US language pack."
      } else {
        Write-Host "Found en-US language pack files: $($lpFiles.Count)"
      }
    } else {
      Write-Warning "No language pack folder found in ISO. EnterpriseG requires en-US language pack."
    }
  }

  # Validate EnterpriseG requirements
  if ($TargetSKU -eq 'EnterpriseG') {
    Write-Host "Validating EnterpriseG requirements..."
    
    # Check supported builds for EnterpriseG
    $supportedBuilds = @("17763", "19041", "22000", "22621", "25398", "26100", "27729")
    if ($Build -notin $supportedBuilds) {
      throw "EnterpriseG only supports builds: $($supportedBuilds -join ', '). Current build: $Build"
    }
    
    Write-Host "Build $Build is supported for EnterpriseG"
    Write-Host "EnterpriseG settings:"
    Write-Host "  - Language: en-US only"
    Write-Host "  - Microsoft Edge: Without (removed)"
    Write-Host "  - Windows Defender: Without (removed)"
    Write-Host "  - Product Key: YYVX9-NTFWV-6MDM3-9PT4T-4M68B"
  }

  # Generate minimal Bedi.ini for non-interactive run
  $iniPath = Join-Path $bediRoot 'Bedi.ini'
  Write-Host "Generating Bedi.ini -> $iniPath"
  
  # Set appropriate source SKU based on target
  $sourceSKU = if ($TargetSKU -eq 'EnterpriseG') { 'Professional' } else { 'Professional' }
  
  $iniContent = @"
; Auto-generated by bedi-ci-wrapper
_sourSKU=$sourceSKU
_targSKU=$TargetSKU
_store=Without
_defender=Without
_msedge=Without
_helospeech=Without
_winre=Without
_wifirtl=Without
"@
  $iniContent | Out-File -FilePath $iniPath -Encoding ASCII -Force

  # Warn about helper exes if missing
  $required = @('wimlib-imagex.exe','7z.exe','NSudo.exe','expand.exe')
  foreach ($r in $required) {
    if (-not (Test-Path (Join-Path $filesDir $r))) {
      Write-Warning "$r not found in $filesDir. Add it if Bedi needs it."
    }
  }

  # Preflight: required EnterpriseG payloads must exist in build folder
  if ($TargetSKU -eq 'EnterpriseG') {
    $lpEsd = Join-Path $buildDir 'Microsoft-Windows-Client-LanguagePack-Package-amd64-en-us.esd'
    $gEsd  = Join-Path $buildDir 'Microsoft-Windows-EditionSpecific-EnterpriseG-Package.esd'
    $missing = @()
    if (-not (Test-Path $lpEsd)) { $missing += (Split-Path -Leaf $lpEsd) }
    if (-not (Test-Path $gEsd))  { $missing += (Split-Path -Leaf $gEsd) }
    if ($missing.Count -gt 0) {
      throw "Missing required EnterpriseG payload(s) in $buildDir: $($missing -join ', '). Place the ESDs per README before running."
    }
  }

  # Run non-interactive automation script that drives Bedi.cmd
  $autoCmd = Join-Path $bediRoot 'bedi_auto.cmd'
  if (-not (Test-Path $autoCmd)) { throw "bedi_auto.cmd not found at $autoCmd" }
  Write-Host "Running bedi_auto.cmd (non-interactive EnterpriseG build)..."
  Push-Location $bediRoot
  & cmd /c ""$autoCmd""
  $rc = $LASTEXITCODE
  Pop-Location

  if ($rc -ne 0) {
    Write-Warning "Bedi.cmd exited with code $rc. Check Bedi\\log* for details."
  } else {
    Write-Host "Bedi finished. Verifying EnterpriseG transformation and debloat..."

    # Wait for install.wim to appear and reach a reasonable size
    $maxWaitSec = 300
    $waitStart = Get-Date
    while (-not (Test-Path $installWim)) {
      if (((Get-Date) - $waitStart).TotalSeconds -gt $maxWaitSec) { throw "Timeout waiting for install.wim to be created." }
      Start-Sleep -Seconds 2
    }
    # Wait a bit for file to finalize writes
    Start-Sleep -Seconds 3
    $wimInfo = Get-Item $installWim
    if ($wimInfo.Length -lt 800MB) { Write-Warning "install.wim is smaller than expected: $([math]::Round($wimInfo.Length/1MB,2)) MB" }

    # Verify edition using DISM (robust parsing)
    $dismOk = $false
    try {
      $out = & dism /English /Get-WimInfo /WimFile:$installWim /Index:1 2>&1
      if (-not $out) { $out = & dism /English /Get-WimInfo /WimFile:$installWim 2>&1 }
      if ($out) {
        $line = ($out | Select-String -Pattern "Current Edition\s*:")
        if ($line) {
          $txt = $line.ToString()
          Write-Host "DISM: $txt"
          if ($txt -match 'EnterpriseG') { $dismOk = $true }
        } else {
          Write-Warning "DISM output did not contain 'Current Edition:'"
        }
      } else {
        Write-Warning "DISM returned no output"
      }
    } catch {
      Write-Warning "DISM check error: $($_.Exception.Message)"
    }

    if (-not $dismOk) {
      # Fallback to wimlib-imagex if available
      $wimlibExe = Join-Path $filesDir 'wimlib-imagex.exe'
      if (Test-Path $wimlibExe) {
        try {
          $winfo = & $wimlibExe info $installWim 1 2>&1
          $wline = ($winfo | Select-String -Pattern "Edition|NAME|FLAGS" | Select-Object -First 1)
          Write-Host "wimlib: $($wline.ToString())"
          if (-not ($winfo -match 'EnterpriseG')) {
            throw "wimlib did not indicate EnterpriseG"
          }
        } catch {
          throw "Failed to verify edition (DISM and wimlib). Please check Bedi logs. Error: $($_.Exception.Message)"
        }
      } else {
        throw "Failed to verify edition with DISM and wimlib not available."
      }
    }

    # Basic debloat verification from logs
    $logAny = Get-ChildItem -Path (Join-Path $bediRoot 'log*') -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($null -eq $logAny) { Write-Warning "No Bedi logs found (log*). Skipping debloat verification." }
    else {
      $logText = (Get-ChildItem -Path (Join-Path $bediRoot 'log*') -Recurse -ErrorAction SilentlyContinue | ForEach-Object { Get-Content $_ -Raw -ErrorAction SilentlyContinue }) -join "`n"
      if ($iniContent -match '_msedge=Without') {
        if ($logText -notmatch 'Remove Microsoft Edge|/Remove-Edge') { Write-Warning "Edge removal not observed in logs." }
      }
      if ($iniContent -match '_defender=Without') {
        if ($logText -notmatch 'Quarantine Windows Defender|defender') { Write-Warning "Defender removal not observed in logs." }
      }
    }

    Write-Host "EnterpriseG verification passed. Proceeding to ISO build."
  }

  # Build ISO that includes the customized install.wim
  try {
    Write-Host "Preparing bootable ISO with customized install.wim..."

    $outDir = Join-Path $bediRoot ("bedi-output-$Build")
    if (Test-Path $outDir) { Remove-Item -Path $outDir -Recurse -Force }
    New-Item -ItemType Directory -Path $outDir | Out-Null

    $staging = Join-Path $bediRoot 'iso-staging'
    if (Test-Path $staging) { Remove-Item -Path $staging -Recurse -Force }
    New-Item -ItemType Directory -Path $staging | Out-Null

    # Copy the original ISO contents to staging
    Write-Host "Copying original ISO contents from $driveLetter to staging..."
    Get-ChildItem -Path $driveLetter -Force | ForEach-Object {
      $dest = Join-Path $staging $_.Name
      Copy-Item -Path $_.FullName -Destination $dest -Recurse -Force -ErrorAction SilentlyContinue
    }

    # Replace sources\install.wim with the customized one
    $stagingSources = Join-Path $staging 'sources'
    if (-not (Test-Path $stagingSources)) { throw "Staging 'sources' folder missing at $stagingSources" }
    $stagingInstallWim = Join-Path $stagingSources 'install.wim'
    Copy-Item -Path $installWim -Destination $stagingInstallWim -Force
    Write-Host "Replaced staging install.wim -> $stagingInstallWim"

    # Try to locate oscdimg.exe (preferred for a dual-boot BIOS/UEFI ISO)
    $oscdimgCandidates = @(
      'oscdimg.exe',
      (Join-Path $filesDir 'oscdimg.exe'),
      'C:\\ProgramData\\chocolatey\\bin\\oscdimg.exe',
      'C:\\Program Files (x86)\\Windows Kits\\10\\Assessment and Deployment Kit\\Deployment Tools\\amd64\\Oscdimg\\oscdimg.exe',
      'C:\\Program Files (x86)\\Windows Kits\\11\\Assessment and Deployment Kit\\Deployment Tools\\amd64\\Oscdimg\\oscdimg.exe'
    )
    $oscdimg = ($oscdimgCandidates | Where-Object { ($_ -eq 'oscdimg.exe' -and (Get-Command oscdimg.exe -ErrorAction SilentlyContinue)) -or (Test-Path $_) } | Select-Object -First 1)

    $isoOut = Join-Path $outDir ("bedi-output-$Build.iso")
    $label = "BEDI_${Build}_G"

    if ($oscdimg) {
      $etfs = Join-Path $staging 'boot/etfsboot.com'
      $efisys = Join-Path $staging 'efi/microsoft/boot/efisys.bin'
      if (-not (Test-Path $etfs)) { Write-Warning "etfsboot.com not found at $etfs; BIOS boot may not work." }
      if (-not (Test-Path $efisys)) { Write-Warning "efisys.bin not found at $efisys; UEFI boot may not work." }
      $bootdata = "2#p0,e,b$etfs#pEF,e,b$efisys"
      Write-Host "Creating bootable ISO using oscdimg..."
      & $oscdimg -bootdata:$bootdata -u2 -udfver102 -l:$label $staging $isoOut
      Write-Host "ISO created: $isoOut"
    } else {
      throw "oscdimg.exe not found. Please install Windows ADK Deployment Tools or place oscdimg.exe in Bedi/Files to produce a bootable ISO."
    }

    Write-Host "Output directory prepared (ISO only): $outDir"
  } catch {
    Write-Warning "Failed to build ISO: $($_.Exception.Message)"
  }

} finally {
  Write-Host "Unmounting ISO..."
  try { Dismount-DiskImage -ImagePath $isoResolved -ErrorAction SilentlyContinue } catch { Write-Warning "Could not dismount by path; you may need to dismount manually." }
}

Write-Host "Bedi CI wrapper finished."