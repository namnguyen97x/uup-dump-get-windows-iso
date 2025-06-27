#!/bin/bash
set -e # Thoát ngay khi có lỗi

# --- Tham số đầu vào ---
ISO_PATH="$1"
OUTPUT_BASENAME="$2"

# Kiểm tra tham số bắt buộc
if [ -z "$ISO_PATH" ]; then
    echo "Lỗi: Vui lòng cung cấp đường dẫn đến file ISO."
    exit 1
fi

# --- Xác định tên file đầu ra ---
if [ -n "$OUTPUT_BASENAME" ]; then
    # Sử dụng tên cơ sở được cung cấp
    DEBLOATED_ISO_NAME="debloated-${OUTPUT_BASENAME}.iso"
else
    # Nếu không có, tự tạo tên từ file ISO đầu vào (loại bỏ đuôi .iso)
    ISO_FILENAME=$(basename "$ISO_PATH")
    DEBLOATED_ISO_NAME="debloated-${ISO_FILENAME%.*}.iso"
fi

echo ">>> Tên file ISO đầu ra sẽ là: $DEBLOATED_ISO_NAME"

# --- DANH SÁCH CÁC APPX CẦN GỠ BỎ ---
APPS_TO_REMOVE=(
    "Microsoft.549981C3F5F10"             # Cortana
    "Microsoft.BingNews"                 # Tin tức
    "Microsoft.BingWeather"              # Thời tiết
    "Microsoft.GetHelp"                  # Get Help
    "Microsoft.Getstarted"               # Get Started / Tips
    "Microsoft.HEIFImageExtension"
    "Microsoft.HEVCVideoExtension"
    "Microsoft.People"                   # People
    "Microsoft.Print3D"                  # Print 3D
    "Microsoft.SkypeApp"                 # Skype
    "Microsoft.ScreenSketch"             # Snip & Sketch
    "Microsoft.StorePurchaseApp"
    "Microsoft.Todos"                    # To Do
    "Microsoft.Wallet"
    "Microsoft.WebpImageExtension"
    "Microsoft.WindowsAlarms"            # Alarms & Clock
    "Microsoft.WindowsCamera"            # Camera
    "Microsoft.WindowsCommunicationsApps" # Mail and Calendar
    "Microsoft.WindowsFeedbackHub"       # Feedback Hub
    "Microsoft.WindowsMaps"              # Maps
    "Microsoft.WindowsSoundRecorder"     # Voice Recorder
    "Microsoft.WindowsStore"             # Microsoft Store (Cẩn thận khi gỡ!)
    "Microsoft.YourPhone"                # Phone Link
    "Microsoft.ZuneMusic"                # Groove Music
    "Microsoft.ZuneVideo"                # Movies & TV
    "Microsoft.XboxApp"
    "Microsoft.XboxGameOverlay"
    "Microsoft.XboxGamingOverlay"
    "Microsoft.XboxIdentityProvider"
    "Microsoft.XboxSpeechToTextOverlay"
)

echo ">>> Bắt đầu quá trình debloat cho $ISO_PATH"

# Kiểm tra và cài đặt các package cần thiết
echo ">>> Kiểm tra các package cần thiết..."

# Kiểm tra wimlib-tools
if ! command -v wimlib-imagex &> /dev/null; then
    echo "Cài đặt wimlib-tools..."
    sudo apt-get update
    sudo apt-get install -y wimtools
else
    echo "wimlib-tools đã được cài đặt"
    echo "Version: $(wimlib-imagex --version)"
fi

# Kiểm tra xorriso
if ! command -v xorriso &> /dev/null; then
    echo "Cài đặt xorriso..."
    sudo apt-get install -y xorriso
else
    echo "xorriso đã được cài đặt"
fi

# Kiểm tra 7zip
if ! command -v 7z &> /dev/null; then
    echo "Cài đặt p7zip-full..."
    sudo apt-get install -y p7zip-full
else
    echo "7zip đã được cài đặt"
fi

# --- LOGGING & RESOURCE CHECK FUNCTIONS ---
log_resource_usage() {
  echo "--- Disk usage ---"
  df -h
  echo "--- RAM usage ---"
  free -h || true
  echo "--- Largest files/folders in workspace ---"
  du -sh * 2>/dev/null | sort -hr | head -20
}

# --- Start script ---
echo ">>> Bắt đầu debloat: $ISO_PATH"
log_resource_usage

# 1. Tạo các thư mục làm việc
echo ">>> 1. Tạo thư mục làm việc"
log_resource_usage
mkdir -p iso_extracted wim_mount

# 2. Trích xuất ISO bằng mount method (hiệu quả hơn cho ISO lớn)
echo ">>> 2. Trích xuất nội dung ISO bằng mount method"
log_resource_usage
echo ">>> Mounting ISO file..."

# Tạo thư mục mount
sudo mkdir -p /mnt/iso

# Mount ISO file
if sudo mount -o loop "$ISO_PATH" /mnt/iso; then
    echo ">>> ISO mounted successfully, copying files..."
    # Copy toàn bộ nội dung từ mount point
    cp -r /mnt/iso/* iso_extracted/
    sudo umount /mnt/iso
    echo ">>> Files copied successfully"
else
    echo ">>> Mount failed, trying 7z as fallback..."
    # Fallback to 7z nếu mount thất bại
    if ! 7z x "$ISO_PATH" -oiso_extracted -y; then
        echo "Lỗi: Tất cả các phương pháp trích xuất ISO đều thất bại"
        exit 1
    fi
fi

# Kiểm tra xem extraction có thành công không
echo ">>> Kiểm tra cấu trúc thư mục sau khi trích xuất:"
ls -la iso_extracted/
log_resource_usage

# Tìm thư mục sources trong các vị trí có thể
SOURCES_DIR=""
if [ -d "iso_extracted/sources" ]; then
    SOURCES_DIR="iso_extracted/sources"
elif [ -d "iso_extracted/CPRA_X64FRE_EN-US_DV9/sources" ]; then
    SOURCES_DIR="iso_extracted/CPRA_X64FRE_EN-US_DV9/sources"
elif [ -d "iso_extracted/*/sources" ]; then
    SOURCES_DIR=$(find iso_extracted -name "sources" -type d | head -1)
else
    echo "Lỗi: Không thể tìm thấy thư mục sources"
    echo "Tìm kiếm thư mục sources trong toàn bộ iso_extracted:"
    find iso_extracted -name "sources" -type d
    exit 1
fi

echo ">>> Tìm thấy thư mục sources tại: $SOURCES_DIR"
echo ">>> Nội dung thư mục sources:"
ls -la "$SOURCES_DIR"

# 3. Tìm và xử lý install.wim hoặc install.esd
echo ">>> 3. Tìm và xử lý install.wim hoặc install.esd"
log_resource_usage
WIM_FILE=""
ESD_FILE=""

if [ -f "$SOURCES_DIR/install.wim" ]; then
    WIM_FILE="$SOURCES_DIR/install.wim"
    echo ">>> Tìm thấy install.wim"
elif [ -f "$SOURCES_DIR/install.esd" ]; then
    ESD_FILE="$SOURCES_DIR/install.esd"
    echo ">>> Tìm thấy install.esd, chuyển đổi sang install.wim"
    
    # Chuyển đổi ESD sang WIM
    wimlib-imagex export "$ESD_FILE" 1 "$SOURCES_DIR/install.wim"
    WIM_FILE="$SOURCES_DIR/install.wim"
    echo ">>> Chuyển đổi ESD sang WIM thành công"
else
    echo "Lỗi: Không tìm thấy install.wim hoặc install.esd trong $SOURCES_DIR"
    echo "Nội dung thư mục sources:"
    ls -la "$SOURCES_DIR"
    exit 1
fi

# 4. Lặp qua từng phiên bản Windows (Image) trong file WIM
echo ">>> 4. Xử lý WIM file..."
log_resource_usage
echo ">>> Kiểm tra WIM file size:"
ls -lh "$WIM_FILE"

echo ">>> Lấy thông tin WIM file:"
WIM_INFO=$(wimlib-imagex info "$WIM_FILE")
echo "$WIM_INFO"

echo ">>> Đếm số lượng images:"
IMAGE_COUNT=$(echo "$WIM_INFO" | grep -c "^Index:" || echo "0")
echo ">>> Tìm thấy $IMAGE_COUNT phiên bản Windows trong WIM."

if [ "$IMAGE_COUNT" -eq 0 ]; then
    echo "Lỗi: Không tìm thấy images trong WIM file"
    echo "Thông tin WIM chi tiết:"
    wimlib-imagex info "$WIM_FILE" | head -20
    exit 1
fi

for (( i=1; i<=IMAGE_COUNT; i++ )); do
    echo ">>> Xử lý Image $i..."
    log_resource_usage
    IMAGE_NAME=$(wimlib-imagex info "$WIM_FILE" $i | grep "Name:" | sed 's/Name: *//')
    echo "--- Đang xử lý Image $i: $IMAGE_NAME ---"
    
    # Đảm bảo thư mục mount rỗng
    echo ">>> Dọn dẹp thư mục mount..."
    rm -rf wim_mount/*
    mkdir -p wim_mount
    
    echo ">>> Extracting WIM image $i..."
    log_resource_usage
    if ! wimlib-imagex extract "$WIM_FILE" $i --dest-dir=wim_mount; then
        echo "Lỗi: Không thể extract WIM image $i"
        exit 1
    fi
    
    echo ">>> Nội dung thư mục mount:"
    ls -la wim_mount/
    log_resource_usage
    
    echo "    Removing AppX packages..."
    for app in "${APPS_TO_REMOVE[@]}"; do
        echo "      Checking for app: $app"
        if [ -d "wim_mount/Program Files/WindowsApps" ]; then
            find wim_mount/Program\ Files/WindowsApps -maxdepth 1 -type d -name "*${app}*" -exec echo "        Removing {}" \; -exec rm -rf {} \; || true
        fi
        if [ -d "wim_mount/Windows/SystemApps" ]; then
            find wim_mount/Windows/SystemApps -maxdepth 1 -type d -name "*${app}*" -exec echo "        Removing {}" \; -exec rm -rf {} \; || true
        fi
    done
    
    echo ">>> Removing Recycle.Bin..."
    rm -rf wim_mount/\$Recycle.Bin || true
    
    echo ">>> Repacking WIM image $i..."
    log_resource_usage
    # Tạo file WIM mới ở thư mục hiện tại bằng lệnh capture
    if ! wimlib-imagex capture wim_mount "./install.debloated.wim" "$IMAGE_NAME"; then
        echo "Lỗi: Không thể tạo file WIM mới cho image $i"
        exit 1
    fi
    
    echo "--- Hoàn tất xử lý Image $i ---"
    log_resource_usage
done

echo ">>> Đã tạo file ./install.debloated.wim. Khi build lại ISO, hãy dùng file này thay cho file install.wim gốc trong sources."
log_resource_usage

# 5. Xây dựng lại file ISO bootable
echo ">>> 5. Xây dựng lại file ISO bootable mới..."
log_resource_usage

# Cài đặt genisoimage nếu chưa có
if ! command -v genisoimage &> /dev/null; then
  echo ">>> Cài đặt genisoimage..."
  sudo apt-get update
  sudo apt-get install -y genisoimage
fi

# Trước khi tạo lại ISO bootable mới, cấp quyền ghi cho thư mục iso_extracted
echo ">>> Cấp quyền cho thư mục iso_extracted..."
sudo chown -R $(whoami) iso_extracted

# Đảm bảo tất cả files có quyền đọc/ghi
echo ">>> Cấp quyền đọc/ghi cho tất cả files..."
chmod -R 755 iso_extracted

# Đảm bảo file boot có quyền đọc/ghi đặc biệt
echo ">>> Cấp quyền đặc biệt cho file boot..."
chmod 644 iso_extracted/boot/etfsboot.com
chmod 644 iso_extracted/boot/bootfix.bin 2>/dev/null || true

# Kiểm tra file UEFI boot
if [ -f iso_extracted/efi/microsoft/boot/efisys.bin ]; then
  echo ">>> Tạo ISO hybrid (UEFI + BIOS) với UDF bằng genisoimage..."
  genisoimage -udf -iso-level 3 -allow-limited-size -o "$DEBLOATED_ISO_NAME" \
    -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table \
    -eltorito-alt-boot -e efi/microsoft/boot/efisys.bin -no-emul-boot \
    iso_extracted
else
  echo ">>> Tạo ISO BIOS-only với UDF bằng genisoimage..."
  genisoimage -udf -iso-level 3 -allow-limited-size -o "$DEBLOATED_ISO_NAME" \
    -b boot/etfsboot.com -no-emul-boot -boot-load-size 8 -boot-info-table \
    iso_extracted
fi

# 6. Dọn dẹp
echo ">>> 6. Dọn dẹp thư mục tạm"
log_resource_usage
rm -rf iso_extracted wim_mount

log_resource_usage
echo ">>> HOÀN TẤT! File ISO đã debloat được tạo tại: $DEBLOATED_ISO_NAME" 