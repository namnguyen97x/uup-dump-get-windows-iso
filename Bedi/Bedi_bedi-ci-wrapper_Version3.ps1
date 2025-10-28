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
if (-not $news) {
  Write-Warning "Could not detect new drive letter automatically. You may need to mount ISO manually. Continuing assuming $isoResolved is accessible."
  $driveRoot = ($after | Where-Object { $_ -notin $before } | Select-Object -First 1)
} else {
  $driveRoot = $news[0]
}

# Ensure driveRoot is a string and handle edge cases
if (-not $driveRoot) {
  throw "Could not determine mounted drive letter. Please mount the ISO manually and provide the drive letter."
}
$driveLetter = [string]$driveRoot.TrimEnd('\')
Write-Host "ISO mounted at $driveLetter"

try {
  $sources = Join-Path $driveLetter 'sources'
  $installWim = Join-Path $bediRoot 'install.wim'
  $installEsdOnIso = Join-Path $sources 'install.esd'
  $installWimOnIso = Join-Path $sources 'install.wim'

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
    throw "Neither install.wim nor install.esd found in ISO's sources folder ($sources)."
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

  # Run Bedi.cmd (prefer NSudo if available)
  $bediCmd = Join-Path $bediRoot 'Bedi.cmd'
  if (-not (Test-Path $bediCmd)) { throw "Bedi.cmd not found at $bediCmd" }

  Push-Location $bediRoot
  $nsudoExe = Join-Path $filesDir 'NSudo.exe'
  if (Test-Path $nsudoExe) {
    Write-Host "Using NSudo to run Bedi as TrustedInstaller/System..."
    & $nsudoExe -U:T -P:E -UseCurrentConsole -Wait cmd /c "Bedi.cmd"
    $rc = $LASTEXITCODE
  } else {
    Write-Host "NSudo not found. Attempting to run Bedi directly (requires elevated session)..."
    Start-Process -FilePath 'cmd.exe' -ArgumentList '/c','Bedi.cmd' -Wait -NoNewWindow
    $rc = $LASTEXITCODE
  }
  Pop-Location

  if ($rc -ne 0) { Write-Warning "Bedi.cmd exited with code $rc. Check Bedi\log* for details." } else { Write-Host "Bedi completed successfully (check outputs in $bediRoot)." }

} finally {
  Write-Host "Unmounting ISO..."
  try { Dismount-DiskImage -ImagePath $isoResolved -ErrorAction SilentlyContinue } catch { Write-Warning "Could not dismount by path; you may need to dismount manually." }
}

Write-Host "Bedi CI wrapper finished."