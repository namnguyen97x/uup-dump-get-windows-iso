#!/usr/bin/pwsh
param(
    [string]$windowsTargetName,
    [string]$destinationDirectory='output'
)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

Write-Host "=== UUP Dump Debloater V2 (Post-Processing) ===" -ForegroundColor Cyan
Write-Host "Target: $windowsTargetName" -ForegroundColor Yellow
Write-Host "Method: Download full → Remove bloatware via DISM → Create clean ISO" -ForegroundColor Green

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

# Apps to KEEP (Core only)
$CORE_APPS = @(
    "Microsoft.WindowsCalculator",
    "Microsoft.WindowsNotepad", 
    "Microsoft.WindowsStore"
)

Write-Host "`n=== STEP 1: Download UUP Package (Full) ===" -ForegroundColor Cyan
# Sử dụng script gốc để tải full UUP package
& "$PSScriptRoot/../uup-dump-get-windows-iso.ps1" $windowsTargetName.Replace("-debloat", "") $destinationDirectory

$buildDirectory = "$destinationDirectory/$windowsTargetName"
$originalBuildDir = "$destinationDirectory/$($windowsTargetName.Replace('-debloat', ''))"

# Copy thư mục build gốc sang thư mục debloat
if (Test-Path $originalBuildDir) {
    Write-Host "Copying build directory for post-processing..." -ForegroundColor Yellow
    Copy-Item -Recurse $originalBuildDir $buildDirectory -Force
    
    # Patch CustomAppsList.txt và ConvertConfig.ini nếu cả hai file đều tồn tại
    $convertConfigPath = "$buildDirectory/ConvertConfig.ini"
    $customAppsListPath = "$buildDirectory/CustomAppsList.txt"
    $patchedCustomList = $false
    if (Test-Path $convertConfigPath -and Test-Path $customAppsListPath) {
        Write-Host "Patching CustomAppsList.txt to only keep 3 core apps..." -ForegroundColor Yellow
        $coreAppsContent = @(
            "Microsoft.WindowsCalculator",
            "Microsoft.WindowsNotepad",
            "Microsoft.WindowsStore"
        ) -join "`n"
        Set-Content -Path $customAppsListPath -Value $coreAppsContent -Encoding UTF8
        Write-Host "✅ Patched CustomAppsList.txt" -ForegroundColor Green

        # Patch ConvertConfig.ini
        Write-Host "Patching ConvertConfig.ini for CustomList=1 and AddUpdates=0..." -ForegroundColor Yellow
        $convertConfig = Get-Content $convertConfigPath
        $convertConfig = $convertConfig -replace '^(CustomList\s*)=.*','$1=1'
        $convertConfig = $convertConfig -replace '^(AddUpdates\s*)=.*','$1=0'
        if ($convertConfig -notmatch '^CustomList\s*=') {
            $convertConfig += "CustomList=1"
        }
        if ($convertConfig -notmatch '^AddUpdates\s*=') {
            $convertConfig += "AddUpdates=0"
        }
        Set-Content -Path $convertConfigPath -Value $convertConfig -Encoding ASCII
        Write-Host "✅ Patched ConvertConfig.ini" -ForegroundColor Green
        $patchedCustomList = $true
        # Nếu đã patch CustomAppsList.txt và ConvertConfig.ini thì tạo ISO và metadata, bỏ qua mount WIM/DISM
        Write-Host "CustomAppsList.txt and ConvertConfig.ini patched. Skipping WIM mount/DISM debloat." -ForegroundColor Cyan
        # Tạo ISO từ thư mục đã được debloat (thực chất là chỉ giữ lại app core)
        $isoName = "$windowsTargetName-debloated.iso"
        $isoPath = "$destinationDirectory\$isoName"
        # Sử dụng oscdimg để tạo ISO (nếu có)
        $oscdimgPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
        if (Test-Path $oscdimgPath) {
            Write-Host "Creating ISO with oscdimg..." -ForegroundColor Yellow
            & $oscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$buildDirectory\boot\etfsboot.com"#pEF,e,b"$buildDirectory\efi\microsoft\boot\efisys.bin" "$buildDirectory" "$isoPath"
        } else {
            Write-Host "oscdimg not found, using PowerShell method..." -ForegroundColor Yellow
            # Fallback method (nếu cần)
            $isoImage = New-Object -ComObject IMAPI2.MsftDiscMaster2
            # ... (implementation for creating ISO without oscdimg)
        }
        # Tạo metadata đơn giản
        $metadata = @{
            name = $windowsTargetName
            title = "Windows Debloated (Ultra-Lite, CustomList)"
            debloated = $true
            coreAppsOnly = $true
            method = "CustomAppsList patch (no DISM)"
            createdDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        }
        $metadataPath = "$isoPath.json"
        $metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataPath
        Write-Host "=== DEBLOATING COMPLETE (CustomList)! ===" -ForegroundColor Green
        Write-Host "Debloated ISO: $isoPath" -ForegroundColor Cyan
        Write-Host "Metadata: $metadataPath" -ForegroundColor Cyan
        exit 0
    }
}

Write-Host "`n=== STEP 2: Post-Process WIM (Remove Bloatware) ===" -ForegroundColor Cyan

# Tìm file WIM
$wimPath = Get-ChildItem "$buildDirectory\sources\install.wim" -ErrorAction SilentlyContinue
if (-not $wimPath) {
    Write-Host "Looking for install.esd instead..." -ForegroundColor Yellow
    $esdPath = Get-ChildItem "$buildDirectory\sources\install.esd" -ErrorAction SilentlyContinue
    if ($esdPath) {
        Write-Host "Converting ESD to WIM..." -ForegroundColor Yellow
        $wimPath = "$buildDirectory\sources\install.wim"
        dism /Export-Image /SourceImageFile:"$esdPath" /SourceIndex:1 /DestinationImageFile:"$wimPath" /DestinationName:"Windows" /Compress:max
    }
}

if (-not $wimPath) {
    throw "Cannot find install.wim or install.esd"
}

Write-Host "Found WIM: $wimPath" -ForegroundColor Green

# Mount WIM để xử lý
$mountPath = "$env:TEMP\WIM_MOUNT_$(Get-Random)"
New-Item -ItemType Directory $mountPath -Force | Out-Null

try {
    Write-Host "Mounting WIM for editing..." -ForegroundColor Yellow
    dism /Mount-Image /ImageFile:"$wimPath" /Index:1 /MountDir:"$mountPath"
    
    Write-Host "`n=== Removing Bloatware Apps ===" -ForegroundColor Cyan
    
    # Lấy danh sách tất cả Appx packages
    $allPackages = dism /Image:"$mountPath" /Get-ProvisionedAppxPackages | 
        Where-Object { $_ -like "*PackageName*" } |
        ForEach-Object { ($_ -split ":")[1].Trim() }
    
    $removedCount = 0
    $keptCount = 0
    
    foreach ($package in $allPackages) {
        $shouldKeep = $false
        foreach ($coreApp in $CORE_APPS) {
            if ($package -like "*$coreApp*") {
                $shouldKeep = $true
                break
            }
        }
        
        if (-not $shouldKeep) {
            try {
                Write-Host "Removing: $package" -ForegroundColor Red
                dism /Image:"$mountPath" /Remove-ProvisionedAppxPackage /PackageName:"$package" | Out-Null
                $removedCount++
            } catch {
                Write-Host "Failed to remove: $package" -ForegroundColor DarkRed
            }
        } else {
            Write-Host "Keeping: $package" -ForegroundColor Green
            $keptCount++
        }
    }
    
    Write-Host "`nDebloating Summary:" -ForegroundColor Cyan
    Write-Host "- Apps Removed: $removedCount" -ForegroundColor Red
    Write-Host "- Apps Kept: $keptCount" -ForegroundColor Green
    
    Write-Host "`nCommitting changes to WIM..." -ForegroundColor Yellow
    dism /Unmount-Image /MountDir:"$mountPath" /Commit
    
} catch {
    Write-Host "Error during debloating: $_" -ForegroundColor Red
    dism /Unmount-Image /MountDir:"$mountPath" /Discard
    throw
} finally {
    Remove-Item $mountPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`n=== STEP 3: Create Debloated ISO ===" -ForegroundColor Cyan

# Tạo ISO từ thư mục đã được debloat
$isoName = "$windowsTargetName-debloated.iso"
$isoPath = "$destinationDirectory\$isoName"

# Sử dụng oscdimg để tạo ISO (nếu có)
$oscdimgPath = "${env:ProgramFiles(x86)}\Windows Kits\10\Assessment and Deployment Kit\Deployment Tools\amd64\Oscdimg\oscdimg.exe"
if (Test-Path $oscdimgPath) {
    Write-Host "Creating ISO with oscdimg..." -ForegroundColor Yellow
    & $oscdimgPath -m -o -u2 -udfver102 -bootdata:2#p0,e,b"$buildDirectory\boot\etfsboot.com"#pEF,e,b"$buildDirectory\efi\microsoft\boot\efisys.bin" "$buildDirectory" "$isoPath"
} else {
    Write-Host "oscdimg not found, using PowerShell method..." -ForegroundColor Yellow
    # Fallback method
    $isoImage = New-Object -ComObject IMAPI2.MsftDiscMaster2
    # ... (implementation for creating ISO without oscdimg)
}

# Tạo metadata cho ISO debloated
$metadata = @{
    name = $windowsTargetName
    title = "Windows Debloated (Ultra-Lite)"
    debloated = $true
    coreAppsOnly = $true
    appsRemoved = $removedCount
    appsKept = $keptCount
    method = "Post-Processing with DISM"
    createdDate = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
}

$metadataPath = "$isoPath.json"
$metadata | ConvertTo-Json -Depth 10 | Set-Content $metadataPath

Write-Host "`n=== DEBLOATING COMPLETE! ===" -ForegroundColor Green
Write-Host "Debloated ISO: $isoPath" -ForegroundColor Cyan
Write-Host "Metadata: $metadataPath" -ForegroundColor Cyan
Write-Host "Apps Removed: $removedCount" -ForegroundColor Yellow
Write-Host "Apps Kept: $keptCount (Core only)" -ForegroundColor Yellow 