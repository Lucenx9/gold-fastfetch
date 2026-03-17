#!/usr/bin/env bash
set -euo pipefail

# uninstall.sh - Removes Gold Fastfetch Config and restores backup

# shellcheck source=scripts/lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/scripts/lib.sh"

check_not_root

CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fastfetch"
BACKUP_DIR="$STATE_DIR/backups"

# Sanity check: ensure CONFIG_DIR is valid before rm -rf
if [[ -z "$CONFIG_DIR" || "$CONFIG_DIR" == "/" || ! "$CONFIG_DIR" =~ fastfetch$ ]]; then
    die "[Error] Invalid CONFIG_DIR: '$CONFIG_DIR'. Aborting for safety."
fi

log_warn "==> Gold Fastfetch Uninstaller"
printf "    This will remove the current configuration and restore the latest backup.\n"

require_interactive

if read -r -p "    Are you sure? (y/N) " response; then
    if [[ ! $response =~ ^[Yy]$ ]]; then
        printf "Aborted.\n"
        exit 0
    fi
else
    printf "Aborted.\n"
    exit 1
fi

log_error "-> Removing current configuration..."
rm -rf "$CONFIG_DIR"

# Find latest backup
LATEST_BACKUP=$(find "$BACKUP_DIR" -mindepth 1 -maxdepth 1 -type d -name "backup_*" 2>/dev/null | sort -r | head -n1)

if [[ -n "$LATEST_BACKUP" ]]; then
    log_info "-> Restoring backup: $(basename "$LATEST_BACKUP")"
    mkdir -p "$CONFIG_DIR"
    cp -a "$LATEST_BACKUP/." "$CONFIG_DIR/"
    log_info "==> Restore complete!"
else
    log_warn "[!] No backup found. Fastfetch configuration reset to defaults."
fi
