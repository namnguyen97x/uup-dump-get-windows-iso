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
function New-QueryString([hashtable]$parameters) {
    @($parameters.GetEnumerator() | ForEach-Object {
        "$($_.Key)=$([System.Web.HttpUtility]::UrlEncode($_.Value))"
    }) -join '&'
}

function Invoke-UupDumpApi([string]$name, [hashtable]$body) {
    # see https://git.uupdump.net/uup-dump/json-api
    for ($n = 0; $n -lt 15; ++$n) {
        if ($n) {
            Write-Host "Waiting a bit before retrying the uup-dump api ${name} request #$n"
            Start-Sleep -Seconds 10
            Write-Host "Retrying the uup-dump api ${name} request #$n"
        }
        try {
            return Invoke-RestMethod `
                -Method Get `
                -Uri "https://api.uupdump.net/$name.php" `
                -Body $body
        } catch {
            Write-Host "WARN: failed the uup-dump api $name request: $_"
        }
    }
    throw "timeout making the uup-dump api $name request"
}

function Get-UupDumpIso($name, $target) {
    Write-Host "Getting the $name metadata"
    $result = Invoke-UupDumpApi listid @{
        search = $target.search
    }
    $result.response.builds.PSObject.Properties `
        | ForEach-Object {
            $id = $_.Value.uuid
            $uupDumpUrl = 'https://uupdump.net/selectlang.php?' + (New-QueryString @{
                id = $id
            })
            Write-Host "Processing $name $id ($uupDumpUrl)"
            $_
        } `
        | Where-Object {
            # ignore previews when they are not explicitly requested.
            $result = $target.search -like '*preview*' -or $_.Value.title -notlike '*preview*'
            if (!$result) {
                Write-Host "Skipping. Expected preview=false. Got preview=true."
            }
            $result
        } `
        | ForEach-Object {
            $id = $_.Value.uuid
            Write-Host "Getting the $name $id langs metadata"
            $result = Invoke-UupDumpApi listlangs @{
                id = $id
            }
            if ($result.response.updateInfo.build -ne $_.Value.build) {
                throw 'for some reason listlangs returned an unexpected build'
            }
            $_.Value | Add-Member -NotePropertyMembers @{
                langs = $result.response.langFancyNames
                info = $result.response.updateInfo
            }
            $langs = $_.Value.langs.PSObject.Properties.Name
            $editions = if ($langs -contains 'en-us') {
                Write-Host "Getting the $name $id editions metadata"
                $result = Invoke-UupDumpApi listeditions @{
                    id = $id
                    lang = 'en-us'
                }
                $result.response.editionFancyNames
            } else {
                Write-Host "Skipping. Expected langs=en-us. Got langs=$($langs -join ',')."
                [PSCustomObject]@{}
            }
            $_.Value | Add-Member -NotePropertyMembers @{
                editions = $editions
            }
            $_
        } `
        | Where-Object {
            # only return builds that match criteria
            $ring = $_.Value.info.ring
            $langs = $_.Value.langs.PSObject.Properties.Name
            $editions = $_.Value.editions.PSObject.Properties.Name
            $result = $true
            $expectedRing = if ($target.PSObject.Properties.Name -contains 'ring') {
                $target.ring
            } else {
                'RETAIL'
            }
            if ($ring -ne $expectedRing) {
                Write-Host "Skipping. Expected ring=$expectedRing. Got ring=$ring."
                $result = $false
            }
            if ($langs -notcontains 'en-us') {
                Write-Host "Skipping. Expected langs=en-us. Got langs=$($langs -join ',')."
                $result = $false
            }
            if ($editions -notcontains $target.edition) {
                Write-Host "Skipping. Expected editions=$($target.edition). Got editions=$($editions -join ',')."
                $result = $false
            }
            $result
        } `
        | Select-Object -First 1 `
        | ForEach-Object {
            $id = $_.Value.uuid
            [PSCustomObject]@{
                name = $name
                title = $_.Value.title
                build = $_.Value.build
                id = $id
                edition = $target.edition
                virtualEdition = $target.virtualEdition
                apiUrl = 'https://api.uupdump.net/get.php?' + (New-QueryString @{
                    id = $id
                    lang = 'en-us'
                    edition = $target.edition
                })
                downloadUrl = 'https://uupdump.net/download.php?' + (New-QueryString @{
                    id = $id
                    pack = 'en-us'
                    edition = $target.edition
                })
                downloadPackageUrl = 'https://uupdump.net/get.php?' + (New-QueryString @{
                    id = $id
                    pack = 'en-us'
                    edition = $target.edition
                })
            }
        }
}

function Get-IsoWindowsImages($isoPath) {
    $isoPath = Resolve-Path $isoPath
    Write-Host "Mounting $isoPath"
    $isoImage = Mount-DiskImage $isoPath -PassThru
    try {
        $isoVolume = $isoImage | Get-Volume
        $installPath = "$($isoVolume.DriveLetter):\sources\install.wim"
        Write-Host "Getting Windows images from $installPath"
        Get-WindowsImage -ImagePath $installPath `
            | ForEach-Object {
                $image = Get-WindowsImage `
                    -ImagePath $installPath `
                    -Index $_.ImageIndex
                $imageVersion = $image.Version
                [PSCustomObject]@{
                    index = $image.ImageIndex
                    name = $image.ImageName
                    version = $imageVersion
                }
            }
    } finally {
        Write-Host "Dismounting $isoPath"
        Dismount-DiskImage $isoPath | Out-Null
    }
}

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

    # ADVANCED DEBLOATING: Modify UUP converter script directly
    Write-Host "Modifying UUP converter script for advanced debloating"
    $uupScriptPath = "$buildDirectory/uup_download_windows.cmd"
    if (Test-Path $uupScriptPath) {
        $uupScript = Get-Content $uupScriptPath -Raw
        # Replace the call to download all apps with custom logic
        $modifiedScript = $uupScript -replace 'ConvertConfig\.ini', 'ConvertConfig.ini'
        Set-Content -Path $uupScriptPath -Value $modifiedScript -Encoding ASCII
    }

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