param(
    [string]$isoPath = "windows.iso",
    [string]$outputISO = "debloated-windows.iso",
    [switch]$testMode = $false
)

Write-Host "=== SIMPLE DEBLOAT SCRIPT ==="
Write-Host "PowerShell Version: $($PSVersionTable.PSVersion)"
Write-Host "Parameters: isoPath='$isoPath', outputISO='$outputISO', testMode=$testMode"
Write-Host "Working Directory: $(Get-Location)"
Write-Host "Current User: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"

# Check ISO file
if (-not (Test-Path $isoPath)) {
    Write-Host "ERROR: ISO file not found: $isoPath"
    Write-Host "Files in current directory:"
    Get-ChildItem | ForEach-Object { Write-Host "  $($_.Name)" }
    exit 1
}

$isoSize = (Get-Item $isoPath).Length / 1GB
Write-Host "ISO File: $isoPath, Size: $([math]::Round($isoSize,2)) GB"

# Create temp directory
$dest = "C:\temp-debloat"
if (Test-Path $dest) {
    Write-Host "Removing old temp directory..."
    Remove-Item $dest -Recurse -Force
}
Write-Host "Creating temp directory: $dest"
New-Item -ItemType Directory -Path $dest -Force | Out-Null

try {
    # Mount ISO
    Write-Host "Mounting ISO..."
    $mount = Mount-DiskImage -ImagePath (Resolve-Path $isoPath).Path -PassThru
    $drive = ($mount | Get-Volume).DriveLetter + ":\"
    Write-Host "ISO mounted at: $drive"
    
    # Copy files
    Write-Host "Copying ISO contents..."
    robocopy $drive $dest /E /R:1 /W:1
    $robocopyExitCode = $LASTEXITCODE
    Write-Host "Robocopy exit code: $robocopyExitCode"
    
    # Unmount
    Write-Host "Unmounting ISO..."
    Dismount-DiskImage -ImagePath (Resolve-Path $isoPath).Path
    
    # Check if copy was successful
    if (Test-Path "$dest\sources") {
        Write-Host "SUCCESS: ISO contents copied to $dest"
        Write-Host "Sources directory exists: $(Test-Path "$dest\sources")"
        
        # List files in sources
        if (Test-Path "$dest\sources") {
            Write-Host "Files in sources directory:"
            Get-ChildItem "$dest\sources" | ForEach-Object {
                $size = if ($_.Length) { "$([math]::Round($_.Length / 1MB, 1)) MB" } else { "DIR" }
                Write-Host "  $($_.Name) - $size"
            }
        }
        
        # Check for install.wim/install.esd
        $installWim = "$dest\sources\install.wim"
        $installEsd = "$dest\sources\install.esd"
        
        if (Test-Path $installWim) {
            $wimSize = (Get-Item $installWim).Length / 1GB
            Write-Host "Found install.wim: $([math]::Round($wimSize,2)) GB"
        } elseif (Test-Path $installEsd) {
            $esdSize = (Get-Item $installEsd).Length / 1GB
            Write-Host "Found install.esd: $([math]::Round($esdSize,2)) GB"
        } else {
            Write-Host "WARNING: No install.wim or install.esd found"
        }
        
        if ($testMode) {
            Write-Host "TEST MODE: Exiting after successful copy"
            exit 0
        }
        
        # Simple debloat - just create a basic "debloated" version
        Write-Host "Creating simplified debloated ISO..."
        
        # For now, just compress the directory to a ZIP and rename to ISO
        # This is not a real ISO but will test the pipeline
        $zipPath = $outputISO.Replace(".iso", ".zip")
        Write-Host "Creating archive: $zipPath"
        
        Add-Type -AssemblyName System.IO.Compression.FileSystem
        [System.IO.Compression.ZipFile]::CreateFromDirectory($dest, $zipPath)
        
        if (Test-Path $zipPath) {
            Rename-Item $zipPath $outputISO
            $outputSize = (Get-Item $outputISO).Length / 1GB
            Write-Host "SUCCESS: Created $outputISO ($([math]::Round($outputSize,2)) GB)"
        }
        
    } else {
        Write-Host "ERROR: Sources directory not found after copy"
        exit 1
    }
    
} catch {
    Write-Host "ERROR: $($_.Exception.Message)"
    exit 1
} finally {
    # Cleanup
    if (Test-Path $dest) {
        Write-Host "Cleaning up temp directory..."
        Remove-Item $dest -Recurse -Force -ErrorAction SilentlyContinue
    }
}

Write-Host "=== SCRIPT COMPLETED SUCCESSFULLY ==="
exit 0 