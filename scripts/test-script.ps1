param(
    [string]$isoPath = "",
    [string]$outputISO = "",
    [switch]$testMode = $false
)

Write-Host "=== TEST SCRIPT EXECUTION ==="
Write-Host "PowerShell version: $($PSVersionTable.PSVersion)"
Write-Host "Working directory: $(Get-Location)"
Write-Host "Parameters received:"
Write-Host "  isoPath: '$isoPath'"
Write-Host "  outputISO: '$outputISO'"
Write-Host "  testMode: $testMode"

if ($isoPath) {
    Write-Host "ISO file exists: $(Test-Path $isoPath)"
    if (Test-Path $isoPath) {
        $size = (Get-Item $isoPath).Length / 1GB
        Write-Host "ISO file size: $([math]::Round($size, 2)) GB"
    }
}

Write-Host "Current user: $([System.Security.Principal.WindowsIdentity]::GetCurrent().Name)"
Write-Host "Is Admin: $(([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] 'Administrator'))"

Write-Host "Available commands:"
Write-Host "  dism: $(if (Get-Command dism -ErrorAction SilentlyContinue) { 'YES' } else { 'NO' })"
Write-Host "  robocopy: $(if (Get-Command robocopy -ErrorAction SilentlyContinue) { 'YES' } else { 'NO' })"
Write-Host "  reg: $(if (Get-Command reg -ErrorAction SilentlyContinue) { 'YES' } else { 'NO' })"

Write-Host "=== TEST COMPLETED SUCCESSFULLY ==="
exit 0 