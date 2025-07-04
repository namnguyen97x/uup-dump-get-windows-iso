#!/usr/bin/pwsh
param(
    [string]$windowsTargetName,
    [string]$destinationDirectory='output'
)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'
trap {
    Write-Host "ERROR: $_"
    @(($_.ScriptStackTrace -split '\r?\n') -replace '^(.*)$','ERROR: $1') | Write-Host
    @(($_.Exception.ToString() -split '\r?\n') -replace '^(.*)$','ERROR EXCEPTION: $1') | Write-Host
    Exit 1
}

$TARGETS = @{
    "windows-11-24h2-debloat" = @{
        search = "window 11 26100 amd64"
        edition = "Professional"
        virtualEdition = $null
    }
    "windows-11-23h2-debloat" = @{
        search = "window 11 22631 amd64"
        edition = "Professional"
        virtualEdition = $null
    }
}

# Import functions from original script
. "$PSScriptRoot/../uup-dump-get-windows-iso.ps1" -WindowsTargetName "dummy" -DestinationDirectory "dummy" 2>$null
# Reset error action after importing
$ErrorActionPreference = 'Stop'

function New-DebloatedCustomAppsList {
    @'
Microsoft.WindowsCalculator
Microsoft.WindowsNotepad
Microsoft.WindowsStore
'@
}

function Get-WindowsIsoDebloated($name, $destinationDirectory) {
    $iso = Get-UupDumpIso $name $TARGETS.$name

    # ensure the build is a version number.
    if ($iso.build -notmatch '^\d+\.\d+$') {
        throw "unexpected $name build: $($iso.build)"
    }

    $buildDirectory = "$destinationDirectory/$name"
    $destinationIsoPath = "$buildDirectory.iso"
    $destinationIsoMetadataPath = "$destinationIsoPath.json"
    $destinationIsoChecksumPath = "$destinationIsoPath.sha256.txt"

    # create the build directory.
    if (Test-Path $buildDirectory) {
        Remove-Item -Force -Recurse $buildDirectory | Out-Null
    }
    New-Item -ItemType Directory -Force $buildDirectory | Out-Null

    # define the iso title.
    $edition = if ($iso.virtualEdition) {
        $iso.virtualEdition
    } else {
        $iso.edition
    }
    $title = "$name $edition $($iso.build) Debloated"

    Write-Host "Downloading the UUP dump download package for $title from $($iso.downloadPackageUrl)"
    $downloadPackageBody = if ($iso.virtualEdition) {
        @{
            autodl = 3
            updates = 1
            cleanup = 1
            'virtualEditions[]' = $iso.virtualEdition
        }
    } else {
        @{
            autodl = 2
            updates = 1
            cleanup = 1
        }
    }
    Invoke-WebRequest `
        -Method Post `
        -Uri $iso.downloadPackageUrl `
        -Body $downloadPackageBody `
        -OutFile "$buildDirectory.zip" `
        | Out-Null
    Expand-Archive "$buildDirectory.zip" $buildDirectory

    # ADD DEBLOATING: Create CustomAppsList.txt with minimal apps
    Write-Host "Creating CustomAppsList.txt for debloating"
    $customAppsContent = New-DebloatedCustomAppsList
    Set-Content -Path "$buildDirectory/CustomAppsList.txt" -Value $customAppsContent -Encoding UTF8

    # patch the uup-converter configuration.
    Write-Host "Configuring UUP converter for debloating"
    $convertConfig = (Get-Content $buildDirectory/ConvertConfig.ini) `
        -replace '^(AutoExit\s*)=.*','$1=1' `
        -replace '^(ResetBase\s*)=.*','$1=1' `
        -replace '^(SkipWinRE\s*)=.*','$1=1' `
        -replace '^(CustomList\s*)=.*','$1=1'  # ENABLE CustomList for debloating
    
    if ($iso.virtualEdition) {
        $convertConfig = $convertConfig `
            -replace '^(StartVirtual\s*)=.*','$1=1' `
            -replace '^(vDeleteSource\s*)=.*','$1=1' `
            -replace '^(vAutoEditions\s*)=.*',"`$1=$($iso.virtualEdition)"
    }
    Set-Content `
        -Encoding ascii `
        -Path $buildDirectory/ConvertConfig.ini `
        -Value $convertConfig

    Write-Host "Creating the debloated $title iso file inside the $buildDirectory directory"
    Push-Location $buildDirectory
    powershell cmd /c uup_download_windows.cmd | Out-String -Stream
    if ($LASTEXITCODE) {
        throw "uup_download_windows.cmd failed with exit code $LASTEXITCODE"
    }
    Pop-Location

    $sourceIsoPath = Resolve-Path $buildDirectory/*.iso

    Write-Host "Getting the $sourceIsoPath checksum"
    $isoChecksum = (Get-FileHash -Algorithm SHA256 $sourceIsoPath).Hash.ToLowerInvariant()
    Set-Content -Encoding ascii -NoNewline `
        -Path $destinationIsoChecksumPath `
        -Value $isoChecksum

    $windowsImages = Get-IsoWindowsImages $sourceIsoPath

    # create the iso metadata file.
    Set-Content `
        -Path $destinationIsoMetadataPath `
        -Value (
            ([PSCustomObject]@{
                name = $name
                title = "$($iso.title) (Debloated)"
                build = $iso.build
                checksum = $isoChecksum
                debloated = $true
                customApps = ($customAppsContent -split "`n" | Where-Object { $_.Trim() -ne "" })
                images = @($windowsImages)
                uupDump = @{
                    id = $iso.id
                    apiUrl = $iso.apiUrl
                    downloadUrl = $iso.downloadUrl
                    downloadPackageUrl = $iso.downloadPackageUrl
                }
            } | ConvertTo-Json -Depth 99) -replace '\\u0026','&'
        )

    Write-Host "Moving the created $sourceIsoPath to $destinationIsoPath"
    Move-Item -Force $sourceIsoPath $destinationIsoPath

    Write-Host 'Debloated Windows ISO created successfully!'
}

# Only run if called directly (not when imported)
if ($MyInvocation.InvocationName -ne '.') {
    Get-WindowsIsoDebloated $windowsTargetName $destinationDirectory
} 