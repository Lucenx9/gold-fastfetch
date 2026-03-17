#!/usr/bin/env bash
# update-snapshots.sh - Regenerate snapshot files for config generation tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
SNAPSHOT_DIR="$SCRIPT_DIR/snapshots"

mkdir -p "$SNAPSHOT_DIR"

# Generate a config from a template with placeholder substitution
# Usage: generate_config <variant> <use_icons> <output_file>
generate_config() {
    local variant="$1"
    local use_icons="$2"
    local output_file="$3"
    local template="$REPO_ROOT/templates/config-${variant}.jsonc"

    if [[ ! -f "$template" ]]; then
        printf "Error: template not found: %s\n" "$template" >&2
        return 1
    fi

    # Icon keys based on Nerd Font availability (same as install.sh)
    local I_USER I_HOST I_TIME I_OS I_KER I_UP
    local I_UPD I_PKG I_AUR I_SH I_LOC I_DE I_WM
    local I_TERM I_FONT I_CPU I_GPU I_RAM I_SWAP
    local I_DISK I_DISP I_AUD I_THM I_ICO I_CUR
    local I_PAD I_IP I_PLAY I_MEDIA I_PAL I_BAT I_MIC

    if [[ "$use_icons" -eq 1 ]]; then
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

    local SED_ARGS=(
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

    # Gold variant needs SCRIPTS_DIR replacement — use placeholder for snapshots
    if [[ "$variant" == "gold" ]]; then
        SED_ARGS+=(-e "s|{{SCRIPTS_DIR}}|{{SCRIPTS_DIR}}|g")
    fi

    sed "${SED_ARGS[@]}" "$template" > "$output_file"
}

# Generate all 4 snapshot variants
generate_config "gold"    1 "$SNAPSHOT_DIR/config-gold-icons.jsonc"
generate_config "gold"    0 "$SNAPSHOT_DIR/config-gold-noicons.jsonc"
generate_config "minimal" 1 "$SNAPSHOT_DIR/config-minimal-icons.jsonc"
generate_config "minimal" 0 "$SNAPSHOT_DIR/config-minimal-noicons.jsonc"

printf "Snapshots updated in %s:\n" "$SNAPSHOT_DIR"
ls -1 "$SNAPSHOT_DIR"
