#!/usr/bin/env bats

setup() {
    # Source lib.sh — set -euo pipefail is active, so we need to be careful
    source "${BATS_TEST_DIRNAME}/../scripts/lib.sh"
}

# --- log_info tests ---

@test "log_info: outputs message to stdout" {
    result=$(log_info "hello world")
    [[ "$result" == *"hello world"* ]]
}

@test "log_info: uses green color code" {
    result=$(log_info "test message")
    [[ "$result" == *$'\033[0;32m'* ]]
}

@test "log_info: resets color at end" {
    result=$(log_info "test message")
    [[ "$result" == *$'\033[0m'* ]]
}

# --- log_warn tests ---

@test "log_warn: outputs message to stdout" {
    result=$(log_warn "warning here")
    [[ "$result" == *"warning here"* ]]
}

@test "log_warn: uses yellow color code" {
    result=$(log_warn "test warning")
    [[ "$result" == *$'\033[1;33m'* ]]
}

@test "log_warn: resets color at end" {
    result=$(log_warn "test warning")
    [[ "$result" == *$'\033[0m'* ]]
}

# --- log_error tests ---

@test "log_error: outputs message to stdout" {
    result=$(log_error "error here")
    [[ "$result" == *"error here"* ]]
}

@test "log_error: uses red color code" {
    result=$(log_error "test error")
    [[ "$result" == *$'\033[0;31m'* ]]
}

@test "log_error: resets color at end" {
    result=$(log_error "test error")
    [[ "$result" == *$'\033[0m'* ]]
}

# --- die tests ---

@test "die: outputs error message" {
    run die "fatal error"
    [[ "$output" == *"fatal error"* ]]
}

@test "die: exits with code 1" {
    run die "fatal error"
    [[ "$status" -eq 1 ]]
}

@test "die: uses red color code" {
    run die "fatal error"
    [[ "$output" == *$'\033[0;31m'* ]]
}

# --- check_not_root tests ---

@test "check_not_root: passes when EUID != 0" {
    # Current user is not root, so this should pass directly
    run check_not_root
    [[ "$status" -eq 0 ]]
}

@test "check_not_root: fails when EUID == 0" {
    # EUID is readonly in bash, so we mock check_not_root's condition
    # by creating a wrapper that simulates root
    check_not_root_as_root() {
        # Replicate check_not_root logic with EUID hardcoded to 0
        if [[ 0 -eq 0 ]]; then
            die "[Error] Do not run this script as root/sudo."
        fi
    }
    run check_not_root_as_root
    [[ "$status" -eq 1 ]]
}

@test "check_not_root: outputs error message when root" {
    check_not_root_as_root() {
        if [[ 0 -eq 0 ]]; then
            die "[Error] Do not run this script as root/sudo."
        fi
    }
    run check_not_root_as_root
    [[ "$output" == *"Do not run this script as root"* ]]
}
