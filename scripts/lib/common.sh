#!/usr/bin/env bash
# Environment: DEV / HOST / GUEST (source-only library — do not execute directly)

# Portable source guard: works in bash (BASH_SOURCE) and zsh (ZSH_EVAL_CONTEXT).
if [ -n "${BASH_SOURCE+x}" ]; then
    [ "${BASH_SOURCE[0]}" = "$0" ] && { printf 'common.sh must be sourced, not executed.\n' >&2; exit 1; }
elif [ -n "${ZSH_EVAL_CONTEXT+x}" ]; then
    case "$ZSH_EVAL_CONTEXT" in
        *:file*) ;;
        *) printf 'common.sh must be sourced, not executed.\n' >&2; exit 1 ;;
    esac
fi

# Emit an informational message to stdout with a timestamp.
log_info() {
    local ts
    ts=$(date '+%H:%M:%S')
    if [ -t 1 ]; then
        printf '\033[0;32m[%s] INFO:\033[0m %s\n' "$ts" "$*"
    else
        printf '[%s] INFO: %s\n' "$ts" "$*"
    fi
}

# Emit a warning message to stderr with a timestamp.
log_warn() {
    local ts
    ts=$(date '+%H:%M:%S')
    if [ -t 2 ]; then  # fd 2 = stderr, which is where this function writes
        printf '\033[0;33m[%s] WARN:\033[0m %s\n' "$ts" "$*" >&2
    else
        printf '[%s] WARN: %s\n' "$ts" "$*" >&2
    fi
}

# Emit an error message to stderr with a timestamp.
log_err() {
    local ts
    ts=$(date '+%H:%M:%S')
    if [ -t 2 ]; then  # fd 2 = stderr, which is where this function writes
        printf '\033[0;31m[%s] ERR:\033[0m %s\n' "$ts" "$*" >&2
    else
        printf '[%s] ERR: %s\n' "$ts" "$*" >&2
    fi
}

# Log an error and exit; code defaults to 1.
die() {
    local msg="${1:-}"
    local code="${2:-1}"
    log_err "$msg"
    exit "$code"
}

# Verify a command exists in PATH, die with an actionable message otherwise.
require_cmd() {
    command -v "$1" >/dev/null 2>&1 || die "required command '$1' not found in PATH."
}

# Detect the runtime environment and export LOA_ENV (host | guest | dev).
detect_env() {
    if [[ "${PREFIX:-}" == *com.termux* ]]; then
        export LOA_ENV=host
    elif grep --quiet --ignore-case 'Android' /proc/version 2>/dev/null; then
        # proot-distro does not fake /proc/version; the host kernel string
        # ("Android") is visible from inside the proot, but not on a native
        # Arch dev station — making this a reliable guest-only signal.
        export LOA_ENV=guest
    else
        export LOA_ENV=dev
    fi
}

# Detect the system package manager and export LOA_PKG (apt | pacman | dnf | zypper | unknown).
detect_pkg_mgr() {
    if command -v pacman >/dev/null 2>&1; then
        export LOA_PKG=pacman
    elif command -v apt >/dev/null 2>&1; then
        export LOA_PKG=apt
    elif command -v dnf >/dev/null 2>&1; then
        export LOA_PKG=dnf
    elif command -v zypper >/dev/null 2>&1; then
        export LOA_PKG=zypper
    else
        export LOA_PKG=unknown
    fi
}
