#!/usr/bin/env bash
set -euo pipefail

# uninstall.sh - Removes Gold Fastfetch Config and restores backup

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Safety check: no root
if [[ $EUID -eq 0 ]]; then
    echo -e "${RED}[Error] Do not run this script as root/sudo.${NC}"
    exit 1
fi

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fastfetch"
BACKUP_DIR="$STATE_DIR/backups"

# Sanity check: ensure CONFIG_DIR is valid before rm -rf
if [[ -z "$CONFIG_DIR" || "$CONFIG_DIR" == "/" || ! "$CONFIG_DIR" =~ fastfetch$ ]]; then
    echo -e "${RED}[Error] Invalid CONFIG_DIR: '$CONFIG_DIR'. Aborting for safety.${NC}"
    exit 1
fi

echo -e "${YELLOW}==> Gold Fastfetch Uninstaller${NC}"
echo -e "    This will remove the current configuration and restore the latest backup."
read -r -p "    Are you sure? (y/N) " response
if [[ ! $response =~ ^[Yy]$ ]]; then
    echo "Aborted."
    exit 0
fi

echo -e "\n${RED}-> Removing current configuration...${NC}"
rm -rf "$CONFIG_DIR"

# Find latest backup
LATEST_BACKUP=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name "backup_*" 2>/dev/null | sort -r | head -n1)

if [[ -n "$LATEST_BACKUP" ]]; then
    echo -e "${GREEN}-> Restoring backup: $(basename "$LATEST_BACKUP")${NC}"
    mkdir -p "$CONFIG_DIR"
    cp -a "$LATEST_BACKUP/." "$CONFIG_DIR/"
    echo -e "${GREEN}==> Restore complete!${NC}"
else
    echo -e "${YELLOW}[!] No backup found. Fastfetch configuration reset to defaults.${NC}"
fi
