# Windows ISO Debloat Workflow

Dự án này cung cấp GitHub Actions workflow và PowerShell scripts để tự động debloat Windows ISO, dựa trên repository [Windows-ISO-Debloater](https://github.com/itsNileshHere/Windows-ISO-Debloater).

## Tính năng chính

### 🔧 GitHub Actions Workflow (`.github/workflows/debloat.yml`)

- **Tự động tải ISO**: Từ artifact của build.yml hoặc từ URL
- **Debloat tự động**: Sử dụng PowerShell scripts
- **Unattended setup**: Tạo cấu hình cài đặt tự động
- **OOBE bypass**: Bỏ qua các bước thiết lập ban đầu
- **Artifact upload**: Tải lên các file đã được debloat

### 📜 PowerShell Scripts

#### 1. `scripts/debloat-windows-iso.ps1` (Advanced)
- Mount/unmount Windows ISO
- Remove Windows components bằng DISM
- Remove bloatware apps
- Disable telemetry
- Tạo unattended setup

#### 2. `scripts/simple-debloat.ps1` (Recommended)
- Không cần mount ISO
- Tạo các file cấu hình
- Tạo setup script post-installation
- An toàn và ổn định hơn

## Cách sử dụng

### 1. Chạy Workflow thủ công

1. Vào tab **Actions** trên GitHub repository
2. Chọn workflow **Debloat Windows ISO**
3. Click **Run workflow**
4. Chọn nguồn ISO:
   - **artifact**: Tải từ artifact của build.yml
   - **url**: Tải từ URL tùy chỉnh
5. Nhập tên artifact hoặc URL nếu cần
6. Click **Run workflow**

### 2. Chạy tự động theo lịch

Workflow được cấu hình chạy tự động vào Chủ nhật hàng tuần lúc 2:00 AM UTC.

### 3. Chạy script PowerShell locally

```powershell
# Cài đặt script
.\scripts\simple-debloat.ps1 -InputPath ".\iso-input" -OutputPath ".\iso-output" -Verbose

# Với các tùy chọn khác
.\scripts\simple-debloat.ps1 -InputPath ".\iso-input" -OutputPath ".\iso-output" -WindowsVersion "11" -Verbose
```

## Output Files

Sau khi chạy workflow, bạn sẽ nhận được các file sau:

### 📁 ISO Files
- `debloated-*.iso` - Windows ISO đã được tối ưu

### ⚙️ Configuration Files
- `unattend.xml` - Cấu hình cài đặt tự động
- `debloat-settings.reg` - Registry settings để disable telemetry
- `setup-debloat.ps1` - Script chạy sau khi cài đặt

### 📋 Documentation
- `README.md` - Hướng dẫn chi tiết
- `*.json` - Thông tin về quá trình debloat
- `*.log` - Log files

## Cách sử dụng ISO đã debloat

### Phương pháp 1: Burn ISO to USB/DVD
1. Tải xuống file `debloated-*.iso`
2. Sử dụng Rufus, Windows Media Creation Tool, hoặc công cụ tương tự
3. Burn ISO vào USB hoặc DVD
4. Boot từ media
5. Cài đặt sẽ tự động hoàn thành mà không cần can thiệp

### Phương pháp 2: Sử dụng Unattended Setup
1. Copy file `unattend.xml` vào thư mục gốc của media cài đặt
2. Boot từ media
3. Setup sẽ sử dụng cấu hình unattended

### Phương pháp 3: Post-Installation Debloat
1. Cài đặt Windows bình thường
2. Sau khi cài đặt, chạy file `debloat-settings.reg`
3. Chạy script `setup-debloat.ps1`
4. Restart máy tính

## Tính năng Debloat

### 🚫 Disabled Features
- **Telemetry**: Windows telemetry và tracking
- **Cortana**: Virtual assistant
- **Windows Update**: Automatic updates (có thể bật lại)
- **Windows Defender**: Built-in antivirus (có thể bật lại)
- **Bloatware Apps**: 3D Builder, Bing apps, Maps, etc.

### ⚡ Performance Optimizations
- Disable search suggestions
- Optimize taskbar
- Reduce background services
- Improve boot time

### 🔒 Privacy Settings
- Disable data collection
- Disable diagnostic services
- Disable advertising ID
- Disable location tracking

## Troubleshooting

### Lỗi thường gặp

1. **Workflow fails to download artifact**
   - Kiểm tra tên artifact có đúng không
   - Đảm bảo build.yml đã chạy thành công

2. **Script fails to run**
   - Kiểm tra quyền admin (nếu chạy locally)
   - Kiểm tra PowerShell execution policy

3. **ISO không boot được**
   - Kiểm tra file ISO có bị corrupt không
   - Thử burn lại với công cụ khác

### Log Files
- `debloat.log` - General log
- `debloat-errors.log` - Error log
- GitHub Actions logs trong tab Actions

## Tùy chỉnh

### Thêm/Remove Apps
Chỉnh sửa array `$appsToRemove` trong script để thêm/bớt apps cần remove.

### Thay đổi Registry Settings
Chỉnh sửa file `debloat-settings.reg` để thay đổi registry settings.

### Tùy chỉnh Unattended Setup
Chỉnh sửa file `unattend.xml` để thay đổi cấu hình cài đặt tự động.

## Bảo mật

⚠️ **Lưu ý quan trọng**:
- Script này disable một số tính năng bảo mật của Windows
- Chỉ sử dụng trên máy tính cá nhân hoặc môi trường test
- Có thể re-enable các tính năng bảo mật sau khi cài đặt

## Đóng góp

1. Fork repository
2. Tạo feature branch
3. Commit changes
4. Push to branch
5. Tạo Pull Request

## License

Dự án này dựa trên [Windows-ISO-Debloater](https://github.com/itsNileshHere/Windows-ISO-Debloater) và tuân theo license của dự án gốc.

## Support

Nếu gặp vấn đề, vui lòng:
1. Kiểm tra log files
2. Tạo issue trên GitHub
3. Cung cấp thông tin chi tiết về lỗi 