#!/usr/bin/env bash
set -euo pipefail
export LC_ALL=C.UTF-8

GREEN=$'\e[32m'
YELLOW=$'\e[33m'
RED=$'\e[31m'
GRAY=$'\e[90m'
RESET=$'\e[0m'

make_bar() {
    local pct="${1%\%}"
    if ! [[ "$pct" =~ ^[0-9]+$ ]]; then pct=0; fi
    local filled=$((pct * 10 / 100))
    local empty=$((10 - filled))
    local color="$GREEN"
    if ((pct >= 90)); then color="$RED"; elif ((pct >= 70)); then color="$YELLOW"; fi
    local bar=""; for ((i=0; i<filled; i++)); do bar+="━"; done
    printf "%s%s%s" "$color" "$bar" "$RESET"
    bar=""; for ((i=0; i<empty; i++)); do bar+="━"; done
    printf "%s%s%s" "$GRAY" "$bar" "$RESET"
}

get_label() {
    local mount="$1"
    local fslabel="$2"
    if [[ -n "$fslabel" && "$fslabel" != "-" ]]; then
        local lower="${fslabel,,}"
        echo "${lower^}"
        return
    fi
    case "${mount,,}" in
        /) echo "System" ;; /home) echo "Home" ;; /mnt/*) echo "${mount##*/}" ;; *) echo "${mount##*/}" ;;
    esac
}

to_gib() {
    local val="$1"
    [[ "$val" == "0B" || "$val" == "-" || -z "$val" ]] && { echo "0.0"; return; }
    # Extract numeric part and suffix more reliably
    local num suffix
    if [[ "$val" =~ ^([0-9.]+)([GMKTB]i?)?$ ]]; then
        num="${BASH_REMATCH[1]}"
        suffix="${BASH_REMATCH[2]}"
    else
        echo "0.0"
        return
    fi
    # Handle both "G" and "Gi" style suffixes
    case "${suffix%%i}" in
        G) awk "BEGIN{printf \"%.1f\", $num}" ;;
        M) awk "BEGIN{printf \"%.1f\", $num/1024}" ;;
        K) awk "BEGIN{printf \"%.1f\", $num/1048576}" ;;
        T) awk "BEGIN{printf \"%.1f\", $num*1024}" ;;
        B|"") awk "BEGIN{printf \"%.1f\", $num/1073741824}" ;;
        *) awk "BEGIN{printf \"%.1f\", $num}" ;;
    esac
}

parse_pairs() {
    local line="$1" key val
    while [[ $line =~ ^([A-Z0-9.%_]+)=\"([^\"]*)\"[[:space:]]*(.*)$ ]]; do
        key="${BASH_REMATCH[1]}"
        val="${BASH_REMATCH[2]}"
        line="${BASH_REMATCH[3]}"
        case "$key" in
            TARGET) mount="$val" ;;
            FSTYPE) fstype="$val" ;;
            SIZE) size="$val" ;;
            USED) used="$val" ;;
            USE%) percent="$val" ;;
            LABEL) fslabel="$val" ;;
        esac
    done
}

# Guard: only run main logic when executed directly (not sourced)
if [[ "${BASH_SOURCE[0]}" == "$0" ]]; then

declare -A seen_sizes
first=1; disk_num=1

while IFS= read -r line; do
    [[ -z "$line" ]] && continue
    mount=""; fstype=""; size=""; used=""; percent=""; fslabel=""
    parse_pairs "$line"

    # Validate required fields exist
    [[ -z "$mount" || -z "$fstype" || -z "$size" || -z "$used" || -z "$percent" ]] && continue

    [[ "$mount" =~ ^/boot ]] && continue
    [[ "$mount" =~ ^/run ]] && continue
    [[ "$mount" =~ ^/dev ]] && continue
    [[ "$mount" =~ ^/sys ]] && continue
    [[ "$mount" =~ ^/proc ]] && continue
    [[ "$mount" =~ ^/var ]] && continue
    [[ "$mount" =~ \.snapshots ]] && continue
    # [[ "$mount" == "/home" ]] && continue

    # Deduplicate btrfs subvolumes by size
    if [[ "$fstype" == "btrfs" ]]; then
        if [[ -n "${seen_sizes[$size]:-}" ]]; then continue; fi
        seen_sizes[$size]=1
    fi

    size_gib=$(to_gib "$size")
    used_gib=$(to_gib "$used")
    label=$(get_label "$mount" "$fslabel")
    bar=$(make_bar "$percent")

    if [[ $first -eq 0 ]]; then
        if (( (disk_num - 1) % 3 == 0 )); then printf "\n                        %s│%s                 " "$GREEN" "$RESET"; else printf " │ "; fi
    fi
    first=0
    fstype_disp="${fstype:-N/A}"
    printf "%s [%s] %s/%sG (%s) %s" "$label" "$fstype_disp" "$used_gib" "$size_gib" "$percent" "$bar"
    ((disk_num++))
done < <(timeout 2s findmnt -n -b -P -o TARGET,FSTYPE,SIZE,USED,USE%,LABEL --real --types notmpfs,nofuse.sshfs,nonfs,nocifs 2>/dev/null)

# Handle case where no disks were found
if [[ $first -eq 1 ]]; then
    echo "N/A (no disks detected)"
else
    printf '\n'
fi

fi # end source guard
