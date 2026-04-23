#!/usr/bin/env bash
# Environment: HOST
# Purpose: Install the Arch Linux ARM rootfs via proot-distro.
# Preconditions:
#   - 00-termux-bootstrap.sh completed successfully (proot-distro is installed).
#   - Network connectivity available.
#   - ~600 MB free disk space for the extracted rootfs.

set -euo pipefail

# Same portable SCRIPT_DIR idiom as 00-termux-bootstrap.sh.
# Short version: BASH_SOURCE[0] is this file's path; cd+pwd canonicalises it
# to an absolute path so lib/common.sh is always found, regardless of $PWD.
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

# --- preconditions ------------------------------------------------------------

require_cmd proot-distro

# --- idempotency check --------------------------------------------------------

# `proot-distro list --installed` prints one line per installed distro in the
# form "  * <name>" (two spaces, asterisk, space, name).
#
# IMPORTANT: the grep is the condition of an `if` statement. In bash, set -e
# does NOT fire on the condition of an if/while/until — the shell uses the
# exit code itself to branch, so a non-matching grep (exit 1) just takes the
# else branch instead of aborting the script. This is the correct way to test
# a command that might return non-zero without wanting to abort.
if proot-distro list --installed | grep --quiet '  \* archlinux'; then
    log_info "Arch Linux rootfs is already installed. Nothing to do."
    exit 0
fi

# --- install ------------------------------------------------------------------

log_warn "Downloading Arch Linux ARM rootfs (~200 MB compressed). This will take several minutes on a slow connection."

proot-distro install archlinux \
    || die "proot-distro install failed. Check disk space (~600 MB required) and network connectivity."

log_info "Arch rootfs installed. Next: 02-arch-provision.sh"
