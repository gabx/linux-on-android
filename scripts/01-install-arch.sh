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

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

# --- preconditions ------------------------------------------------------------

require_cmd proot-distro

# --- idempotency check --------------------------------------------------------

# We test the filesystem directly rather than parsing proot-distro output.
# Reasons:
#   1. CLI output format (flags, text, ANSI codes) can change between
#      proot-distro versions; a file path is a stable contract.
#   2. We test /etc/os-release specifically, not just the directory: proot-distro
#      creates the rootfs directory before extraction begins, so the directory
#      alone can exist in a half-installed state. os-release is written by the
#      Arch tarball itself and is absent until extraction completes successfully.
ARCH_ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux"

if [[ -f "${ARCH_ROOTFS}/etc/os-release" ]]; then
    log_info "Arch Linux rootfs is already installed. Nothing to do."
    exit 0
fi

# --- install ------------------------------------------------------------------

log_warn "Downloading Arch Linux ARM rootfs (~200 MB compressed). This will take several minutes on a slow connection."

proot-distro install archlinux \
    || die "proot-distro install failed. Check disk space (~600 MB required) and network connectivity."

log_info "Arch rootfs installed. Next: 02-arch-provision.sh"
