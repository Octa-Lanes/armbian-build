#!/bin/bash
# ───────────────────────────────────────────────
#  Octimus-I Setup Script for Ubuntu/Armbian
#  Installs core packages and services
# ───────────────────────────────────────────────
set -e
set -o pipefail

# ──── Color Definitions ────────────────────────────────
GREEN="\e[32m"
YELLOW="\e[33m"
RED="\e[31m"
RESET="\e[0m"

# ──── Helper Function ─────────────────────────────────
step()   { echo -e "${YELLOW}\n[STEP] $1${RESET}"; }
ok()     { echo -e "${GREEN}[OK] $1${RESET}"; }
warn()   { echo -e "${RED}[WARN] $1${RESET}"; }

echo "───────────────────────────────────────────────"
echo -e "  ${GREEN}Starting Octimus-I setup process...${RESET}"
echo "───────────────────────────────────────────────"
sleep 1

# ──── 1. Add HOPE-X APT Repository ─────────────────────
step "Adding HOPE-X APT repository..."
curl -fsSL -o /usr/share/keyrings/hopex.gpg https://hope-apt.8lanes.co/repo_signing.gpg
echo "deb [signed-by=/usr/share/keyrings/hopex.gpg] http://hope-apt.8lanes.co/ hopex main" \
  | tee /etc/apt/sources.list.d/hopex.list > /dev/null
ok "Repository added successfully."

# ──── 2. Update APT ────────────────────────────────────
step "Updating APT package lists..."
apt update -y
ok "APT updated."

# ──── 3. Install Kodmai Updater ────────────────────────
step "Installing kodmai-sw-updater..."
apt install -y kodmai-sw-updater
cp /user-data/machine-info.json /tmp/ 2>/dev/null || warn "machine-info.json not found."
sudo /usr/lib/kodmai-sw-updater/kodmai-sw-updater || warn "kodmai-sw-updater initialization failed."
ok "Kodmai Updater installed."

# ──── 4. Install Node.js (Manual Method) ──────
step "Installing Node.js (v18.20.8) manually..."
NODE_TAR="/user-data/node-v18.20.8-linux-arm64.tar.xz"
NODE_DIR="/user-data/node-v18.20.8-linux-arm64"
INSTALL_DIR="/usr/local/node-v18.20.8-linux-arm64"

if [ -f "$NODE_TAR" ]; then
  echo "📦 Extracting Node.js tarball..."
  tar -xJf "$NODE_TAR" -C /user-data/

  # Clean up existing installation if needed
  if [ -d "$INSTALL_DIR" ]; then
    echo "⚙️  Existing Node.js directory found, removing..."
    sudo rm -rf "$INSTALL_DIR"
  fi

  # Move and link
  echo "📂 Moving Node.js to /usr/local..."
  sudo mv "$NODE_DIR" /usr/local/
  sudo ln -sfn "$INSTALL_DIR" /usr/local/node

  # Add to PATH if not already there
  if ! grep -q "/usr/local/node/bin" ~/.bashrc; then
    echo "🛠️  Adding Node.js to PATH..."
    echo 'export PATH=$PATH:/usr/local/node/bin' >> ~/.bashrc
  fi

  # Ensure PATH is available for this script runtime
  export PATH=$PATH:/usr/local/node/bin

  # Create system-wide symlinks
  echo "🔗 Linking Node.js binaries..."
  sudo ln -sf /usr/local/node/bin/* /usr/local/bin/

  # Install global npm tools
  echo "🧰 Installing global npm packages (yarn, pm2)..."
  npm install -g yarn pm2

  # Verify installation
  echo "Versions:"
  node -v && npm -v && pm2 -v

  ok "Node.js installed successfully."
else
  warn "Node tarball not found — skipping Node.js installation."
fi

# ──── 5. Install Chromium + Unclutter (Kiosk Mode) ─────
step "Installing Chromium + Unclutter..."
apt install -y chromium unclutter
ok "Chromium and Unclutter installed."

# ──── 6. Install NGINX with all modules ────────────────
step "Installing NGINX and related modules..."
apt install -y nginx-full \
  libnginx-mod-http-perl libnginx-mod-http-geoip libnginx-mod-http-xslt-filter \
  libnginx-mod-mail libnginx-mod-stream-geoip libnginx-mod-nchan \
  libnginx-mod-http-image-filter libnginx-mod-http-geoip2 \
  libnginx-mod-http-cache-purge libnginx-mod-http-fancyindex \
  libnginx-mod-http-headers-more-filter libnginx-mod-http-uploadprogress
ok "NGINX installed."

# ──── 7. GPIO + GNOME Remote Desktop Dependencies ──────
step "Installing GPIO and remote desktop dependencies..."
apt install -y gpiod libcjson1 gnome-remote-desktop libfdk-aac2 libvncserver1
ok "Dependencies installed."

# ──── 8. Restore Machine Info + VNC Config ─────────────
step "Restoring machine info and VNC configuration..."
tar xzvf /user-data/gnome-remote-desktop-vnc-arm64.tar.gz -C / 2>/dev/null || warn "VNC tarball not found."
sleep 1
ok "VNC config restored."

# ──── 9. Reload GNOME Remote Desktop ───────────────────
step "Reloading GNOME Remote Desktop service..."
systemctl --user daemon-reload || true
systemctl --user restart gnome-remote-desktop.service || true
ok "GNOME Remote Desktop reloaded."

# ──── 10. System Setup and Service Startup ───────
step "Running final setup and starting services..."

# Chromium alias for kiosk compatibility
echo "🔗 Linking chromium → chromium-browser..."
sudo ln -sf /usr/bin/chromium /usr/bin/chromium-browser

# Clear old Chromium singleton locks
echo "🧹 Cleaning Chromium lock files..."
sudo -u sun108 rm -f /home/sun108/.config/chromium/Singleton*
sudo rm -rf ~/.cache/chromium

# Start PM2 service for sun108-api
if command -v pm2 >/dev/null 2>&1; then
  echo "🚀 Starting PM2 process for sun108-api..."
  pm2 start /home/sun108/sun108-api/server.js --name sun108-api || true
  pm2 save || true
  pm2 startup || true
  ok "PM2 service initialized."
else
  warn "pm2 not found — skipping sun108-api startup."
fi

# Restore and enable NGINX configuration
if [ -f /user-data/nginx-sun108.tgz ]; then
  echo "📦 Restoring nginx-sun108 configuration..."
  sudo tar xzf /user-data/nginx-sun108.tgz -C /
  sudo nginx -t && ok "NGINX configuration test passed."
else
  warn "nginx-sun108.tgz not found — skipping restore."
fi

ok "Final setup tasks completed."

# ──── Add file permission ────────────────
step "Add file permission..."
sudo chmod o+x /home/sun108
sudo chmod -R 755 /home/sun108/sun108-frontend/dist
sudo chmod -R 755 /home/sun108/sun108-so/dist
ok "Gives read + execute access to sun108-frontend/dist and sun108-so/dist"

step "Change journalctl to persistent mode and extend SystemMaxUse size..."
sudo sed -i 's/^Storage=.*/Storage=persistent/; s/^SystemMaxUse=.*/SystemMaxUse=500M/' /etc/systemd/journald.conf && sudo systemctl restart systemd-journald
ok "Journalctl is configued"

# ──── 11. Install Root & User Cron Jobs ─────────────────────────────
step "Installing default cron jobs for root and user..."

USER_NAME="sun108"
USER_CRON_TMP="/tmp/${USER_NAME}_cron_current"
ROOT_CRON_TMP="/tmp/root_cron_current"

echo "=== Installing DEFAULT ROOT and USER cron jobs ==="

#########################################################
# 1) ROOT CRONTAB
#########################################################

ROOT_JOBS="
0 0 * * * /home/$USER_NAME/sun108-ota-agent/ota-agent.sh
*/1 * * * * bash '/home/$USER_NAME/sun108-ota-agent/watchdog-cable.sh'
* * * * * bash '/home/$USER_NAME/sun108-ota-agent/watchdog-not-ready-state.sh'
*/8 * * * * bash '/home/$USER_NAME/sun108-ota-agent/watchdog.sh'
*/5 * * * * bash '/home/$USER_NAME/sun108-ota-agent/watchdog-module.sh'
*/5 * * * * bash '/home/$USER_NAME/sun108-ota-agent/watchdog-teamviewerd.sh'
*/1 * * * * bash '/home/$USER_NAME/sun108-ota-agent/watchdog-touchinput.sh'
49 * * * * bash '/home/$USER_NAME/sun108-ota-agent/utils/redis-cli/check-version.sh'
"

echo ">> Setting root cron jobs..."

# Load current root cron
sudo crontab -l > "$ROOT_CRON_TMP" 2>/dev/null || touch "$ROOT_CRON_TMP"

# Append missing entries only
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if ! grep -Fqx "$line" "$ROOT_CRON_TMP"; then
    echo "$line" >> "$ROOT_CRON_TMP"
  fi
done <<< "$ROOT_JOBS"

# Install updated root cron
sudo crontab "$ROOT_CRON_TMP"
ok "Root cron installed."

#########################################################
# 2) USER CRONTAB (for sun108)
#########################################################

USER_JOBS="
*/1 * * * * DISPLAY=:0 bash '/home/$USER_NAME/sun108-ota-agent/watchdog-orientation.sh'
*/1 * * * * DISPLAY=:0 bash '/home/$USER_NAME/sun108-ota-agent/watchdog-monitor.sh'
"

echo ">> Setting cron jobs for user $USER_NAME..."

# Load current user cron
crontab -u "$USER_NAME" -l > "$USER_CRON_TMP" 2>/dev/null || touch "$USER_CRON_TMP"

# Append missing entries only
while IFS= read -r line; do
  [ -z "$line" ] && continue
  if ! grep -Fqx "$line" "$USER_CRON_TMP"; then
    echo "$line" >> "$USER_CRON_TMP"
  fi
done <<< "$USER_JOBS"

# Install updated user cron
crontab -u "$USER_NAME" "$USER_CRON_TMP"
ok "User cron installed."

echo "=== Cron setup completed successfully ==="

echo "Root cron:"
sudo crontab -l
echo "-------------------------"
echo "User cron ($USER_NAME):"
crontab -u "$USER_NAME" -l
echo "========================="

echo "───────────────────────────────────────────────"
echo -e "✅  ${GREEN}Octimus I setup completed successfully!${RESET}"
echo "───────────────────────────────────────────────"

echo "🔁 Rebooting system in 5 seconds..."
sleep 5
sudo reboot
