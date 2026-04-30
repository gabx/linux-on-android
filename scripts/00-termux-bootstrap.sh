#!/usr/bin/env bash
# Environment: HOST
# Purpose: Prepare a fresh Termux (F-Droid) installation to host proot-distro
#          and termux-x11.
# Preconditions:
#   - Termux installed from F-Droid (Play Store build is incompatible).
#   - Network connectivity available.

set -euo pipefail

# Resolve the absolute path to the directory that contains this script.
#
# BASH_SOURCE[0] is the path to this file as the shell sees it — it may be
# relative (e.g. "./scripts/00-…") or absolute, depending on how the user
# invoked it. The subshell `cd "$(dirname …)" && pwd` walks into that
# directory and asks the shell for its canonical absolute path, so the
# result is the same no matter where the caller was standing.
#
# We need this to find lib/common.sh reliably, because plain relative paths
# like "../lib/common.sh" are relative to $PWD, not to the script itself.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

# --- step 1: refresh & upgrade ------------------------------------------------

log_info "Refreshing package index..."
pkg update \
    || die "pkg update failed. Check network connectivity and Termux repository settings."

log_info "Upgrading installed packages..."
pkg upgrade -y \
    || die "pkg upgrade failed. Check network connectivity and Termux repository settings."

# --- step 2: enable X11 repo --------------------------------------------------

# x11-repo adds the Termux X11 package channel. It must be installed before
# termux-x11-nightly is available to pkg.
log_info "Enabling the Termux X11 package repository..."
pkg install -y x11-repo \
    || die "Failed to install x11-repo. Check network or Termux repository settings."

# --- step 3: install essential packages ---------------------------------------

# pkg install -y is naturally idempotent: already-installed packages are
# reported as up-to-date and skipped without error, so re-running this
# script on a partially provisioned device is safe.
log_info "Installing proot-distro, termux-x11-nightly, git..."
pkg install -y \
    proot-distro \
    termux-x11-nightly \
    git \
    || die "Package installation failed. Check network or Termux repository settings."

log_info "Bootstrap complete. Continue with: make host-provision"
