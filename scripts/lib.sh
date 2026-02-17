#!/usr/bin/env bash
# lib.sh - Shared helper library for Gold Fastfetch scripts
set -euo pipefail

# shellcheck disable=SC2034
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# --- Colors ---
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# --- Logging (uses printf instead of echo -e) ---
log_info() {
    printf "${GREEN}%s${NC}\n" "$*"
}

log_warn() {
    printf "${YELLOW}%s${NC}\n" "$*"
}

log_error() {
    printf "${RED}%s${NC}\n" "$*"
}

die() {
    log_error "$*"
    exit 1
}

# --- Checks ---
check_not_root() {
    if [[ $EUID -eq 0 ]]; then
        die "[Error] Do not run this script as root/sudo."
    fi
}

check_arch() {
    if [[ ! -f /etc/arch-release ]]; then
        log_error "[Error] This script is explicitly designed for Arch Linux."
        printf "Running on non-Arch systems may break your config.\n"
        exit 1
    fi
}

check_command() {
    local cmd="$1"
    command -v "$cmd" >/dev/null 2>&1
}

require_interactive() {
    if [[ ! -t 0 ]]; then
        die "[Error] This script requires an interactive terminal."
    fi
}
