# Windows ISO Debloat Workflow

Dự án này cung cấp GitHub Actions workflow và PowerShell scripts để tự động debloat Windows ISO, dựa trên repository [Windows-ISO-Debloater](https://github.com/itsNileshHere/Windows-ISO-Debloater).

## Tính năng chính

### 🔧 GitHub Actions Workflow (`.github/workflows/debloat.yml`)

- **Tự động phát hiện artifact**: Tự động tìm và tải artifact mới nhất từ các workflow runs
- **Tải ISO linh hoạt**: Từ artifact, URL, hoặc auto-detect
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

#### 3. `scripts/artifact-manager.ps1` (New!)
- Quản lý artifacts một cách linh hoạt
- Tự động phát hiện repository và token
- Tải artifact từ workflow runs cụ thể
- Hỗ trợ pattern matching cho artifact names

## Cách sử dụng

### 1. Chạy Workflow thủ công

1. Vào tab **Actions** trên GitHub repository
2. Chọn workflow **Debloat Windows ISO**
3. Click **Run workflow**
4. Chọn nguồn ISO:
   - **auto-detect**: Tự động tìm artifact mới nhất (mặc định)
   - **artifact**: Tải từ artifact cụ thể
   - **url**: Tải từ URL tùy chỉnh
5. Cấu hình thêm:
   - **Artifact Pattern**: Pattern để match artifact names (mặc định: `Windows-*`)
   - **Workflow Run ID**: ID của workflow run cụ thể (tùy chọn)
   - **Artifact Name**: Tên artifact cụ thể (nếu chọn source = artifact)
6. Click **Run workflow**

### 2. Chạy tự động theo lịch

Workflow được cấu hình chạy tự động vào Chủ nhật hàng tuần lúc 2:00 AM UTC với chế độ auto-detect.

### 3. Sử dụng Artifact Manager Script

```powershell
# Liệt kê tất cả artifacts có sẵn
.\scripts\artifact-manager.ps1 -ListOnly -Pattern "Windows-*"

# Tải artifact mới nhất
.\scripts\artifact-manager.ps1 -DownloadLatest -Pattern "Windows-*" -OutputPath "./downloads"

# Tải artifact cụ thể từ workflow run
.\scripts\artifact-manager.ps1 -WorkflowRunId "123456789" -ArtifactName "Windows-11-23H2" -OutputPath "./downloads"

# Chế độ interactive (chọn artifact từ danh sách)
.\scripts\artifact-manager.ps1 -Pattern "Windows-*" -OutputPath "./downloads"
```

### 4. Chạy script debloat locally

```powershell
# Cài đặt script
.\scripts\simple-debloat.ps1 -InputPath ".\iso-input" -OutputPath ".\iso-output" -Verbose

# Với các tùy chọn khác
.\scripts\simple-debloat.ps1 -InputPath ".\iso-input" -OutputPath ".\iso-output" -WindowsVersion "11" -Verbose
```

## Tính năng động lấy artifact

### 🔍 Auto-Detection
Workflow tự động:
- Quét các workflow runs gần đây (tối đa 10 runs)
- Tìm artifacts phù hợp với pattern
- Chọn artifact mới nhất để tải
- Hiển thị thông tin chi tiết về artifact được chọn

### 📋 Artifact Pattern Matching
- Hỗ trợ wildcard patterns (ví dụ: `Windows-*`, `*11*`, `*23H2*`)
- Có thể tùy chỉnh pattern qua input parameter
- Tự động lọc artifacts không phù hợp

### 🔗 Cross-Workflow Artifact Access
- Tải artifacts từ bất kỳ workflow run nào
- Hỗ trợ workflow run ID cụ thể
- Tương thích với build.yml và các workflow khác

### 📊 Artifact Information
Workflow cung cấp thông tin chi tiết:
- Tên artifact và workflow source
- Kích thước file
- Thời gian tạo
- Workflow run ID
- Trạng thái download

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

1. **Workflow fails to detect artifacts**
   - Kiểm tra pattern có đúng không
   - Đảm bảo có workflow runs thành công
   - Kiểm tra quyền truy cập repository

2. **Artifact download fails**
   - Kiểm tra workflow run ID có đúng không
   - Đảm bảo artifact name chính xác
   - Kiểm tra GitHub token permissions

3. **Script fails to run**
   - Kiểm tra quyền admin (nếu chạy locally)
   - Kiểm tra PowerShell execution policy
   - Đảm bảo GitHub CLI đã cài đặt

4. **ISO không boot được**
   - Kiểm tra file ISO có bị corrupt không
   - Thử burn lại với công cụ khác

### Log Files
- `debloat.log` - General log
- `debloat-errors.log` - Error log
- GitHub Actions logs trong tab Actions

## Tùy chỉnh

### Thay đổi Artifact Pattern
```yaml
# Trong workflow
artifact_pattern: "Windows-11-*"  # Chỉ lấy Windows 11 artifacts
artifact_pattern: "*23H2*"        # Chỉ lấy artifacts có 23H2
artifact_pattern: "*"             # Lấy tất cả artifacts
```

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
- GitHub token cần có quyền truy cập repository và workflows

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