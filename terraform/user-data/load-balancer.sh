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

        listen 80 default_server;
        server_name _;
        
        location / {
            proxy_pass http://backend_servers;
            
            # Headers
            proxy_set_header Host $host;
            proxy_set_header X-Real-IP $remote_addr;
            proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
            proxy_set_header X-Forwarded-Proto $scheme;
            
            # Timeouts
            proxy_connect_timeout 5s;
            proxy_send_timeout 60s;
            proxy_read_timeout 60s;
            
            # Retry logic
            proxy_next_upstream error timeout invalid_header http_500 http_502 http_503;
            proxy_next_upstream_tries 2;
            
            # HTTP version
            proxy_http_version 1.1;
            proxy_set_header Connection "";
            
            # Add custom headers
            add_header X-Load-Balancer-Algorithm "ALGORITHM" always;
            add_header X-Upstream-Server $upstream_addr always;
        }
        
        location /health {
            access_log off;
            return 200 "Load Balancer is healthy\n";
            add_header Content-Type text/plain;
        }
        
        location /status {
            access_log off;
            return 200 '{"status": "online", "algorithm": "ALGORITHM", "backends": 2}';
            add_header Content-Type application/json;
        }
    }
}
EOF

# Replace placeholders
sed -i "s/ALGORITHM/$ALGORITHM/g" /etc/nginx/nginx.conf
sed -i "s/SERVER1_IP/$SERVER1_IP/g" /etc/nginx/nginx.conf
sed -i "s/SERVER2_IP/$SERVER2_IP/g" /etc/nginx/nginx.conf

# Test configuration
echo "[4/6] Testing Nginx configuration..."
nginx -t

# Start Nginx
echo "[5/6] Starting Nginx..."
systemctl start nginx
systemctl enable nginx

# Install monitoring tools
echo "[6/6] Installing monitoring tools..."
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
  - Algorithm: ALGORITHM
  - Backend Servers: 2
  - Port: 80

Useful Commands:
  - Check Nginx status:  sudo systemctl status nginx
  - View access logs:    sudo tail -f /var/log/nginx/access.log
  - Test configuration:  sudo nginx -t
  - Reload Nginx:        sudo nginx -s reload

Backend Servers:
  - Server 1: SERVER1_IP:8081
  - Server 2: SERVER2_IP:8082

EOF

sed -i "s/ALGORITHM/$ALGORITHM/g" /etc/motd
sed -i "s/SERVER1_IP/$SERVER1_IP/g" /etc/motd
sed -i "s/SERVER2_IP/$SERVER2_IP/g" /etc/motd

echo "========================================="
echo "Load Balancer Setup Complete!"
echo "Finished at: $(date)"
echo "========================================="

# Signal completion
touch /var/log/user-data-complete
