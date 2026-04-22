# linux-on-android

Arch Linux + XFCE4 on Android via Termux (F-Droid) + proot-distro + termux-x11.

**Target device:** Pixel 7a (aarch64), Android 14+.
**Root:** Magisk supported but NOT required.

## Stack

- **Termux** (F-Droid build, not Play Store) — Android terminal + base userland
- **proot-distro** — userspace chroot wrapper, no root needed
- **Arch Linux ARM** — the guest distribution
- **XFCE4** — desktop environment inside the proot
- **termux-x11** — X server running on Android (no VNC)

## Repository layout

```
linux-on-android/
├── Makefile              # orchestration (dev / host / guest targets)
├── README.md
├── .editorconfig
├── .gitignore
├── .claude/
│   └── CLAUDE.md         # project context for Claude CLI
├── docs/                 # step-by-step setup notes
└── scripts/
    ├── lib/
    │   └── common.sh     # logging + env detection helpers
    └── NN-*.sh           # numbered, idempotent setup scripts
```

## Conventions

- Scripts are **bash** (`#!/usr/bin/env bash`), `set -euo pipefail`.
- Scripts are **numbered** and **idempotent** — safe to re-run.
- Each script header declares its execution context:
  - `DEV` → runs on the dev station (Arch Linux)
  - `HOST` → runs inside Termux on the device
  - `GUEST` → runs inside the proot (Arch guest)
- No `sudo`, no root on device side.

## Workflow

1. Develop on the dev station (Arch + zsh + WezTerm + Neovim).
2. Commit & push.
3. `git pull` inside Termux at `~/projects/loa`.
4. Run the relevant `make` target.
5. Feed logs back to the dev station if something breaks.

## Quickstart

Work in progress. See `docs/` for detailed setup once populated.

## Status

- [ ] `scripts/lib/common.sh` — shared helpers
- [ ] `00-termux-bootstrap.sh` — Termux host bootstrap (HOST)
- [ ] `01-install-arch.sh` — install Arch rootfs via proot-distro (HOST)
- [ ] `02-arch-provision.sh` — base provisioning inside Arch (GUEST)
- [ ] `03-xfce4-install.sh` — XFCE4 + deps (GUEST)
- [ ] `04-start-desktop.sh` — launch termux-x11 + XFCE4 session (HOST)
- [ ] `Makefile` — wrap everything with tidy targets
- [ ] `docs/` — step-by-step guides

## License

MIT - see [LICENSE](LICENSE)