param(
    [string]$isoPath = "windows.iso",
    [string]$outputISO = "debloated-windows.iso",
    [switch]$testMode = $false
)

Write-Host "=== REAL DEBLOAT SCRIPT ==="
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "Parameters: isoPath='$isoPath', outputISO='$outputISO', testMode=$testMode"

# Check ISO file
if (-not (Test-Path $isoPath)) {
    Write-Host "ERROR: ISO file not found: $isoPath"
    exit 1
}

$originalSize = (Get-Item $isoPath).Length / 1GB
Write-Host "Original ISO: $([math]::Round($originalSize,2)) GB"

# Create temp directory
$dest = "C:\temp-debloat"
if (Test-Path $dest) {
    Remove-Item $dest -Recurse -Force
}
New-Item -ItemType Directory -Path $dest -Force | Out-Null

try {
    # Mount and copy ISO
    Write-Host "Mounting and copying ISO..."
    $mount = Mount-DiskImage -ImagePath (Resolve-Path $isoPath).Path -PassThru
    $drive = ($mount | Get-Volume).DriveLetter + ":\"
    
    robocopy $drive $dest /E /R:1 /W:1
    Dismount-DiskImage -ImagePath (Resolve-Path $isoPath).Path
    
    # Check sources directory
    if (-not (Test-Path "$dest\sources")) {
        Write-Host "ERROR: Sources directory not found"
        exit 1
    }
    
    Write-Host "=== STARTING REAL DEBLOAT ==="
    
    # 1. Remove unnecessary files from root
    Write-Host "1. Removing unnecessary root files..."
    $filesToRemove = @(
        "$dest\autorun.inf",
        "$dest\setup.exe"
    )
    foreach ($file in $filesToRemove) {
        if (Test-Path $file) {
            Remove-Item $file -Force
            Write-Host "  Removed: $(Split-Path $file -Leaf)"
        }
    }
    
    # 2. Remove language packs (keep only en-US)
    Write-Host "2. Removing extra language packs..."
    $langDirs = @("$dest\sources\lang", "$dest\support\lang")
    foreach ($langDir in $langDirs) {
        if (Test-Path $langDir) {
            Get-ChildItem $langDir | Where-Object { $_.Name -ne "en-us" -and $_.Name -ne "en-US" } | ForEach-Object {
                Remove-Item $_.FullName -Recurse -Force
                Write-Host "  Removed language: $($_.Name)"
            }
        }
    }
    
    # 3. Remove Windows PE components
    Write-Host "3. Removing Windows PE components..."
    $peFiles = @(
        "$dest\sources\boot.wim",
        "$dest\boot\*"
    )
    foreach ($peFile in $peFiles) {
        if (Test-Path $peFile) {
            Remove-Item $peFile -Recurse -Force -ErrorAction SilentlyContinue
            Write-Host "  Removed PE component: $(Split-Path $peFile -Leaf)"
        }
    }
    
    # 4. Clean sources directory
    Write-Host "4. Cleaning sources directory..."
    $sourcesToRemove = @(
        "$dest\sources\ei.cfg",
        "$dest\sources\pid.txt",
        "$dest\sources\setup.exe",
        "$dest\sources\setupprep.exe",
        "$dest\sources\uup",
        "$dest\sources\background.bmp"
    )
    foreach ($source in $sourcesToRemove) {
        if (Test-Path $source) {
            Remove-Item $source -Recurse -Force
            Write-Host "  Removed: $(Split-Path $source -Leaf)"
        }
    }
    
    # 5. Process install.wim/install.esd if exists
    $installWim = "$dest\sources\install.wim"
    $installEsd = "$dest\sources\install.esd"
    
    if (Test-Path $installWim) {
        $beforeWimSize = (Get-Item $installWim).Length / 1GB
        Write-Host "5. Processing install.wim ($([math]::Round($beforeWimSize,2)) GB)..."
        
        # Simple optimization: Export and recompress WIM to reduce size
        $tempWim = "$dest\sources\install_temp.wim"
        Write-Host "  Recompressing WIM file..."
        
        # Use DISM to export with maximum compression
        $result = & dism /export-image /sourceimagefile:$installWim /sourceindex:1 /destinationimagefile:$tempWim /compress:max /checkintegrity 2>&1
        
        if ($LASTEXITCODE -eq 0 -and (Test-Path $tempWim)) {
            Remove-Item $installWim -Force
            Rename-Item $tempWim $installWim
            
            $afterWimSize = (Get-Item $installWim).Length / 1GB
            $wimSaved = $beforeWimSize - $afterWimSize
            Write-Host "  WIM recompressed: $([math]::Round($afterWimSize,2)) GB (saved $([math]::Round($wimSaved,2)) GB)"
        } else {
            Write-Host "  WIM recompression failed, keeping original"
            if (Test-Path $tempWim) { Remove-Item $tempWim -Force }
        }
        
    } elseif (Test-Path $installEsd) {
        Write-Host "5. Found install.esd - keeping as-is (already compressed)"
    } else {
        Write-Host "5. No install.wim or install.esd found - this may not be a valid Windows ISO"
    }
    
    # 6. Remove additional directories
    Write-Host "6. Removing additional bloat directories..."
    $dirsToRemove = @(
        "$dest\support",
        "$dest\upgrade",
        "$dest\efi\boot\fonts",
        "$dest\sources\dlmanifests"
    )
    foreach ($dir in $dirsToRemove) {
        if (Test-Path $dir) {
            $dirSize = (Get-ChildItem $dir -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1MB
            Remove-Item $dir -Recurse -Force
            Write-Host "  Removed directory: $(Split-Path $dir -Leaf) ($([math]::Round($dirSize,1)) MB)"
        }
    }
    
    if ($testMode) {
        Write-Host "=== TEST MODE: Showing debloat results ==="
        $currentSize = (Get-ChildItem $dest -Recurse -File | Measure-Object -Property Length -Sum).Sum / 1GB
        $saved = $originalSize - $currentSize
        Write-Host "Original size: $([math]::Round($originalSize,2)) GB"
        Write-Host "Debloated size: $([math]::Round($currentSize,2)) GB"
        Write-Host "Space saved: $([math]::Round($saved,2)) GB ($([math]::Round($saved/$originalSize*100,1))%)"
        
        # Show what was actually removed
        Write-Host ""
        Write-Host "=== DEBLOAT VERIFICATION ==="
        Write-Host "Checking what was removed:"
        
        $checks = @{
            "Language packs" = "$dest\sources\lang"
            "Boot WIM" = "$dest\sources\boot.wim"
            "Support dir" = "$dest\support"
            "Setup.exe" = "$dest\setup.exe"
            "EI.cfg" = "$dest\sources\ei.cfg"
        }
        
        foreach ($item in $checks.GetEnumerator()) {
            $exists = Test-Path $item.Value
            $status = if ($exists) { "❌ Still exists" } else { "✅ Removed" }
            Write-Host "$($item.Key): $status"
        }
        
        # Check language directories if they exist
        if (Test-Path "$dest\sources\lang") {
            $langCount = (Get-ChildItem "$dest\sources\lang" | Measure-Object).Count
            Write-Host "Remaining languages: $langCount"
        }
        
        # Check install.wim compression
        if (Test-Path "$dest\sources\install.wim") {
            $wimSize = (Get-Item "$dest\sources\install.wim").Length / 1GB
            Write-Host "install.wim size: $([math]::Round($wimSize,2)) GB"
        }
        
        exit 0
    }
    
    # 7. Create optimized ISO
    Write-Host "7. Creating optimized output..."
    
    # Create ZIP with maximum compression
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    
    Write-Host "  Compressing debloated files..."
    $zipPath = $outputISO.Replace(".iso", ".zip")
    
    # Use compression level for better size reduction
    [System.IO.Compression.ZipFile]::CreateFromDirectory($dest, $zipPath, [System.IO.Compression.CompressionLevel]::Optimal, $false)
    
    if (Test-Path $zipPath) {
        Rename-Item $zipPath $outputISO
        
        $finalSize = (Get-Item $outputISO).Length / 1GB
        $totalSaved = $originalSize - $finalSize
        
        Write-Host "=== DEBLOAT COMPLETED ==="
        Write-Host "Original size: $([math]::Round($originalSize,2)) GB"
        Write-Host "Final size: $([math]::Round($finalSize,2)) GB"
        Write-Host "Total saved: $([math]::Round($totalSaved,2)) GB ($([math]::Round($totalSaved/$originalSize*100,1))%)"
        
        if ($totalSaved -gt 0.5) {
            Write-Host "✅ Significant space savings achieved!"
        } else {
            Write-Host "⚠️ Limited space savings - may need more aggressive debloating"
        }
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
} finally {
    # Cleanup
    if (Test-Path $dest) {
        Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "=== REAL DEBLOAT COMPLETED ==="
exit 0 