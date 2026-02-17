#!/usr/bin/env bats

# Source disk_detect.sh functions (main loop is guarded)
setup() {
    source "${BATS_TEST_DIRNAME}/../templates/scripts/disk_detect.sh"
}

# --- to_gib tests ---

@test "to_gib: converts GiB value" {
    result=$(to_gib "500G")
    [[ "$result" == "500.0" ]]
}

@test "to_gib: converts Gi suffix" {
    result=$(to_gib "500Gi")
    [[ "$result" == "500.0" ]]
}

@test "to_gib: converts MiB to GiB" {
    result=$(to_gib "1024M")
    [[ "$result" == "1.0" ]]
}

@test "to_gib: converts KiB to GiB" {
    result=$(to_gib "1048576K")
    [[ "$result" == "1.0" ]]
}

@test "to_gib: converts TiB to GiB" {
    result=$(to_gib "1T")
    [[ "$result" == "1024.0" ]]
}

@test "to_gib: converts bytes to GiB" {
    result=$(to_gib "1073741824B")
    [[ "$result" == "1.0" ]]
}

@test "to_gib: handles bare number as bytes" {
    result=$(to_gib "1073741824")
    [[ "$result" == "1.0" ]]
}

@test "to_gib: returns 0.0 for 0B" {
    result=$(to_gib "0B")
    [[ "$result" == "0.0" ]]
}

@test "to_gib: returns 0.0 for dash" {
    result=$(to_gib "-")
    [[ "$result" == "0.0" ]]
}

@test "to_gib: returns 0.0 for empty string" {
    result=$(to_gib "")
    [[ "$result" == "0.0" ]]
}

# --- make_bar tests ---

@test "make_bar: 0% produces no filled segments" {
    result=$(make_bar "0%")
    # Bar should have 0 filled + 10 empty = 10 bar chars total
    bar_chars=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "${#bar_chars}" -eq 10 ]]
}

@test "make_bar: 50% produces 5 filled segments" {
    result=$(make_bar "50%")
    bar_chars=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "${#bar_chars}" -eq 10 ]]
    # 50% => 5 filled, should use GREEN color
    [[ "$result" == *$'\e[32m'* ]]
}

@test "make_bar: 70% uses YELLOW color" {
    result=$(make_bar "70%")
    [[ "$result" == *$'\e[33m'* ]]
}

@test "make_bar: 90% uses RED color" {
    result=$(make_bar "90%")
    [[ "$result" == *$'\e[31m'* ]]
}

@test "make_bar: 100% produces 10 filled segments" {
    result=$(make_bar "100%")
    bar_chars=$(echo "$result" | sed 's/\x1b\[[0-9;]*m//g')
    [[ "${#bar_chars}" -eq 10 ]]
    # 100% => RED color
    [[ "$result" == *$'\e[31m'* ]]
}

# --- get_label tests ---

@test "get_label: returns 'System' for /" {
    result=$(get_label "/" "")
    [[ "$result" == "System" ]]
}

@test "get_label: returns 'Home' for /home" {
    result=$(get_label "/home" "")
    [[ "$result" == "Home" ]]
}

@test "get_label: returns filesystem label when present" {
    result=$(get_label "/" "ARCHLINUX")
    [[ "$result" == "Archlinux" ]]
}

@test "get_label: ignores dash label" {
    result=$(get_label "/" "-")
    [[ "$result" == "System" ]]
}

@test "get_label: returns mount basename for /mnt/*" {
    result=$(get_label "/mnt/data" "")
    [[ "$result" == "data" ]]
}

@test "get_label: capitalizes filesystem label" {
    result=$(get_label "/mnt/whatever" "MY_DATA")
    [[ "$result" == "My_data" ]]
}

# --- parse_pairs tests ---

@test "parse_pairs: parses full findmnt -P output" {
    mount="" fstype="" size="" used="" percent="" fslabel=""
    parse_pairs 'TARGET="/" FSTYPE="ext4" SIZE="500G" USED="250G" USE%="50%" LABEL="root"'
    [[ "$mount" == "/" ]]
    [[ "$fstype" == "ext4" ]]
    [[ "$size" == "500G" ]]
    [[ "$used" == "250G" ]]
    [[ "$percent" == "50%" ]]
    [[ "$fslabel" == "root" ]]
}

@test "parse_pairs: handles empty fields" {
    mount="" fstype="" size="" used="" percent="" fslabel=""
    parse_pairs 'TARGET="/home" FSTYPE="btrfs" SIZE="1T" USED="500G" USE%="50%" LABEL=""'
    [[ "$mount" == "/home" ]]
    [[ "$fstype" == "btrfs" ]]
    [[ "$fslabel" == "" ]]
}

@test "parse_pairs: handles missing LABEL field" {
    mount="" fstype="" size="" used="" percent="" fslabel=""
    parse_pairs 'TARGET="/mnt/data" FSTYPE="xfs" SIZE="2T" USED="1T" USE%="50%"'
    [[ "$mount" == "/mnt/data" ]]
    [[ "$fstype" == "xfs" ]]
    [[ "$fslabel" == "" ]]
}
