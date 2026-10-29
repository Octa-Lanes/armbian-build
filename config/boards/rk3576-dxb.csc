# Rockchip RK3576 SoC octa core, Liontron DEC-3576 ("RK3576 DXB V10") 2*GBe eMMC USB3 PCIe2 4G-mPCIe 2*CAN-FD WIFI
BOARD_NAME="Liontron DEC-3576 (DXB)"
BOARDFAMILY="rk35xx"
# Interim: the radxa-cm4-io U-Boot is what DXB units boot today; a DXB U-Boot target replaces it (porting plan, Phase 3)
BOOTCONFIG="radxa-cm4-io-rk3576_defconfig"
KERNEL_TARGET="vendor"
FULL_DESKTOP="yes"
BOOT_LOGO="desktop"
BOOT_FDT_FILE="rockchip/rk3576-dxb.dtb"
BOOT_SCENARIO="spl-blobs"
IMAGE_PARTITION_TABLE="gpt"
BOARD_MAINTAINER=""

# AIC8800D80 is on SDIO: the in-tree aic8800_sdio driver with firmware from armbian-firmware,
# so no radxa-aic8800 (USB dkms) extension here.

# The family boot script puts "console=both" on ttyS2, which is the Bluetooth UART on this board.
# Use the display plus the FIQ debugger on UART0 (ttyFIQ0) instead.
function post_family_tweaks__rk3576-dxb_console() {
	local env_file="$SDCARD/boot/armbianEnv.txt"
	[[ -f "$env_file" ]] || return 0
	display_alert "$BOARD" "Serial console on ttyFIQ0 (ttyS2 is the Bluetooth UART)" "info"

	if grep -q '^console=' "$env_file"; then
		sed -i 's/^console=.*/console=display/' "$env_file"
	else
		echo "console=display" >> "$env_file"
	fi
	if grep -q '^extraargs=' "$env_file"; then
		sed -i 's/^extraargs=\(.*\)$/extraargs=\1 console=ttyFIQ0,1500000/' "$env_file"
	else
		echo "extraargs=console=ttyFIQ0,1500000" >> "$env_file"
	fi

	return 0
}

function post_family_tweaks__rk3576-dxb_naming_audios() {
	display_alert "$BOARD" "Renaming rk3576-dxb audios" "info"

	mkdir -p "$SDCARD/etc/udev/rules.d/"
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-hdmi-sound", ENV{SOUND_DESCRIPTION}="HDMI Audio"' > "$SDCARD/etc/udev/rules.d/90-naming-audios.rules"
	echo 'SUBSYSTEM=="sound", ENV{ID_PATH}=="platform-es8388-sound", ENV{SOUND_DESCRIPTION}="ES8388 Audio"' >> "$SDCARD/etc/udev/rules.d/90-naming-audios.rules"

	return 0
}
