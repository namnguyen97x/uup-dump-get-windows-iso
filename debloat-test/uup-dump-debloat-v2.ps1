#!/usr/bin/pwsh
param(
    [string]$windowsTargetName,
    [string]$destinationDirectory='output'
)

Set-StrictMode -Version Latest
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Stop'

Write-Host "=== UUP Dump Debloater V2 (Post-Processing Method) ==="
Write-Host "Target: $windowsTargetName"
Write-Host "Output: $destinationDirectory"

# Dừng script hiện tại nếu đang chạy
Write-Host ""
Write-Host "NOTICE: This is V2 approach using post-processing debloating."
Write-Host "Please stop the current script and use this method instead."
Write-Host ""
Write-Host "V2 Method:"
Write-Host "1. Download UUP package normally (all apps)"
Write-Host "2. Use DISM to remove bloatware from WIM after conversion"
Write-Host "3. Create clean ISO from debloated WIM"
Write-Host ""
Write-Host "This method is more reliable than CustomList approach."
Write-Host ""
Write-Host "To implement V2, we need to:"
Write-Host "- Run original UUP converter first"
Write-Host "- Mount the created WIM file"  
Write-Host "- Use Remove-AppxProvisionedPackage to remove bloatware"
Write-Host "- Unmount and save the WIM"
Write-Host "- Create new ISO from clean WIM" 