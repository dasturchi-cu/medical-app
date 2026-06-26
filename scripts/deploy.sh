#!/bin/bash
# =====================================================================
# NEUROSCIENCE APP - CONTABO VPS DEPLOYMENT SCRIPT
# Hardened for Cloudflare Proxy (Accepts HTTP/S only from Cloudflare)
# =====================================================================

set -e

echo "=== Starting Hardened Contabo VPS Deployment Setup ==="

# 1. Update and install core packages
echo "Updating packages..."
sudo apt-get update && sudo apt-get upgrade -y
sudo apt-get install -y curl gnupg lsb-release fail2ban ufw git

# 2. Install Docker & Docker Compose if not installed
if ! [ -x "$(command -v docker)" ]; then
    echo "Installing Docker..."
    sudo mkdir -p /etc/apt/keyrings
    curl -fsSL https://download.docker.com/linux/ubuntu/gpg | sudo gpg --dearmor -o /etc/apt/keyrings/docker.gpg
    echo \
      "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.gpg] https://download.docker.com/linux/ubuntu \
      $(lsb_release -cs) stable" | sudo tee /etc/apt/sources.list.d/docker.list > /dev/null
    sudo apt-get update
    sudo apt-get install -y docker-ce docker-ce-cli containerd.io docker-compose-plugin
fi

# 3. Configure Fail2Ban for SSH protection
echo "Configuring Fail2Ban..."
sudo tee /etc/fail2ban/jail.local > /dev/null <<EOF
[sshd]
enabled = true
port = 22
filter = sshd
logpath = /var/log/auth.log
maxretry = 5
bantime = 1d
findtime = 10m
EOF
sudo systemctl restart fail2ban

# 4. Configure UFW Firewall (Cloudflare IP Lockdown)
echo "Configuring UFW Firewall with Cloudflare IP Lockdown..."
sudo ufw default deny incoming
sudo ufw default allow outgoing

# Allow standard SSH (Change 22 to custom SSH port if you use one)
sudo ufw allow 22/tcp comment 'Allow SSH'

# Cloudflare IPv4 ranges
CLOUDFLARE_IPV4=(
    "173.245.48.0/20"
    "103.21.244.0/22"
    "103.22.200.0/22"
    "103.31.4.0/22"
    "141.101.64.0/18"
    "108.162.192.0/18"
    "190.93.240.0/20"
    "188.114.96.0/20"
    "197.234.240.0/22"
    "198.41.128.0/17"
    "162.158.0.0/15"
    "104.16.0.0/13"
    "104.24.0.0/14"
    "172.64.0.0/13"
    "131.0.72.0/22"
)

# Cloudflare IPv6 ranges
CLOUDFLARE_IPV6=(
    "2400:cb00::/32"
    "2606:4700::/32"
    "2803:f800::/32"
    "2405:b500::/32"
    "2405:8100::/32"
    "2a06:98c0::/29"
    "2c0f:f248::/32"
)

# Allow port 80/443 ONLY from Cloudflare IPv4 ranges
for ip in "${CLOUDFLARE_IPV4[@]}"; do
    sudo ufw allow from "$ip" to any port 80 proto tcp comment 'CF IPv4 HTTP'
    sudo ufw allow from "$ip" to any port 443 proto tcp comment 'CF IPv4 HTTPS'
done

# Allow port 80/443 ONLY from Cloudflare IPv6 ranges
for ip in "${CLOUDFLARE_IPV6[@]}"; do
    sudo ufw allow from "$ip" to any port 80 proto tcp comment 'CF IPv6 HTTP'
    sudo ufw allow from "$ip" to any port 443 proto tcp comment 'CF IPv6 HTTPS'
done

# Enable UFW
echo "y" | sudo ufw enable
sudo ufw status verbose

# 5. Create SSL Certificate Folders and verify keys exist
echo "Creating SSL Folders..."
sudo mkdir -p /etc/ssl/certs
sudo mkdir -p /etc/ssl/private

# Prompt user for certificates if not exists
if [ ! -f /etc/ssl/certs/neuroscience_server.crt ] || [ ! -f /etc/ssl/private/neuroscience_server.key ]; then
    echo "====================================================================="
    echo "WARNING: SSL Certificate or Key not found in /etc/ssl/!"
    echo "Please place your SSL certificate at: /etc/ssl/certs/neuroscience_server.crt"
    echo "Please place your Private key at: /etc/ssl/private/neuroscience_server.key"
    echo "Then run this script again."
    echo "====================================================================="
fi

# 6. Run Application Containers
echo "Building and launching Docker containers..."
sudo docker compose down --remove-orphans || true
sudo docker compose up -d --build

echo "=== Deployment Completed Successfully ==="
sudo docker compose ps
