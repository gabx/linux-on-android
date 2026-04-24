#!/usr/bin/env bash
# Environment: HOST (orchestrates a GUEST block via proot-distro login)
# Purpose: Install the XFCE4 desktop environment inside the Arch guest.
# Preconditions:
#   - 02-arch-provision.sh completed successfully.
#   - Network connectivity available.
#   - ~300 MB free disk space inside the Arch rootfs.
#   - Allow ~5-15 minutes depending on network speed and mirror latency.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

require_cmd proot-distro

# --- verify prerequisites -----------------------------------------------------

ARCH_ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux"

if [[ ! -f "${ARCH_ROOTFS}/etc/os-release" ]]; then
    die "Arch Linux rootfs not found. Run 01-install-arch.sh first."
fi

if [[ ! -f "${ARCH_ROOTFS}/var/lib/loa-provisioned" ]]; then
    die "Arch guest is not provisioned. Run 02-arch-provision.sh first."
fi

# --- idempotency check --------------------------------------------------------

XFCE_SENTINEL="${ARCH_ROOTFS}/var/lib/loa-xfce4-installed"

if [[ -f "${XFCE_SENTINEL}" ]]; then
    log_info "XFCE4 already installed in guest. Nothing to do."
    exit 0
fi

# --- install ------------------------------------------------------------------

log_warn "Installing XFCE4 inside the Arch guest (~150-250 MB). This will take 5-15 minutes."

# === GUEST block begins ===
proot-distro login archlinux -- bash <<'GUEST_SCRIPT' || die "XFCE4 installation failed. Check network connectivity, pacman mirror availability, and keyring state."

set -euo pipefail

# Arch's cardinal rule: never install without a fresh DB sync. Installing
# against a stale DB can pull a package version that no longer matches what
# the mirror serves, causing 404s or broken partial upgrades.
pacman -Syy

# Install the full xfce4 group plus xfce4-terminal explicitly.
# xfce4-terminal is already in the xfce4 group today, but we list it by name
# as a statement of intent: this package is a first-class requirement, not an
# implicit transitive dep we happen to get. If the group ever drops it, the
# explicit entry ensures it stays installed rather than silently disappearing.
# --noconfirm accepts the default choice for any optional dependency prompts
# (e.g. polkit provider selection).
if ! pacman -S --needed --noconfirm xfce4 xfce4-terminal; then
    echo ">>> First install attempt hit mirror desync. Re-syncing and retrying..."
    pacman -Syy
    pacman -S --needed --noconfirm xfce4 xfce4-terminal
fi

mkdir -p /var/lib
printf '%s\n' "$(date -u +%FT%TZ) loa-xfce4 03" > /var/lib/loa-xfce4-installed

GUEST_SCRIPT
# === GUEST block ends ===

log_info "XFCE4 installed. Next: 04-start-desktop.sh"
