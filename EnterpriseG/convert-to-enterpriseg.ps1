param(
    [Parameter(Mandatory=$true)]
    [string]$InputIso,
    [Parameter(Mandatory=$false)]
    [string]$OutputIso = ''
)

# Đường dẫn các tool và file cần thiết
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Definition
$FilesDir = Join-Path $ScriptRoot 'files'
$TempDir = Join-Path $env:TEMP ("EnterpriseG-" + [guid]::NewGuid().ToString())

# Tạo thư mục tạm
New-Item -ItemType Directory -Force -Path $TempDir | Out-Null

# 1. Giải nén ISO gốc
Write-Host "[+] Giải nén ISO: $InputIso"
& "$FilesDir\7z.exe" x $InputIso -o"$TempDir\iso" -y | Out-Null

# 2. Mount/giải nén install.wim
$WimPath = Get-ChildItem -Path "$TempDir/iso/sources" -Filter "install.wim" | Select-Object -First 1
if (-not $WimPath) { throw "Không tìm thấy install.wim trong ISO!" }
$MountDir = Join-Path $TempDir 'mount'
New-Item -ItemType Directory -Force -Path $MountDir | Out-Null
Write-Host "[+] Mount install.wim"
& "$FilesDir\wimlib-imagex.exe" mount $WimPath.FullName 1 $MountDir | Out-Null

# 3. Áp dụng các tuỳ chọn (ví dụ: Remove Edge, Add regedit, ...)
Write-Host "[+] Áp dụng các tuỳ chọn EnterpriseG..."
# Chạy RemoveEdge.cmd nếu có
if (Test-Path "$FilesDir\Scripts\RemoveEdge.cmd") {
    Write-Host "  - Remove Edge"
    & "$FilesDir\Scripts\RemoveEdge.cmd"
}
# Thêm regedit.reg nếu có
if (Test-Path "$FilesDir\regedit.reg") {
    Write-Host "  - Thêm regedit.reg"
    reg import "$FilesDir\regedit.reg"
}
# Thêm các bước khác tuỳ theo options.json...

# 4. Unmount và commit thay đổi vào WIM
Write-Host "[+] Lưu thay đổi vào install.wim"
& "$FilesDir\wimlib-imagex.exe" unmount $MountDir --commit | Out-Null

# 5. Đóng gói lại thành ISO EnterpriseG
if (-not $OutputIso) {
    $OutputIso = [System.IO.Path]::ChangeExtension($InputIso, '-enterpriseg.iso')
}
Write-Host "[+] Đóng gói lại thành ISO: $OutputIso"
& "$FilesDir\7z.exe" a -tiso $OutputIso "$TempDir\iso\*" | Out-Null

# 6. Xoá thư mục tạm
Remove-Item -Recurse -Force $TempDir

Write-Host "[OK] Done! EnterpriseG ISO file: $OutputIso" 