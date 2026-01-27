#!/usr/bin/env bash
# Installs base OS dependencies required for the quickstart image.
set -euo pipefail

requirement_check() { # helper to verify command availability
  local cmd="$1"
  if ! command -v "$cmd" >/dev/null 2>&1; then
    fail "Missing required command: ${cmd}"
  fi
}
fail() { echo "ERROR: $*" >&2; exit 1; } # helper to abort with message
info() { echo "info $*"; }               # helper to print informational logs

# ensure apt operations have privileges
[[ "$(id -u)" -eq 0 ]] || fail "Run this script as root (or via sudo) inside the build context."

# base utilities required by every quickstart
apt-get update
apt-get install -y --no-install-recommends \
  ca-certificates \
  curl \
  build-essential \
  git

info "OS dependencies installed"
