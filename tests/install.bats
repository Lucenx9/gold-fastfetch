#!/usr/bin/env bats

setup() {
    export REPO_ROOT="${BATS_TEST_DIRNAME}/.."
    export SNAPSHOT_DIR="${BATS_TEST_DIRNAME}/snapshots"

    # Create temp directories for isolated install
    TEMP_HOME="$(mktemp -d)"
    export XDG_CONFIG_HOME="$TEMP_HOME/.config"
    export XDG_STATE_HOME="$TEMP_HOME/.local/state"
    mkdir -p "$XDG_CONFIG_HOME" "$XDG_STATE_HOME"

    # Create mock commands directory
    MOCK_BIN="$TEMP_HOME/bin"
    mkdir -p "$MOCK_BIN"

    # Mock fastfetch
    printf '#!/usr/bin/env bash\necho "fastfetch 2.30.1 (Linux)"\n' > "$MOCK_BIN/fastfetch"
    chmod +x "$MOCK_BIN/fastfetch"

    # Mock checkupdates and lspci
    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/checkupdates"
    printf '#!/usr/bin/env bash\nexit 0\n' > "$MOCK_BIN/lspci"
    chmod +x "$MOCK_BIN/checkupdates" "$MOCK_BIN/lspci"

    # Prepend mock bin to PATH
    export PATH="$MOCK_BIN:$PATH"
}

teardown() {
    rm -rf "$TEMP_HOME"
}

# Run install.sh with given args in an isolated environment
run_installer() {
    # Create a shim lib.sh that sources the real one, then overrides check_arch
    local shim_lib="$TEMP_HOME/lib_shim.sh"
    cat > "$shim_lib" << SHIM
#!/usr/bin/env bash
source "$REPO_ROOT/scripts/lib.sh"
check_arch() { return 0; }
# Restore SCRIPT_DIR to repo root (lib.sh overwrites it to scripts/ dir)
SCRIPT_DIR="$REPO_ROOT"
SHIM

    # Create a patched install.sh that uses our shim instead of lib.sh
    local test_installer="$TEMP_HOME/test_install.sh"
    sed 's|source "$SCRIPT_DIR/scripts/lib.sh"|source "'"$shim_lib"'"|' \
        "$REPO_ROOT/install.sh" > "$test_installer"
    chmod +x "$test_installer"

    bash "$test_installer" "$@"
}

# Normalize generated config: replace absolute script paths with {{SCRIPTS_DIR}}
normalize_config() {
    local file="$1"
    local config_dir="${XDG_CONFIG_HOME}/fastfetch"
    sed "s|${config_dir}/scripts|{{SCRIPTS_DIR}}|g" "$file"
}

# --- Snapshot tests ---

@test "snapshot: gold variant with icons matches expected output" {
    run_installer --icons --variant gold
    local generated="$XDG_CONFIG_HOME/fastfetch/config.jsonc"
    [[ -f "$generated" ]]

    normalized="$(normalize_config "$generated")"
    expected="$(cat "$SNAPSHOT_DIR/config-gold-icons.jsonc")"
    [[ "$normalized" == "$expected" ]]
}

@test "snapshot: gold variant without icons matches expected output" {
    run_installer --no-icons --variant gold
    local generated="$XDG_CONFIG_HOME/fastfetch/config.jsonc"
    [[ -f "$generated" ]]

    normalized="$(normalize_config "$generated")"
    expected="$(cat "$SNAPSHOT_DIR/config-gold-noicons.jsonc")"
    [[ "$normalized" == "$expected" ]]
}

@test "snapshot: minimal variant with icons matches expected output" {
    run_installer --icons --variant minimal
    local generated="$XDG_CONFIG_HOME/fastfetch/config.jsonc"
    [[ -f "$generated" ]]

    normalized="$(normalize_config "$generated")"
    expected="$(cat "$SNAPSHOT_DIR/config-minimal-icons.jsonc")"
    [[ "$normalized" == "$expected" ]]
}

@test "snapshot: minimal variant without icons matches expected output" {
    run_installer --no-icons --variant minimal
    local generated="$XDG_CONFIG_HOME/fastfetch/config.jsonc"
    [[ -f "$generated" ]]

    normalized="$(normalize_config "$generated")"
    expected="$(cat "$SNAPSHOT_DIR/config-minimal-noicons.jsonc")"
    [[ "$normalized" == "$expected" ]]
}
