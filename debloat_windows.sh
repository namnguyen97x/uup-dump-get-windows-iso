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

# 2. Trích xuất ISO bằng xorriso (thay vì 7-Zip)
echo ">>> 2. Trích xuất nội dung ISO bằng xorriso"
xorriso -osirrox on -indev "$ISO_PATH" -extract / iso_extracted/

# Kiểm tra xem extraction có thành công không
if [ ! -d "iso_extracted/sources" ]; then
    echo "Lỗi: Không thể trích xuất thư mục sources từ ISO"
    exit 1
fi

echo ">>> Kiểm tra nội dung thư mục sources:"
ls -la iso_extracted/sources/

# 3. Tìm và xử lý install.wim hoặc install.esd
WIM_FILE=""
ESD_FILE=""

if [ -f "iso_extracted/sources/install.wim" ]; then
    WIM_FILE="iso_extracted/sources/install.wim"
    echo ">>> Tìm thấy install.wim"
elif [ -f "iso_extracted/sources/install.esd" ]; then
    ESD_FILE="iso_extracted/sources/install.esd"
    echo ">>> Tìm thấy install.esd, chuyển đổi sang install.wim"
    
    # Chuyển đổi ESD sang WIM
    wimlib-imagex export "$ESD_FILE" 1 iso_extracted/sources/install.wim
    WIM_FILE="iso_extracted/sources/install.wim"
    echo ">>> Chuyển đổi ESD sang WIM thành công"
else
    echo "Lỗi: Không tìm thấy install.wim hoặc install.esd trong sources/"
    echo "Nội dung thư mục sources:"
    ls -la iso_extracted/sources/
    exit 1
fi

# 4. Lặp qua từng phiên bản Windows (Image) trong file WIM
IMAGE_COUNT=$(wimlib-imagex info "$WIM_FILE" | grep -c "Image Index")
echo ">>> Tìm thấy $IMAGE_COUNT phiên bản Windows trong WIM."

for (( i=1; i<=IMAGE_COUNT; i++ )); do
    IMAGE_NAME=$(wimlib-imagex info "$WIM_FILE" $i | grep "Name:" | sed 's/Name: *//')
    echo "--- Đang xử lý Image $i: $IMAGE_NAME ---"
    wimlib-imagex mountrw "$WIM_FILE" "$i" wim_mount
    echo "    Removing AppX packages..."
    for app in "${APPS_TO_REMOVE[@]}"; do
        find wim_mount/Program\ Files/WindowsApps -maxdepth 1 -type d -name "*${app}*" -exec echo "      Removing {}" \; -exec rm -rf {} \; || true
        find wim_mount/Windows/SystemApps -maxdepth 1 -type d -name "*${app}*" -exec echo "      Removing {}" \; -exec rm -rf {} \; || true
    done
    rm -rf wim_mount/\$Recycle.Bin
    wimlib-imagex unmount --commit wim_mount
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