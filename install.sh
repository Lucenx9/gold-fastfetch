#!/usr/bin/env bash
# install.sh - Installer for Gold Fastfetch Config
# Version: 2.0 (Supports gold/minimal variants)

set -euo pipefail

# Guard against process substitution (e.g. bash <(curl ...))
if [[ ! -f "${BASH_SOURCE[0]}" ]]; then
    printf '\033[0;31m[Error] Cannot run via process substitution.\033[0m\n'
    printf 'Clone the repository first:\n'
    printf '  git clone https://github.com/Lucenx9/gold-fastfetch.git && cd gold-fastfetch && ./install.sh\n'
    exit 1
fi

# Resolve project root and source shared library
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib.sh
source "$SCRIPT_DIR/scripts/lib.sh"

# XDG paths
CONFIG_DIR="${XDG_CONFIG_HOME:-$HOME/.config}/fastfetch"
STATE_DIR="${XDG_STATE_HOME:-$HOME/.local/state}/fastfetch"

trap 'printf "\n"; log_error "[!] Installation aborted."; exit 1' INT

# --- Argument Handling ---
USE_ICONS_ARG=""
VARIANT="gold"
while [[ "$#" -gt 0 ]]; do
    case $1 in
        --icons) USE_ICONS_ARG=1 ;;
        --no-icons) USE_ICONS_ARG=0 ;;
        --variant)
            shift
            if [[ "$#" -eq 0 ]]; then
                die "[Error] --variant requires a value (gold or minimal)."
            fi
            VARIANT="$1"
            if [[ "$VARIANT" != "gold" && "$VARIANT" != "minimal" ]]; then
                die "[Error] Unknown variant '$VARIANT'. Must be 'gold' or 'minimal'."
            fi
            ;;
        *) die "Unknown option: $1" ;;
    esac
    shift
done

# Validate template exists
TEMPLATE_FILE="$SCRIPT_DIR/templates/config-${VARIANT}.jsonc"
if [[ ! -f "$TEMPLATE_FILE" ]]; then
    die "[Error] Template not found: $TEMPLATE_FILE"
fi

# 0. Pre-flight checks
check_not_root
check_arch

log_info "==> Gold Fastfetch Installer v2.0 (variant: $VARIANT)"

# 1. Check Dependencies
if ! check_command fastfetch; then
    log_error "[Error] Fastfetch is not installed."
    printf "Run: sudo pacman -S fastfetch\n"
    exit 1
fi

FF_RAW_VER=$(fastfetch --version 2>/dev/null || echo "0.0.0")
FF_MAJOR=$(echo "$FF_RAW_VER" | grep -oE '[0-9]+\.[0-9]+' | head -n1 | cut -d. -f1 || echo "0")
if [[ ! "$FF_MAJOR" =~ ^[0-9]+$ ]]; then FF_MAJOR=0; fi

if [[ "$FF_MAJOR" -lt 2 ]]; then
    log_warn "[Warn] Fastfetch version ($FF_RAW_VER) seems outdated. v2+ recommended."
fi

log_info "==> Checking optional dependencies..."
MISSING_DEPS=0
for cmd in lspci checkupdates; do
    if ! check_command "$cmd"; then
        log_warn "  [Warn] '$cmd' missing."
        if [[ "$cmd" == "checkupdates" ]]; then
            log_warn "         -> Install with: sudo pacman -S pacman-contrib"
        elif [[ "$cmd" == "lspci" ]]; then
            log_warn "         -> Install with: sudo pacman -S pciutils"
        fi
        MISSING_DEPS=1
    fi
done
if [[ $MISSING_DEPS -eq 0 ]]; then log_info "  -> All dependencies found."; fi

# 2. Icon Capability Check
if [[ -n "$USE_ICONS_ARG" ]]; then
    USE_ICONS=$USE_ICONS_ARG
elif [[ -t 0 ]]; then
    log_info "==> Checking font support..."
    printf "  Can you see this icon clearly? -> [   ]\n"
    if read -r -p "  Enable Nerd Font icons? (y/N) " response; then
        if [[ $response =~ ^[Yy]$ ]]; then
            USE_ICONS=1
        else
            USE_ICONS=0
            log_warn "  -> Icons disabled."
            log_warn "     Tip: To use icons, install a Nerd Font, set it as your terminal font,"
            log_warn "          then run this installer again."
        fi
    else
        USE_ICONS=0
        log_warn "  -> No input detected; icons disabled."
    fi
else
    USE_ICONS=0
    log_warn "==> Non-interactive shell detected; icons disabled by default."
    log_warn "    Tip: re-run with --icons to force."
fi

# 3. Backup
mkdir -p "$STATE_DIR/backups"
mkdir -p "$CONFIG_DIR"

REQUIRED_KB=10240
AVAILABLE_KB=$(df -Pk "$STATE_DIR" 2>/dev/null | awk 'NR==2{print $4}' || echo "99999999")

if (( AVAILABLE_KB < REQUIRED_KB )); then
    die "[!] Insufficient space in $STATE_DIR ($AVAILABLE_KB KB available)."
fi

if [[ -d "$CONFIG_DIR" ]] && [[ -n "$(ls -A "$CONFIG_DIR" 2>/dev/null)" ]]; then
    BACKUP_PATH="$STATE_DIR/backups/backup_$(date +%Y%m%d_%H%M%S)"
    log_warn "==> Backing up existing config to:"
    printf "    %s\n" "$BACKUP_PATH"

    mkdir -p "$BACKUP_PATH"

    if cp -a "$CONFIG_DIR/." "$BACKUP_PATH/"; then
        log_info "  -> Backup successful."
        # Keep only last 5 backups (using -print0/xargs -0 for safe path handling)
        find "$STATE_DIR/backups" -mindepth 1 -maxdepth 1 -type d -printf '%T@ %p\0' 2>/dev/null | \
        sort -znr | tail -zn +6 | cut -zd ' ' -f 2- | xargs -r0 rm -rf
    else
        log_error "[!] Backup failed."
        if [[ -t 0 ]]; then
            if read -r -p "Continue anyway? (y/N) " response; then
                if [[ ! $response =~ ^[Yy]$ ]]; then exit 1; fi
            else
                exit 1
            fi
        else
            exit 1
        fi
    fi
fi

# 4. Install Helper Scripts (gold variant only)
if [[ "$VARIANT" == "gold" ]]; then
    SCRIPTS_DIR="$CONFIG_DIR/scripts"
    mkdir -p "$SCRIPTS_DIR"

    for script in "$SCRIPT_DIR/templates/scripts/"*.sh; do
        cp "$script" "$SCRIPTS_DIR/"
    done
    chmod +x "$SCRIPTS_DIR/"*.sh
fi

# 5. Generate Config from Template
log_info "==> Generating config.jsonc (variant: $VARIANT)..."

# Icon keys based on Nerd Font availability
if [[ $USE_ICONS -eq 1 ]]; then
    I_USER="󰟷 "; I_HOST="󰌢 "; I_TIME="󰃰 "; I_OS="󰏤 "; I_KER="󰌽 "; I_UP="󰥔 "
    I_UPD="󰚰 "; I_PKG="󰏖 "; I_AUR="󰣇 "; I_SH="󰟤 "; I_LOC="󰗊 "; I_DE="󰇧 "; I_WM="󰖩 "
    I_TERM=" "; I_FONT="󰛖 "; I_CPU="󰻠 "; I_GPU="󰢮 "; I_RAM="󰍛 "; I_SWAP="󰓡 "
    I_DISK="󰋊 "; I_DISP="󰍹 "; I_AUD="󰓃 "; I_THM="󰉼 "; I_ICO="󰀻 "; I_CUR="󰇀 "
    I_PAD="󰊗 "; I_IP="󰩟 "; I_PLAY="󰎈 "; I_MEDIA="󰝚 "; I_PAL="󰸱 "; I_BAT="󰁹 "
    I_MIC="󰍬 "
else
    I_USER=""; I_HOST=""; I_TIME=""; I_OS=""; I_KER=""; I_UP=""
    I_UPD=""; I_PKG=""; I_AUR=""; I_SH=""; I_LOC=""; I_DE=""; I_WM=""
    I_TERM=""; I_FONT=""; I_CPU=""; I_GPU=""; I_RAM=""; I_SWAP=""
    I_DISK=""; I_DISP=""; I_AUD=""; I_THM=""; I_ICO=""; I_CUR=""
    I_PAD=""; I_IP=""; I_PLAY=""; I_MEDIA=""; I_PAL=""; I_BAT=""
    I_MIC=""
fi

# Build sed replacement expression for all placeholders
# Use pipe | as delimiter to avoid conflicts with path separators
SED_ARGS=(
    -e "s|{{I_USER}}|${I_USER}|g"
    -e "s|{{I_HOST}}|${I_HOST}|g"
    -e "s|{{I_TIME}}|${I_TIME}|g"
    -e "s|{{I_OS}}|${I_OS}|g"
    -e "s|{{I_KER}}|${I_KER}|g"
    -e "s|{{I_UP}}|${I_UP}|g"
    -e "s|{{I_UPD}}|${I_UPD}|g"
    -e "s|{{I_PKG}}|${I_PKG}|g"
    -e "s|{{I_AUR}}|${I_AUR}|g"
    -e "s|{{I_SH}}|${I_SH}|g"
    -e "s|{{I_LOC}}|${I_LOC}|g"
    -e "s|{{I_DE}}|${I_DE}|g"
    -e "s|{{I_WM}}|${I_WM}|g"
    -e "s|{{I_TERM}}|${I_TERM}|g"
    -e "s|{{I_FONT}}|${I_FONT}|g"
    -e "s|{{I_CPU}}|${I_CPU}|g"
    -e "s|{{I_GPU}}|${I_GPU}|g"
    -e "s|{{I_RAM}}|${I_RAM}|g"
    -e "s|{{I_SWAP}}|${I_SWAP}|g"
    -e "s|{{I_DISK}}|${I_DISK}|g"
    -e "s|{{I_DISP}}|${I_DISP}|g"
    -e "s|{{I_AUD}}|${I_AUD}|g"
    -e "s|{{I_THM}}|${I_THM}|g"
    -e "s|{{I_ICO}}|${I_ICO}|g"
    -e "s|{{I_CUR}}|${I_CUR}|g"
    -e "s|{{I_PAD}}|${I_PAD}|g"
    -e "s|{{I_IP}}|${I_IP}|g"
    -e "s|{{I_PLAY}}|${I_PLAY}|g"
    -e "s|{{I_MEDIA}}|${I_MEDIA}|g"
    -e "s|{{I_PAL}}|${I_PAL}|g"
    -e "s|{{I_BAT}}|${I_BAT}|g"
    -e "s|{{I_MIC}}|${I_MIC}|g"
)

# Gold variant also needs SCRIPTS_DIR replacement
if [[ "$VARIANT" == "gold" ]]; then
    SED_ARGS+=(-e "s|{{SCRIPTS_DIR}}|${CONFIG_DIR}/scripts|g")
fi

sed "${SED_ARGS[@]}" "$TEMPLATE_FILE" > "$CONFIG_DIR/config.jsonc"

if [[ -f "$CONFIG_DIR/config.jsonc" ]]; then
    log_info "==> Installation complete!"
    printf "Test it by running: "
    log_warn "fastfetch"
    printf "\nTip: Add this to your .bashrc / .zshrc for speed:\n"
    log_warn "alias ff='fastfetch'"
else
    die "[Error] Failed to create config file."
fi
