# Proxmox Maintenance Tool

A web-based tool for managing Proxmox VE nodes in maintenance mode. This tool provides a simple interface to:
- View all nodes in your Proxmox cluster
- Put nodes into maintenance mode
- Automatically migrate VMs to other nodes
- Monitor the maintenance process

## Quick Install

Run this command in your Proxmox LXC container:

```bash
curl -sSL https://raw.githubusercontent.com/yourusername/proxmox-maintenance/main/install.sh | bash
```

After installation:
1. Create your configuration file:
```bash
cp /opt/proxmox-maintenance/.proxmox.template /opt/proxmox-maintenance/.proxmox
nano /opt/proxmox-maintenance/.proxmox
```

2. Restart the service:
```bash
systemctl restart proxmox-maintenance
```

The web interface will be available at `http://<container-ip>`

## Requirements

- Proxmox VE cluster
- LXC container with:
  - Ubuntu 22.04 LTS
  - At least 1GB RAM
  - At least 10GB storage
  - Network access

## Features

- Modern web interface
- Real-time status updates
- Automatic VM migration
- Resource-aware node selection
- Secure credential management
- Systemd service management
- Nginx reverse proxy

## Security

- Runs as www-data user
- Secure file permissions
- Virtual environment for Python dependencies
- SSL-ready configuration
- Credential file protection

## Manual Installation

If you prefer to install manually:

1. Clone the repository:
```bash
git clone https://github.com/yourusername/proxmox-maintenance.git
cd proxmox-maintenance
```

2. Run the setup script:
```bash
./setup.sh
```

3. Configure the application:
```bash
cp .proxmox.template .proxmox
nano .proxmox
```

4. Start the service:
```bash
systemctl start proxmox-maintenance
```

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

## License

This project is licensed under the MIT License - see the LICENSE file for details. 