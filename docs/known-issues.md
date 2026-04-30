# Known Issues

Open or unresolved limitations. Distinct from
[docs/troubleshooting.md](docs/troubleshooting.md), which covers
user-facing symptoms with workarounds. This file is contributor /
informed-user oriented: what doesn't work ideally, what would
deserve future work.

---

### 1. XFCE elements appear small on phone screens

**Status:** Cosmetic limitation, partial workaround available.

XFCE renders text and icons at default Linux desktop sizes, which are
visually small on a 6-inch phone screen at high DPI.

**Mitigation:** in the Termux:X11 Android app → Output → Display scale,
increase the slider (e.g. 190%) to enlarge the entire X11 surface
visually. Tradeoff: less usable workspace per fixed-size element.

**Idea:** `GDK_DPI_SCALE` was tried as a guest-side environment variable
but had no observable effect on this stack. Open question: would
xfconf-based DPI configuration work better — for example
`xfconf-query -c xsettings -p /Xft/DPI -s <value>` invoked after
xfconfd starts? Or pre-creating
`/root/.config/xfce4/xfconf/xfce-perchannel-xml/xsettings.xml` with
the DPI override before launching the session?

---

### 2. Glycin package source — RESOLVED in v1.0

**Status:** Resolved.

Earlier versions required the user to manually download
`gdk-pixbuf2-2.42.12-2-aarch64.pkg.tar.xz` from a third-party Manjaro
ARM mirror, which was fragile (mirrors rotate old packages out).

As of v1.0, the package is hosted as an asset of this project's GitHub
release: https://github.com/gabx/linux-on-android/releases/tag/v1.0.
`scripts/02b-pin-gdk-pixbuf.sh` downloads it automatically with
SHA256 verification. The user no longer has any manual download step.

**Long-term outlook (verified April 2026):** the underlying
incompatibility — glycin uses bubblewrap, which requires kernel user
namespaces; proot does not implement kernel namespaces by design — is
architectural, not a bug. As of the GTK 2026 hackfest, upstream is
doubling down on glycin: gdk-pixbuf 2.44.5 ships glycin-based loaders
even for legacy XPM/XBM formats, and the built-in loaders have been
removed by default on Linux. The same symptom is reproduced in Debian
under proot (see termux/termux-packages#28421, Feb 2026). Pinning
gdk-pixbuf2-2.42.12-2 is expected to remain necessary indefinitely.

---

### 3. Termux:X11 trackpad input model is unusual

**Status:** Not a bug, but a UX gotcha for new users.

Termux:X11's default Trackpad mode treats finger movement as cursor
movement and tap as click *at cursor position* (not at finger position).
This is the correct mode for proper X11 event generation, but it
confuses users who expect direct touch.

Documented in `docs/troubleshooting.md` entry 4.

**Idea:** provide a small helper `scripts/optional/help-input.sh` that
prints a one-paragraph explanation of the Trackpad model the first time
`04-start-desktop.sh` is run on a fresh device. Or mention it more
prominently in the README quickstart.

---

### 4. Memory pressure on Pixel 7a

**Status:** Physical limitation, no full fix.

Running Termux + proot-distro + XFCE + scrcpy simultaneously can
saturate RAM on Pixel 7a (8 GB total, of which Android already uses a
large fraction). Android's Low Memory Killer terminates Termux processes
under pressure, killing the XFCE session.

**Mitigation:** close other Android apps before launching the desktop
session. Avoid opening a second Termux session unless strictly needed
for diagnostics.

**Idea (modest):** document recommended memory hygiene more prominently
in the README. Encourage closing background apps and disabling
non-essential Android services during use.

**Idea (involved):** proot-distro supports zram-based swap. Could be
investigated as a way to extend usable memory at the cost of CPU.
Untested.

---

### 5. No audio support

**Status:** Out of scope by design.

PulseAudio was deliberately removed from the bootstrap (commit f38867b,
"refactor(scripts): remove pulseaudio from bootstrap"). Reason:
PulseAudio is notoriously flaky in proot environments, and audio was not
a project requirement.

Side effect: GTK applications that try to play sounds (notification
chimes, etc.) emit warnings about missing PulseAudio sockets. These are
non-fatal.

**Idea:** a `scripts/optional/05-add-audio.sh` could install and
configure PulseAudio for users who need it. Best-effort only, since
proot + PulseAudio reliability is the original reason for the removal.

---

### 6. Single-distro support (Arch only)

**Status:** Design choice, but limits users.

The project targets Arch Linux ARM exclusively. proot-distro itself
supports many other distros (Debian, Ubuntu, Alpine, Fedora, ...), and
some of them might avoid current Arch-specific issues — notably the
glycin / gdk-pixbuf2 problem: Debian stable ships an older gdk-pixbuf2
without glycin.

**Idea:** add `scripts/01b-install-debian.sh` as an alternative path to
`01-install-arch.sh`. Subsequent scripts (02, 03, 04) would need
conditional logic to detect which distro is installed and adapt their
package commands. Significant refactor, but clean separation of concerns
is possible.
