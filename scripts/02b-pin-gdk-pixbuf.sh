#!/usr/bin/env bash
# Environment: HOST (orchestrates a GUEST block via proot-distro login)
# Purpose: Downgrade gdk-pixbuf2 to 2.42.12-2 (pre-glycin) and pin it via
#          IgnorePkg in /etc/pacman.conf so future upgrades never re-introduce glycin.
# Preconditions:
#   - 02-arch-provision.sh completed successfully.
#   - gdk-pixbuf2-2.42.12-2-aarch64.pkg.tar.xz present at $HOME in Termux.
#     Push from dev station:
#       adb push gdk-pixbuf2-2.42.12-2-aarch64.pkg.tar.xz \
#                /data/data/com.termux/files/home/

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

require_cmd proot-distro

# --- paths --------------------------------------------------------------------

ARCH_ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux"
SENTINEL="${ARCH_ROOTFS}/var/lib/loa-gdk-pixbuf-pinned"
PKG_FILENAME="gdk-pixbuf2-2.42.12-2-aarch64.pkg.tar.xz"
PKG_HOST_PATH="${HOME}/${PKG_FILENAME}"

# --- verify prerequisites -----------------------------------------------------

if [[ ! -f "${ARCH_ROOTFS}/var/lib/loa-provisioned" ]]; then
    die "Arch guest is not provisioned. Run 02-arch-provision.sh first."
fi

# --- idempotency check --------------------------------------------------------

if [[ -f "${SENTINEL}" ]]; then
    log_info "gdk-pixbuf2 already pinned to 2.42.12-2. Nothing to do."
    exit 0
fi

# --- verify package file ------------------------------------------------------

if [[ ! -f "${PKG_HOST_PATH}" ]]; then
    die "${PKG_FILENAME} not found at ${PKG_HOST_PATH}. Push it first: adb push ${PKG_FILENAME} /data/data/com.termux/files/home/"
fi

# --- downgrade and pin --------------------------------------------------------

log_info "Installing gdk-pixbuf2-2.42.12-2 and pinning via IgnorePkg..."

# --bind exposes a single file from the host filesystem inside the guest at the
# given path. We mount the package archive into /tmp inside the guest so pacman
# can install it from a local path without network access.
proot-distro login archlinux \
    --bind "${PKG_HOST_PATH}:/tmp/${PKG_FILENAME}" \
    -- bash <<'GUEST_SCRIPT' || die "Guest block failed. Check pacman output above."
set -euo pipefail

PKG_FILENAME="gdk-pixbuf2-2.42.12-2-aarch64.pkg.tar.xz"
PACMAN_CONF="/etc/pacman.conf"
SENTINEL="/var/lib/loa-gdk-pixbuf-pinned"

# -U / --upgrade installs a package directly from a local file. --noconfirm
# skips the interactive "Proceed with installation?" prompt, which cannot be
# answered inside a non-interactive script.
pacman --upgrade --noconfirm "/tmp/${PKG_FILENAME}"

# Pin the package so `pacman -Syu` skips it on future full upgrades.
# IgnorePkg in pacman.conf takes a space-separated package list.
# Three cases:
#   1. gdk-pixbuf2 already listed   -> do nothing.
#   2. IgnorePkg line exists but lacks gdk-pixbuf2 -> append to that line.
#   3. No uncommented IgnorePkg line -> insert one after the [options] header.
if grep --quiet '^IgnorePkg.*gdk-pixbuf2' "${PACMAN_CONF}"; then
    : # already pinned, nothing to do
elif grep --quiet '^IgnorePkg' "${PACMAN_CONF}"; then
    # sed --in-place edits the file in-place (no temp file visible to us).
    # 's/$/ gdk-pixbuf2/' matches end-of-line and appends the package name.
    sed --in-place '/^IgnorePkg/ s/$/ gdk-pixbuf2/' "${PACMAN_CONF}"
else
    # The /a command appends text on a new line after the matched line.
    sed --in-place '/^\[options\]/a IgnorePkg = gdk-pixbuf2' "${PACMAN_CONF}"
fi

mkdir --parents /var/lib
printf '%s\n' "$(date -u +%FT%TZ) loa-gdk-pixbuf-pinned 02b" > "${SENTINEL}"
GUEST_SCRIPT
# === GUEST block ends ===

log_info "gdk-pixbuf2 pinned. Run 04-start-desktop.sh to test."
