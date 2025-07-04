# list-targets.ps1
# Trích xuất danh sách key từ $TARGETS trong uup-dump-get-windows-iso.ps1

# Đọc toàn bộ nội dung file
$lines = Get-Content ./uup-dump-get-windows-iso.ps1
# Tìm vị trí bắt đầu của $TARGETS = @{
$start = ($lines | Select-String '^[ \t]*\$TARGETS\s*=\s*@\{' | Select-Object -First 1).LineNumber - 1

# Đếm ngoặc để tìm đúng vị trí kết thúc block
$braceCount = 0
$end = $null
for ($i = $start; $i -lt $lines.Length; $i++) {
    $line = $lines[$i]
    $braceCount += ($line -split '\{').Count - 1
    $braceCount -= ($line -split '\}').Count - 1
    if ($braceCount -eq 0) {
        $end = $i
        break
    }
}
if ($end -eq $null) { throw "Không tìm thấy dấu } kết thúc block!" }
$targetBlock = $lines[$start..$end] -join "`n"
Invoke-Expression $targetBlock
$TARGETS.Keys | ConvertTo-Json 