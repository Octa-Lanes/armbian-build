#!/bin/bash
# ───────────────────────────────────────────────
# Purpose: Expand userdata partition, extract /user-data, update fstab, then reboot
# ───────────────────────────────────────────────
set -e

echo "🧠 Starting pre-extract setup..."

# 1. Install required packages
echo "📦 Installing required packages..."
sudo apt update -y
sudo apt install -y cloud-guest-utils vim modemmanager

# 2. Detect root partition and parent device correctly
echo "🔍 Detecting root device..."
ROOT_PART=$(findmnt -n -o SOURCE /)
echo "→ Root partition: $ROOT_PART"

# Get parent block device name (e.g. mmcblk1, sda, nvme0n1)
ROOT_BASE=$(lsblk -no pkname "$ROOT_PART" | head -n1)
ROOT_DEV="/dev/$ROOT_BASE"
echo "→ Root device detected: $ROOT_DEV"

# 3. Determine correct partition 4 path (handles mmcblk, nvme, sd)
if [[ "$ROOT_BASE" == mmcblk* || "$ROOT_BASE" == nvme* ]]; then
    PART4="${ROOT_DEV}p4"
else
    PART4="${ROOT_DEV}4"
fi
echo "→ Target partition: $PART4"

# 4. Grow partition 4 and resize filesystem
echo "📈 Growing and resizing $PART4..."
if sudo growpart "$ROOT_DEV" 4; then
    sudo resize2fs "$PART4"
    sync
else
    echo "⚠️ growpart failed (maybe already full size or invalid partition)"
fi

# 5. Extract user-data archive
if [ -f /user-data/user-data.tar.gz ]; then
    echo "📦 Extracting /user-data/user-data.tar.gz..."
    sudo tar -xvzf /user-data/user-data.tar.gz
else
    echo "⚠️ /user-data/user-data.tar.gz not found, skipping extraction."
fi

# 6. Write /etc/fstab dynamically based on detected device
echo "🧾 Writing /etc/fstab..."
sudo bash -c "cat <<EOF > /etc/fstab
# Do not direct edit this file, this file was generated from run-this-before-extract-user-data.sh
${ROOT_DEV}p3 / ext4 defaults,noatime,commit=120,errors=remount-ro 0 1
${ROOT_DEV}p1 /boot ext4 defaults,ro 0 2
${PART4} /user-data ext4 defaults,noatime,commit=120,errors=remount-ro 0 2
/user-data/root /root none bind 0 0
/user-data/home /home none bind 0 0
tmpfs /tmp tmpfs defaults,nosuid 0 0
EOF"

# 7. Self-remove
SCRIPT_PATH="$(realpath "$0")"
echo "🧹 Removing script: $SCRIPT_PATH"
sudo rm -f "$SCRIPT_PATH"

# 8. Reboot
echo "🔁 Rebooting system in 5 seconds..."
sleep 5
sudo reboot
