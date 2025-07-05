# Windows ISO Debloater

Thư mục này chứa các script để debloat Windows ISO được tạo từ UUP dump build workflow.

## Mục đích

- Tự động lấy ISO từ artifact của workflow build.yml
- Áp dụng công thức debloat từ [Windows-ISO-Debloater](https://github.com/itsNileshHere/Windows-ISO-Debloater)
- Tạo ra Windows ISO sạch, nhẹ hơn
- Hoạt động hoàn toàn tự động không cần tương tác

## Cách sử dụng

### 🚀 **Tự động (GitHub Actions)**

#### Workflow tự động sau build:
- Workflow `debloat.yml` sẽ tự động chạy sau khi `build.yml` hoàn thành
- Tạo ISO debloat và upload làm artifact mới

#### Workflow thủ công với tùy chọn:
1. Vào **Actions** → **Debloat Windows ISO** → **Run workflow**
2. Chọn các tùy chọn:
   - **Target artifact**: Tên artifact cụ thể (để trống = artifact mới nhất)
   - **ISO path**: Đường dẫn trực tiếp đến ISO (nếu không dùng artifacts)
   - **Windows edition**: Edition Windows cần debloat
   - **Appx Remove**: Xóa Microsoft Store apps
   - **OneDrive Remove**: Xóa OneDrive
   - **Edge Remove**: Xóa Microsoft Edge
   - **TPM Bypass**: Bỏ qua kiểm tra TPM

### 💻 **Thủ công (Local)**

```powershell
# Chế độ tương tác
cd debloat
.\debloat-iso.ps1

# Chế độ tự động (tự động phát hiện ISO)
.\debloat-iso.ps1 -noPrompt

# Chế độ tự động với tham số cụ thể
.\debloat-iso.ps1 -noPrompt -isoPath "path\to\windows.iso" -winEdition "Windows 11 Pro" -outputISO "Win11Debloat"
```

## Tham số

- `-noPrompt`: Chạy không cần tương tác (yêu cầu các tham số khác)
- `-isoPath`: Đường dẫn đến file ISO
- `-winEdition`: Tên edition Windows (VD: "Windows 11 Pro")
- `-outputISO`: Tên file ISO đầu ra (không có extension)

## Tùy chọn debloat

- `-AppxRemove`: Xóa Microsoft Store apps
- `-CapabilitiesRemove`: Xóa Windows features không cần thiết
- `-OnedriveRemove`: Xóa OneDrive hoàn toàn
- `-EDGERemove`: Xóa Microsoft Edge
- `-TPMBypass`: Bỏ qua kiểm tra TPM
- `-UserFoldersEnable`: Bật user folders trong Explorer
- `-ESDConvert`: Nén ISO bằng ESD compression

## ✨ **Tính năng**

- ✅ **Tự động phát hiện ISO** trong thư mục hiện tại
- ✅ **Tự động phát hiện Windows edition** từ ISO
- ✅ **Tự động tạo tên output** từ tên ISO gốc
- ✅ **Workflow GitHub Actions** với tùy chọn linh hoạt
- ✅ **Chạy tự động sau build** hoặc thủ công
- ✅ **Hỗ trợ cả artifacts và ISO trực tiếp**
- ✅ **Báo cáo dung lượng tiết kiệm** sau khi debloat

## 📋 **Workflow Files**

- **`.github/workflows/debloat.yml`** - Workflow chính (tự động sau build)

## ⚠️ **Lưu ý**

- Script này độc lập với code build UUP dump gốc
- Sử dụng oscdimg.exe để tạo ISO bootable
- Backup dữ liệu quan trọng trước khi sử dụng
- Cần quyền Administrator để chạy script
- Workflow tự động chạy sau khi build.yml hoàn thành

## 🔧 **Files**

- **`debloat-iso.ps1`** - Script debloat chính
- **`README.md`** - Hướng dẫn sử dụng 