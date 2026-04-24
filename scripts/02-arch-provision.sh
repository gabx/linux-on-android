#!/usr/bin/env bash
# Environment: HOST (orchestrates a GUEST block via proot-distro login)
# Purpose: Initial provisioning of the Arch Linux guest: keyring init,
#          full system upgrade, base-devel install, sentinel file.
# Preconditions:
#   - 01-install-arch.sh completed successfully.
#   - Network connectivity available.
#   - Allow ~5-10 minutes depending on network speed and mirror latency.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

require_cmd proot-distro

# --- verify Arch is installed -------------------------------------------------

ARCH_ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux"

if [[ ! -f "${ARCH_ROOTFS}/etc/os-release" ]]; then
    die "Arch Linux rootfs not found. Run 01-install-arch.sh first."
fi

# --- idempotency check --------------------------------------------------------

SENTINEL="${ARCH_ROOTFS}/var/lib/loa-provisioned"

if [[ -f "${SENTINEL}" ]]; then
    log_info "Arch guest already provisioned. Nothing to do."
    exit 0
fi

# --- provision ----------------------------------------------------------------

log_warn "Provisioning the Arch guest. This will take 5-10 minutes."

# === GUEST block begins ===
# The heredoc marker is single-quoted ('GUEST_SCRIPT') so the host shell
# passes the block verbatim to bash inside the guest without expanding any
# variables or subshells. The || die is on this same line because bash
# evaluates the heredoc as part of this command; after the closing delimiter
# it is too late — a || on its own line would be a syntax error.
proot-distro login archlinux -- bash <<'GUEST_SCRIPT' || die "Guest provisioning failed. Check network connectivity, pacman mirror availability, and keyring initialisation."

# This is a fresh bash process inside the proot. set -euo pipefail from the
# host shell is not inherited — shell options never cross process boundaries —
# so we must re-declare it here to get the same early-exit behaviour.
set -euo pipefail

# Initialise the pacman keyring. Creates /etc/pacman.d/gnupg if absent;
# safe to rerun because it checks for an existing keyring first and skips
# re-initialisation.
pacman-key --init

# Populate the Arch Linux ARM signing keys from the archlinuxarm keyring
# package. Also safe to rerun: it only imports keys not already present.
pacman-key --populate archlinuxarm

# Force a fresh sync of all package databases. -Syy re-downloads even if the
# local db is considered up to date — essential on a fresh rootfs where cached
# db timestamps are meaningless.
pacman -Syy

# Upgrade the keyrings first, as their own isolated step. A weeks-old rootfs
# may carry outdated signing keys; if we run the full upgrade before updating
# them, pacman will fail signature checks on packages signed with newer keys.
pacman -S --needed --noconfirm archlinux-keyring archlinuxarm-keyring

# Full system upgrade with retry for transient mirror desync.
# On a rolling-release distro, the package DB and the mirror's file pool can
# briefly diverge: the DB lists version X+1 but the mirror still serves X.
# A fresh rootfs that lags by weeks is especially prone to this. The retry
# re-syncs the DB so pacman gets fresh URLs before the second attempt.
# Note: -Syyu (double y) forces a DB re-download even if pacman thinks the
# local copy is current, shrinking the sync-to-fetch window where rotation
# can happen.
if ! pacman -Syyu --noconfirm; then
    echo ">>> First upgrade attempt hit mirror desync. Re-syncing and retrying..."
    pacman -Syy
    pacman -Syyu --noconfirm
fi

# Install base-devel after the system is in a fully upgraded, stable state.
# --needed skips packages already installed, making this call idempotent.
pacman -S --needed --noconfirm base-devel

# Write the sentinel file. Its presence tells this script on the next run
# that provisioning completed successfully, so the whole block can be skipped.
# The timestamp records when provisioning happened for debugging purposes.
mkdir -p /var/lib
printf '%s\n' "$(date -u +%FT%TZ) loa-provision 02" > /var/lib/loa-provisioned

GUEST_SCRIPT
# === GUEST block ends ===

log_info "Arch guest provisioned. Next: 03-xfce4-install.sh"
