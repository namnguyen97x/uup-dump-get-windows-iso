# list-targets.ps1
# Trích xuất danh sách key từ $TARGETS trong uup-dump-get-windows-iso.ps1

# Đọc toàn bộ nội dung file
$lines = Get-Content ./uup-dump-get-windows-iso.ps1
# Tìm vị trí bắt đầu và kết thúc của $TARGETS = @{ ... }
$start = ($lines | Select-String '^[ \t]*\$TARGETS\s*=\s*@\{' | Select-Object -First 1).LineNumber - 1
$end = ($lines[$start..($lines.Length-1)] | Select-String '^[ \t]*\}' | Select-Object -First 1).LineNumber + $start - 1
$targetBlock = $lines[$start..$end] -join "`n"
Invoke-Expression $targetBlock
$TARGETS.Keys | ConvertTo-Json 