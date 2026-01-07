#!/bin/bash
#
# User Data Script for Load Balancer Instance
# Automatically configures Nginx as a load balancer
#

set -euo pipefail

# Logging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Load Balancer Setup Script"
echo "Started at: $(date)"
echo "========================================="

# Update system
echo "[1/4] Updating system packages..."
export DEBIAN_FRONTEND=noninteractive
apt-get update -y
apt-get upgrade -y

# Install Nginx
echo "[2/4] Installing Nginx..."
apt-get install -y nginx

# Stop Nginx to configure
systemctl stop nginx

# Configure Nginx using the template from repo
echo "[3/4] Configuring Nginx load balancer with ${lb_algorithm} algorithm..."

# Write the Nginx configuration (passed from Terraform)
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
${nginx_conf}
NGINX_EOF

# Replace placeholder IPs with actual private IPs
sed -i "s/localhost:8081/${server1_ip}:8081/g" /etc/nginx/nginx.conf
sed -i "s/localhost:8082/${server2_ip}:8082/g" /etc/nginx/nginx.conf

# For weighted algorithm, update the weights
if [ "${lb_algorithm}" == "weighted" ]; then
    sed -i "s/server ${server1_ip}:8081;/server ${server1_ip}:8081 weight=${server1_weight};/g" /etc/nginx/nginx.conf
    sed -i "s/server ${server2_ip}:8082;/server ${server2_ip}:8082 weight=${server2_weight};/g" /etc/nginx/nginx.conf
fi

# Test configuration
echo "[4/4] Testing and starting Nginx..."
nginx -t

# Start Nginx
systemctl start nginx
systemctl enable nginx

# Install monitoring tools
apt-get install -y htop curl net-tools

# Create a welcome message
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              NGINX LOAD BALANCER - SERVER                    ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

This server is configured as an Nginx Load Balancer.

Configuration:
  - Algorithm: ${lb_algorithm}
  - Backend Servers: 2
  - Port: 80
  - Config: /etc/nginx/nginx.conf

Useful Commands:
  - Check Nginx status:  sudo systemctl status nginx
  - View access logs:    sudo tail -f /var/log/nginx/access.log
  - Test configuration:  sudo nginx -t
  - Reload Nginx:        sudo nginx -s reload

Backend Servers:
  - Server 1: ${server1_ip}:8081 (weight: ${server1_weight})
  - Server 2: ${server2_ip}:8082 (weight: ${server2_weight})

Test Load Balancer:
  curl http://localhost/
  curl http://localhost/health

EOF

echo "========================================="
echo "Load Balancer Setup Complete!"
echo "Algorithm: ${lb_algorithm}"
echo "Backend Server 1: ${server1_ip}:8081"
echo "Backend Server 2: ${server2_ip}:8082"
echo "Finished at: $(date)"
echo "========================================="

# Signal completion
touch /var/log/user-data-complete

# Signal completion
touch /var/log/user-data-complete
