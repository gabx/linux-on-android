# linux-on-android

Arch Linux + XFCE4 on Android via Termux (F-Droid) + proot-distro + termux-x11.

**Tested device:** Pixel 7a (aarch64), Android 14+.
**Likely compatible** (untested): Pixel 6 family and later (aarch64, Android 14+).
Devices with 6 GB RAM (e.g. Pixel 6a) may hit OOM more easily under
load — see [docs/known-issues.md](docs/known-issues.md) entry 4.
**Root:** Magisk supported but NOT required.

## Stack

- **Termux** (F-Droid build, not Play Store) — Android terminal + base userland
- **proot-distro** — userspace chroot wrapper, no root needed
- **Arch Linux ARM** — the guest distribution
- **XFCE4** — desktop environment inside the proot
- **termux-x11** — X server running on Android (no VNC)

## Prerequisites

- Termux from F-Droid (NOT Play Store — see footnote).
- Termux:X11 from F-Droid or its GitHub releases.
- ADB on the dev station for pushing files / pulling logs.
- ~5 GB free on the device for the rootfs.
- Internet during initial install (mirrors, package downloads).

> **Footnote:** Termux on the Play Store has been unmaintained since the Bintray
> shutdown. F-Droid is the only supported channel.

## Repository layout

```
linux-on-android/
├── Makefile
├── README.md
├── LICENSE
├── .editorconfig
├── .gitignore
├── .claude/
│   └── CLAUDE.md             # project context for Claude CLI
├── docs/
│   └── troubleshooting.md    # symptom / cause / fix reference
└── scripts/
    ├── lib/
    │   └── common.sh         # logging + env detection helpers
    └── NN-*.sh               # numbered, idempotent setup scripts
```

## Conventions

- Scripts are **bash** (`#!/usr/bin/env bash`), `set -euo pipefail`.
- Scripts are **numbered** and **idempotent** — safe to re-run.
- Each script header declares its execution context:
  - `DEV` → runs on the dev station (Arch Linux)
  - `HOST` → runs inside Termux on the device
  - `GUEST` → runs inside the proot (Arch guest)
- No `sudo`, no root on the device side.
- All scripts source `scripts/lib/common.sh` for shared logging (`log_info`,
  `log_warn`, `log_err`, `die`) and environment detection (`detect_env`).

## Quickstart

1. **Install Termux + Termux:X11 from F-Droid.**

2. **Clone or copy the repository to `~/projects/loa` on the device.**

3. **In Termux:**
   ```bash
   cd ~/projects/loa
   bash scripts/00-termux-bootstrap.sh
   bash scripts/01-install-arch.sh
   bash scripts/02-arch-provision.sh
   ```

4. **Continue:**
   ```bash
   bash scripts/02b-pin-gdk-pixbuf.sh   # auto-downloads gdk-pixbuf2 from the v1.0 release
   bash scripts/03-xfce4-install.sh
   ```

5. **Open the Termux:X11 Android app** (black screen with cursor — leave it open).

6. **In Termux:**
   ```bash
   bash scripts/04-start-desktop.sh
   ```

7. **Wait 30–60 seconds**, then switch to the Termux:X11 app.

> **Tip:** each `bash scripts/NN-*.sh` invocation has an equivalent
> `make` target. Run `make help` for the list. Functionally identical;
> use whichever you prefer.

For interaction quirks (Trackpad input model) and other gotchas,
see [docs/troubleshooting.md](docs/troubleshooting.md).

## Known limitations

- XFCE elements (text, icons) appear small on a phone screen.
  Workaround: Termux:X11 → Output → Display scale (e.g. 190%).
- Termux:X11 in Trackpad mode: cursor follows finger; tap clicks at the
  *cursor position*, not the finger position.
- Multiple proots + scrcpy + XFCE can saturate RAM on Pixel 7a
  (Android Low Memory Killer).
- See `docs/troubleshooting.md` for symptoms and fixes.
- See `docs/known-issues.md` for open questions and future work directions.

## Status

- [x] `scripts/lib/common.sh` — shared helpers
- [x] `00-termux-bootstrap.sh` — Termux host bootstrap (HOST)
- [x] `01-install-arch.sh` — install Arch rootfs via proot-distro (HOST)
- [x] `02-arch-provision.sh` — base provisioning inside Arch (HOST → GUEST)
- [x] `02b-pin-gdk-pixbuf.sh` — pin gdk-pixbuf2 pre-glycin (HOST → GUEST)
- [x] `03-xfce4-install.sh` — XFCE4 + deps (HOST → GUEST)
- [x] `04-start-desktop.sh` — launch termux-x11 + XFCE4 session (HOST)
- [x] `docs/troubleshooting.md` — symptom/cause/fix reference
- [x] `Makefile` — wrap everything with tidy targets

## License

MIT — see [LICENSE](LICENSE).
