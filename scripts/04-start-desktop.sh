#!/usr/bin/env bash
# Environment: HOST (orchestrates a GUEST block via proot-distro login)
# Purpose: Start a full XFCE4 desktop session: launch termux-x11 on the HOST,
#          then run startxfce4 inside the Arch guest via proot-distro.
#          Blocks until the XFCE session ends (logout or Ctrl+C).
# Preconditions:
#   - 03-xfce4-install.sh completed successfully.
#   - Termux:X11 Android app is open on screen (launched manually by user).

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# shellcheck source=lib/common.sh
source "${SCRIPT_DIR}/lib/common.sh"

# --- guard --------------------------------------------------------------------

detect_env
if [[ "${LOA_ENV}" != "host" ]]; then
    die "This script must run inside Termux on the device (HOST). Detected: ${LOA_ENV}."
fi

require_cmd proot-distro
require_cmd termux-x11

# --- verify prerequisites -----------------------------------------------------

ARCH_ROOTFS="${PREFIX}/var/lib/proot-distro/installed-rootfs/archlinux"

if [[ ! -f "${ARCH_ROOTFS}/etc/os-release" ]]; then
    die "Arch Linux rootfs not found. Run 01-install-arch.sh first."
fi

if [[ ! -f "${ARCH_ROOTFS}/var/lib/loa-provisioned" ]]; then
    die "Arch guest is not provisioned. Run 02-arch-provision.sh first."
fi

if [[ ! -f "${ARCH_ROOTFS}/var/lib/loa-xfce4-installed" ]]; then
    die "XFCE4 not installed in guest. Run 03-xfce4-install.sh first."
fi

# --- cleanup ------------------------------------------------------------------

# Declared at the top so cleanup() can reference it even if the script exits
# before termux-x11 is started. An empty string means "nothing to kill".
X11_PID=""

cleanup() {
    log_info "Stopping desktop session..."
    # kill -0 tests liveness without sending a real signal; we only attempt to
    # kill if the process is still running. The || true is essential: under
    # set -e, a failing kill (process already gone) would abort cleanup itself,
    # which is exactly the wrong moment to stop running cleanup logic.
    if [[ -n "${X11_PID}" ]] && kill -0 "${X11_PID}" 2>/dev/null; then
        kill "${X11_PID}" 2>/dev/null || true
    fi
}

# EXIT catches any script termination reason (normal exit, die, unbound var,
# etc.). INT catches Ctrl+C from the user. TERM catches a polite kill sent by
# another process. All three route to the same cleanup so nothing leaks.
trap cleanup EXIT INT TERM

# --- pre-flight: evict stale instances ----------------------------------------

log_info "Cleaning up any existing termux-x11 instance..."
# pkill -x matches the exact command name (no substring matches).
# || true handles the common case where no matching process exists:
# pkill exits non-zero when it finds nothing, and set -e would otherwise
# abort the script here — a false alarm.
pkill -x termux-x11 2>/dev/null || true
sleep 1

# --- start termux-x11 ---------------------------------------------------------

log_info "Starting termux-x11 server (display :0)..."
termux-x11 :0 &
# $! holds the PID of the most recently backgrounded job. It is only valid
# immediately after the &; a later subshell or pipeline would overwrite it.
X11_PID=$!
sleep 2

# kill -0 does not kill; it tests whether we can send a signal to the process,
# which is the standard POSIX idiom for a liveness check. If termux-x11 exited
# immediately (missing Android app, display already in use, etc.), we die here
# with a message that tells the user exactly what to fix.
if ! kill -0 "${X11_PID}" 2>/dev/null; then
    die "termux-x11 exited immediately. Is the Termux:X11 Android app open? Launch it before running this script."
fi

# --- launch XFCE4 session (blocking) ------------------------------------------

log_info "Starting XFCE4 session. Close XFCE or press Ctrl+C to stop."

# === GUEST block begins ===
# --shared-tmp exposes the host's /tmp inside the guest. The X11 socket lives
# at /tmp/.X11-unix/X0; without this flag the guest has its own private /tmp
# and cannot find the socket, so every X client silently fails to connect.
#
# The heredoc marker is single-quoted (<<'GUEST_SCRIPT') so the host shell
# passes the block verbatim to bash inside the guest. DISPLAY=:0 must be
# exported inside the guest environment, not pre-expanded by the host shell.
proot-distro login archlinux --shared-tmp -- bash <<'GUEST_SCRIPT'
set -euo pipefail

export DISPLAY=:0

# dbus-run-session starts a private D-Bus session bus, waits until the daemon
# is ready, exports DBUS_SESSION_BUS_ADDRESS into the environment, then execs
# the given command. When startxfce4 exits, the bus daemon exits with it.
# dbus-launch (the legacy alternative) is fragile without systemd: it spawns
# the daemon but does not guarantee readiness before exec-ing the child, and
# in proot the socket path it chooses is sometimes unreachable by child
# processes — producing the silent "unable to connect to D-Bus" failures.
# -- separates dbus-run-session flags from the command to run.
dbus-run-session -- startxfce4
GUEST_SCRIPT
# === GUEST block ends ===

log_info "Desktop session ended."
