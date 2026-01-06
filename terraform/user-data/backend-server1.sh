#!/bin/bash
#
# User Data Script for Backend Server 1
# Automatically configures Nginx web server on port 8081
#

set -euo pipefail

# Logging
exec > >(tee -a /var/log/user-data.log)
exec 2>&1

echo "========================================="
echo "Backend Server 1 Setup Script"
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

# Create web directory
echo "[3/4] Setting up web content and configuration..."
mkdir -p /var/www/server1

# Write the HTML content (passed from Terraform)
cat > /var/www/server1/index.html << 'HTML_EOF'
${html_content}
HTML_EOF

# Write the Nginx configuration (passed from Terraform)
cat > /etc/nginx/nginx.conf << 'NGINX_EOF'
${nginx_conf}
NGINX_EOF

# Create server status endpoint
cat > /var/www/server1/server-status << 'EOF'
{"server": "server1", "status": "online", "port": 8081, "id": 1}
EOF

# Test configuration
nginx -t

# Start Nginx
echo "[4/4] Starting Nginx..."
systemctl start nginx
systemctl enable nginx

# Create motd
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              BACKEND SERVER 1 - NGINX WEB SERVER             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

This server is configured as Backend Server 1.

Configuration:
  - Port: 8081
  - Server ID: 1
  - Color Theme: Purple 🟣
  - Config: /etc/nginx/nginx.conf
  - Web Root: /var/www/server1

Useful Commands:
  - Check Nginx status:  sudo systemctl status nginx
  - View access logs:    sudo tail -f /var/log/nginx/server1_access.log
  - Test configuration:  sudo nginx -t
  - Reload config:       sudo nginx -s reload

EOF

echo "========================================="
echo "Backend Server 1 Setup Complete!"
echo "Finished at: $(date)"
echo "========================================="

# Signal completion
touch /var/log/user-data-complete

<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Backend Server 1</title>
    <style>
        * {
            margin: 0;
            padding: 0;
            box-sizing: border-box;
        }
        body {
            font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif;
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            min-height: 100vh;
            display: flex;
            justify-content: center;
            align-items: center;
            padding: 20px;
        }
        .container {
            background: white;
            border-radius: 20px;
            padding: 40px;
            box-shadow: 0 20px 60px rgba(0, 0, 0, 0.3);
            max-width: 600px;
            text-align: center;
            animation: fadeIn 0.6s ease-in-out;
        }
        @keyframes fadeIn {
            from { opacity: 0; transform: translateY(-20px); }
            to { opacity: 1; transform: translateY(0); }
        }
        .server-badge {
            background: linear-gradient(135deg, #667eea 0%, #764ba2 100%);
            color: white;
            padding: 15px 30px;
            border-radius: 50px;
            font-size: 24px;
            font-weight: bold;
            display: inline-block;
            margin-bottom: 20px;
            box-shadow: 0 4px 15px rgba(102, 126, 234, 0.4);
        }
        h1 {
            color: #333;
            margin-bottom: 20px;
            font-size: 32px;
        }
        .info-box {
            background: #f8f9fa;
            border-left: 4px solid #667eea;
            padding: 20px;
            margin: 20px 0;
            text-align: left;
            border-radius: 5px;
        }
        .info-box h3 {
            color: #667eea;
            margin-bottom: 10px;
        }
        .info-box p {
            color: #666;
            line-height: 1.6;
            margin: 5px 0;
        }
        .timestamp {
            background: #e3f2fd;
            padding: 15px;
            border-radius: 8px;
            margin: 20px 0;
            font-family: 'Courier New', monospace;
            color: #1976d2;
        }
        .reload-hint {
            margin-top: 30px;
            padding: 15px;
            background: #fff3cd;
            border-radius: 8px;
            border: 2px dashed #ffc107;
            color: #856404;
            font-weight: 500;
        }
    </style>
</head>
<body>
    <div class="container">
        <div class="server-badge">🟣 SERVER 1</div>
        <h1>Backend Server 1</h1>
        <div class="info-box">
            <h3>📍 Server Information</h3>
            <p><strong>Server ID:</strong> Backend-Server-01</p>
            <p><strong>Port:</strong> 8081</p>
            <p><strong>Location:</strong> AWS Cloud</p>
            <p><strong>Status:</strong> <span style="color: #28a745;">● Online</span></p>
            <p><strong>Deployed via:</strong> Terraform</p>
        </div>
        <div class="timestamp">
            <strong>🕐 Request Time:</strong><br>
            <span id="timestamp"></span>
        </div>
        <div class="reload-hint">
            💡 <strong>Reload this page</strong> to see load balancing in action!<br>
            You should be routed to different servers.
        </div>
    </div>
    <script>
        function updateTimestamp() {
            const now = new Date();
            document.getElementById('timestamp').textContent = now.toLocaleString();
        }
        updateTimestamp();
    </script>
</body>
</html>
EOF

# Create server status endpoint
cat > /var/www/server1/server-status << 'EOF'
{"server": "server1", "status": "online", "port": 8081, "id": 1}
EOF

# Configure Nginx
echo "[4/5] Configuring Nginx..."
cat > /etc/nginx/sites-available/default << 'EOF'
server {
    listen 8081 default_server;
    server_name _;
    
    root /var/www/server1;
    index index.html;
    
    access_log /var/log/nginx/server1_access.log;
    error_log /var/log/nginx/server1_error.log;
    
    location / {
        try_files $uri $uri/ =404;
        add_header X-Served-By "Backend-Server-1" always;
        add_header X-Server-Port "8081" always;
    }
    
    location /health {
        access_log off;
        return 200 "Server 1 is healthy\n";
        add_header Content-Type text/plain;
    }
    
    location /server-status {
        alias /var/www/server1/server-status;
        default_type application/json;
        add_header Content-Type application/json;
    }
}
EOF

# Test configuration
nginx -t

# Start Nginx
echo "[5/5] Starting Nginx..."
systemctl start nginx
systemctl enable nginx

# Create motd
cat > /etc/motd << 'EOF'
╔══════════════════════════════════════════════════════════════╗
║                                                              ║
║              BACKEND SERVER 1 - NGINX WEB SERVER             ║
║                                                              ║
╚══════════════════════════════════════════════════════════════╝

This server is configured as Backend Server 1.

Configuration:
  - Port: 8081
  - Server ID: 1
  - Color Theme: Purple 🟣

Useful Commands:
  - Check Nginx status:  sudo systemctl status nginx
  - View access logs:    sudo tail -f /var/log/nginx/server1_access.log
  - Test configuration:  sudo nginx -t

EOF

echo "========================================="
echo "Backend Server 1 Setup Complete!"
echo "Finished at: $(date)"
echo "========================================="

# Signal completion
touch /var/log/user-data-complete
