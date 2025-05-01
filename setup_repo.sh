#!/bin/bash

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo -e "${GREEN}Setting up GitHub repository...${NC}"

# Check if git is installed
if ! command -v git &> /dev/null; then
    echo -e "${RED}Git is not installed. Please install git first.${NC}"
    exit 1
fi

# Initialize git repository
git init

# Add all files
git add .

# Initial commit
git commit -m "Initial commit: Proxmox Maintenance Tool"

# Add remote repository
echo -e "${YELLOW}Please enter your GitHub username:${NC}"
read username

# Create main branch
git branch -M main

# Add remote
git remote add origin "https://github.com/${username}/proxmox-maintenance.git"

echo -e "${YELLOW}Now you need to:${NC}"
echo "1. Create a new repository on GitHub named 'proxmox-maintenance'"
echo "2. Run these commands:"
echo -e "${GREEN}git push -u origin main${NC}"

echo -e "\n${YELLOW}After pushing to GitHub, update the install.sh script with your username:${NC}"
echo "Replace 'zenjabba' with '${username}' in the curl commands" 