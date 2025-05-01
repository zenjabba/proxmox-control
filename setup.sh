#!/bin/bash

# Update system
apt-get update
apt-get upgrade -y

# Install required packages
apt-get install -y python3-venv python3-pip nginx

# Create application directory
mkdir -p /opt/proxmox-maintenance
cp -r . /opt/proxmox-maintenance/

# Create and activate virtual environment
cd /opt/proxmox-maintenance
python3 -m venv venv
source venv/bin/activate

# Install Python dependencies
pip install -r requirements.txt

# Set up nginx
cat > /etc/nginx/sites-available/proxmox-maintenance << 'EOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
EOF

ln -s /etc/nginx/sites-available/proxmox-maintenance /etc/nginx/sites-enabled/
rm /etc/nginx/sites-enabled/default
nginx -t && systemctl restart nginx

# Set up systemd service
cp proxmox-maintenance.service /etc/systemd/system/
systemctl daemon-reload
systemctl enable proxmox-maintenance
systemctl start proxmox-maintenance

# Set permissions
chown -R www-data:www-data /opt/proxmox-maintenance
chmod 600 /opt/proxmox-maintenance/.proxmox

echo "Setup complete! The web interface should be available at http://<container-ip>" 