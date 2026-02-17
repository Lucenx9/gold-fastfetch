#!/usr/bin/env bash
set -euo pipefail

CACHE_DIR="${XDG_CACHE_HOME:-$HOME/.cache}/fastfetch"
CACHE_FILE="$CACHE_DIR/updates.txt"
LOCK_FILE="$CACHE_DIR/updates.lock"
CACHE_TTL=1800
LOCK_TIMEOUT=300

mkdir -p "$CACHE_DIR"

if [[ -e /var/lib/pacman/db.lck ]]; then
    echo "Repo: Locked | AUR: ?"
    exit 0
fi

have() { command -v "$1" >/dev/null 2>&1; }

count_updates() {
  local off=0 aur=0
  if have checkupdates; then
    off=$(timeout 10s checkupdates 2>/dev/null | wc -l || true); off=${off//[[:space:]]/}; off=${off:-0}
  else off="0"; fi

  if have yay; then
    aur=$(timeout 10s yay -Qua 2>/dev/null | wc -l || true); aur=${aur//[[:space:]]/}; aur=${aur:-0}
  elif have paru; then
    aur=$(timeout 10s paru -Qua 2>/dev/null | wc -l || true); aur=${aur//[[:space:]]/}; aur=${aur:-0}
  else aur="0"; fi
  echo "Repo: $off | AUR: $aur" > "$CACHE_FILE"
}

should_refresh() {
  [[ ! -f "$CACHE_FILE" ]] && return 0

  local file_time pacman_time now age
  file_time=$(stat -c %Y "$CACHE_FILE" 2>/dev/null || echo 0)

  # Smart Check: If pacman DB changed recently, refresh immediately
  pacman_time=$(stat -c %Y "/var/lib/pacman/local" 2>/dev/null || echo 0)
  if (( pacman_time > file_time )); then return 0; fi

  now=$(date +%s)
  age=$((now - file_time))
  if (( age > CACHE_TTL )); then
    return 0
  else
    return 1
  fi
}

if [[ -d "$LOCK_FILE" ]]; then
  lock_age=$(( $(date +%s) - $(stat -c %Y "$LOCK_FILE" 2>/dev/null || echo 0) ))
  if (( lock_age > LOCK_TIMEOUT )); then rmdir "$LOCK_FILE" 2>/dev/null || true; fi
fi

# First run: sync, subsequent: async
if [[ ! -f "$CACHE_FILE" ]]; then
  count_updates
elif should_refresh; then
  ( if mkdir "$LOCK_FILE" 2>/dev/null; then
      trap 'rmdir "$LOCK_FILE" 2>/dev/null || true' EXIT
      count_updates
    fi ) >/dev/null 2>&1 &
fi

# Ensure cache file exists before reading
if [[ -f "$CACHE_FILE" ]]; then
  cat "$CACHE_FILE"
else
  echo "Repo: ? | AUR: ?"
fi
