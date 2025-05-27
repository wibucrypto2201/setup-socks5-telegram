#!/bin/bash

# SOCKS5 Proxy Setup Script (Dante)
# Compatible with Telegram, curl, browsers

set -e

# Prompt for username and password
echo "Enter username for proxy authentication:"
read -r USERNAME
echo "Enter password for user $USERNAME:"
read -rs PASSWORD

PORT=1080
INTERFACE="eth0"

# Remove old installation
echo "[+] Removing old Dante setup (if any)"
sudo systemctl stop danted || true
sudo apt purge --autoremove dante-server -y || true
sudo rm -f /etc/danted.conf /var/log/danted.log || true

# Reinstall Dante
echo "[+] Installing dante-server"
sudo apt update
sudo apt install dante-server -y

# Create new system user
echo "[+] Creating user: $USERNAME"
sudo deluser --remove-home $USERNAME || true
sudo adduser --disabled-login --gecos "" $USERNAME
# If password too weak, bypass policy
echo "$USERNAME:$PASSWORD" | sudo chpasswd --crypt-method=SHA512

# Generate Dante config
echo "[+] Writing /etc/danted.conf"
cat <<EOF | sudo tee /etc/danted.conf > /dev/null
logoutput: /var/log/danted.log
internal: $INTERFACE port = $PORT
external: $INTERFACE

method: username
user.notprivileged: nobody

client pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    log: connect disconnect error
}

pass {
    from: 0.0.0.0/0 to: 0.0.0.0/0
    protocol: tcp udp
    log: connect disconnect error
}
EOF

# Open firewall port
echo "[+] Opening firewall port $PORT"
sudo ufw allow $PORT/tcp || true

# Restart Dante
echo "[+] Restarting danted"
sudo systemctl restart danted
sudo systemctl enable danted

# Test
echo "[+] Setup complete. You can test with:"
echo "curl --proxy-user $USERNAME:$PASSWORD --socks5 \$(curl -s ifconfig.me):$PORT https://api.ipify.org"
