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

# 1. Tạo các thư mục làm việc
echo ">>> 1. Tạo thư mục làm việc"
mkdir -p iso_extracted wim_mount

# 2. Trích xuất ISO bằng mount method (hiệu quả hơn cho ISO lớn)
echo ">>> 2. Trích xuất nội dung ISO bằng mount method"
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
IMAGE_COUNT=$(wimlib-imagex info "$WIM_FILE" | grep -c "Image Index")
echo ">>> Tìm thấy $IMAGE_COUNT phiên bản Windows trong WIM."

# Kiểm tra thông tin WIM file
echo ">>> Thông tin WIM file:"
wimlib-imagex info "$WIM_FILE"

for (( i=1; i<=IMAGE_COUNT; i++ )); do
    IMAGE_NAME=$(wimlib-imagex info "$WIM_FILE" $i | grep "Name:" | sed 's/Name: *//')
    echo "--- Đang xử lý Image $i: $IMAGE_NAME ---"
    
    # Đảm bảo thư mục mount rỗng và có quyền ghi
    echo ">>> Dọn dẹp thư mục mount..."
    rm -rf wim_mount/*
    chmod 755 wim_mount
    
    echo ">>> Mounting WIM image $i..."
    if ! wimlib-imagex mountrw "$WIM_FILE" "$i" wim_mount; then
        echo "Lỗi: Không thể mount WIM image $i"
        echo "Nội dung thư mục wim_mount:"
        ls -la wim_mount
        echo "Kiểm tra quyền thư mục:"
        ls -ld wim_mount
        echo "Kiểm tra dung lượng disk:"
        df -h .
        exit 1
    fi
    
    echo ">>> WIM image mounted successfully"
    echo ">>> Nội dung thư mục mount:"
    ls -la wim_mount/
    
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
    
    echo ">>> Committing changes..."
    if ! wimlib-imagex unmount --commit wim_mount; then
        echo "Lỗi: Không thể commit changes cho WIM image $i"
        echo "Thử discard changes..."
        wimlib-imagex unmount --discard wim_mount || true
        exit 1
    fi
    
    echo "--- Hoàn tất xử lý Image $i ---"
done

# 5. Xây dựng lại file ISO bootable
echo ">>> 5. Xây dựng lại file ISO bootable mới..."
dd if="$ISO_PATH" bs=1 count=432 of=iso_extracted/boot/etfsboot.com

# Dùng biến DEBLOATED_ISO_NAME đã được xác định ở trên
xorriso -as mkisofs -r -V "Win_Debloated" \
    -o "$DEBLOATED_ISO_NAME" \
    -b boot/etfsboot.com -no-emul-boot \
    -boot-load-size 8 \
    -c boot/boot.cat \
    -iso-level 4 -J -l \
    -eltorito-alt-boot -b efi/microsoft/boot/efisys.bin -no-emul-boot \
    -append_partition 2 0xef iso_extracted/efi/microsoft/boot/efisys.bin \
    -partition_cyl_align on \
    iso_extracted/

# 6. Dọn dẹp
echo ">>> 6. Dọn dẹp thư mục tạm"
rm -rf iso_extracted wim_mount

echo ">>> HOÀN TẤT! File ISO đã debloat được tạo tại: $DEBLOATED_ISO_NAME" 