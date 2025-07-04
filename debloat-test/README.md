# Windows Debloated ISO Builder

Thư mục này chứa các script thử nghiệm để tạo Windows ISO đã được debloat (loại bỏ bloatware).

## Cách hoạt động

### Phương pháp Debloating
Thay vì sử dụng "create download package for these updates" (không có CustomAppsList.txt), script này:

1. **Download UUP package thông thường** từ UUP Dump
2. **Tự động tạo CustomAppsList.txt** với danh sách ứng dụng tối thiểu
3. **Bật CustomList=1** trong ConvertConfig.ini
4. **Chạy UUP converter** - sẽ chỉ tải và cài đặt apps trong CustomList

### Danh sách Apps được giữ lại (Core Only)
- Microsoft.WindowsCalculator (Máy tính)
- Microsoft.WindowsNotepad (Notepad)
- Microsoft.WindowsStore (Microsoft Store)

**Tất cả apps khác đều bị loại bỏ** - Chỉ giữ lại 3 app core thiết yếu nhất!

## Files

- `uup-dump-debloat.ps1` - Script chính tạo debloated ISO
- `list-targets-debloat.ps1` - Script lấy danh sách target cho workflow
- `.github/workflows/build-debloat.yml` - GitHub Actions workflow riêng
- `README.md` - File này

## Targets hiện tại

- `windows-11-24h2-debloat` - Windows 11 24H2 (build 26100) debloated
- `windows-11-23h2-debloat` - Windows 11 23H2 (build 22631) debloated

## Cách sử dụng

### Chạy thủ công
```powershell
cd debloat-test
pwsh ./uup-dump-debloat.ps1 windows-11-24h2-debloat c:/output
```

### GitHub Actions
Workflow `build-debloat.yml` sẽ tự động chạy hàng tháng (ngày 18) hoặc có thể trigger thủ công.

## So sánh với script gốc

| Tính năng | Script gốc | Script debloat |
|-----------|------------|----------------|
| Bloatware | Có đầy đủ | **Loại bỏ hoàn toàn** |
| Kích thước ISO | ~5GB | **~2.5-3GB** |
| Apps tích hợp | ~40+ apps | **3 apps core** |
| Workflow | build.yml | build-debloat.yml |
| Output | Regular ISO | **Ultra-Lite ISO** |

## Lưu ý

- Script này **KHÔNG ảnh hưởng** đến dự án gốc
- Tất cả files test nằm trong thư mục `debloat-test/`
- Workflow riêng biệt với workflow chính
- Vẫn sử dụng các function từ script gốc (import) 