#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Starting Proxmox Maintenance Tool installation...${NC}"

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Download all required files
echo -e "${YELLOW}Downloading required files...${NC}"
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/proxmox_maintenance.py -o proxmox_maintenance.py
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/web_interface.py -o web_interface.py
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/requirements.txt -o requirements.txt
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/proxmox-maintenance.service -o proxmox-maintenance.service
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/.proxmox.template -o .proxmox.template
mkdir -p templates
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/templates/index.html -o templates/index.html

# Create setup script
cat > setup.sh << 'EOF'
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
cat > /etc/nginx/sites-available/proxmox-maintenance << 'NGINXEOF'
server {
    listen 80;
    server_name _;

    location / {
        proxy_pass http://127.0.0.1:5000;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
    }
}
NGINXEOF

ln -s /etc/nginx/sites-available/proxmox-maintenance /etc/nginx/sites-enabled/
rm -f /etc/nginx/sites-enabled/default
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
EOF

chmod +x setup.sh

# Run setup
echo -e "${YELLOW}Running setup...${NC}"
./setup.sh

# Cleanup
cd /
rm -rf $TEMP_DIR

echo -e "${GREEN}Installation complete!${NC}"
echo -e "${YELLOW}Please create your .proxmox configuration file:${NC}"
echo "cp /opt/proxmox-maintenance/.proxmox.template /opt/proxmox-maintenance/.proxmox"
echo "nano /opt/proxmox-maintenance/.proxmox"
echo -e "${YELLOW}Then restart the service:${NC}"
echo "systemctl restart proxmox-maintenance" 