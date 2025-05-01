#!/bin/bash

# Check if whiptail is installed
if ! command -v whiptail &> /dev/null; then
    echo "Installing whiptail..."
    apt-get update && apt-get install -y whiptail
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Function to show error message
show_error() {
    whiptail --title "Error" --msgbox "$1" 8 60
}

# Function to show info message
show_info() {
    whiptail --title "Information" --msgbox "$1" 8 60
}

# Function to get input with validation
get_input() {
    local title="$1"
    local prompt="$2"
    local default="$3"
    local required="$4"
    local input
    
    while true; do
        if [ -n "$default" ]; then
            input=$(whiptail --title "$title" --inputbox "$prompt" 8 60 "$default" 3>&1 1>&2 2>&3)
        else
            input=$(whiptail --title "$title" --inputbox "$prompt" 8 60 3>&1 1>&2 2>&3)
        fi
        
        # Check if user pressed Cancel
        if [ $? -ne 0 ]; then
            echo "CANCELLED"
            return
        fi
        
        if [ "$required" = "true" ] && [ -z "$input" ]; then
            show_error "This field is required"
            continue
        fi
        
        break
    done
    echo "$input"
}

# Show welcome message
whiptail --title "Proxmox Maintenance Tool" --msgbox "Welcome to the Proxmox Maintenance Tool installer.\n\nThis will install the maintenance tool with a web interface for managing your Proxmox nodes." 12 60

# Get Proxmox credentials
PROXMOX_HOST=$(get_input "Proxmox Configuration" "Enter Proxmox host URL (e.g., https://proxmox.example.com:8006):" "" "true")
if [ "$PROXMOX_HOST" = "CANCELLED" ]; then
    show_error "Installation cancelled by user"
    exit 1
fi

PROXMOX_USER=$(get_input "Proxmox Configuration" "Enter Proxmox user:" "root@pam" "true")
if [ "$PROXMOX_USER" = "CANCELLED" ]; then
    show_error "Installation cancelled by user"
    exit 1
fi

PROXMOX_PASS=$(get_input "Proxmox Configuration" "Enter Proxmox password:" "" "true")
if [ "$PROXMOX_PASS" = "CANCELLED" ]; then
    show_error "Installation cancelled by user"
    exit 1
fi

# Confirm installation
if ! whiptail --title "Confirm Installation" --yesno "Proxmox host: $PROXMOX_HOST\nProxmox user: $PROXMOX_USER\n\nProceed with installation?" 12 60; then
    show_error "Installation cancelled by user"
    exit 1
fi

# Create temporary directory
TEMP_DIR=$(mktemp -d)
cd $TEMP_DIR

# Show progress
{
    echo "XXX"
    echo "Downloading required files..."
    echo "XXX"
    curl -sSL https://raw.githubusercontent.com/zenjabba/proxmox-maintenance/main/proxmox_maintenance.py -o proxmox_maintenance.py
    echo "20"
    echo "XXX"
    echo "Downloading web interface..."
    echo "XXX"
    curl -sSL https://raw.githubusercontent.com/zenjabba/proxmox-maintenance/main/web_interface.py -o web_interface.py
    echo "40"
    echo "XXX"
    echo "Downloading dependencies..."
    echo "XXX"
    curl -sSL https://raw.githubusercontent.com/zenjabba/proxmox-maintenance/main/requirements.txt -o requirements.txt
    echo "60"
    echo "XXX"
    echo "Downloading service configuration..."
    echo "XXX"
    curl -sSL https://raw.githubusercontent.com/zenjabba/proxmox-maintenance/main/proxmox-maintenance.service -o proxmox-maintenance.service
    echo "80"
    echo "XXX"
    echo "Creating configuration..."
    echo "XXX"
    mkdir -p templates
    curl -sSL https://raw.githubusercontent.com/zenjabba/proxmox-maintenance/main/templates/index.html -o templates/index.html
    
    # Create .proxmox file with user input
    cat > .proxmox << EOF
[proxmox]
host = ${PROXMOX_HOST}
user = ${PROXMOX_USER}
password = ${PROXMOX_PASS}
EOF
    echo "100"
    echo "XXX"
    echo "Download complete!"
    echo "XXX"
} | whiptail --title "Installation Progress" --gauge "Please wait while downloading files..." 6 60 0

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
EOF

chmod +x setup.sh

# Show setup progress
{
    echo "XXX"
    echo "Running system setup..."
    echo "XXX"
    ./setup.sh
    echo "100"
    echo "XXX"
    echo "Setup complete!"
    echo "XXX"
} | whiptail --title "Setup Progress" --gauge "Please wait while setting up the system..." 6 60 0

# Cleanup
cd /
rm -rf $TEMP_DIR

# Show completion message
whiptail --title "Installation Complete" --msgbox "The Proxmox Maintenance Tool has been installed successfully!\n\nThe web interface should be available at http://<container-ip>\n\nYou can restart the service if needed using:\nsystemctl restart proxmox-maintenance" 12 60 