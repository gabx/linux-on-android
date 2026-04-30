# Troubleshooting

Symptom → Cause → Fix. No narrative.

---

## 1. xfce4-session aborts with Gtk:ERROR / Bail out

### Symptom
Script 04 starts, then aborts with `Gtk:ERROR` about
`Failed to load /usr/share/icons/Adwaita/scalable/status/image-missing.svg`
with `bwrap` and `seccomp` in the stack trace.

### Cause
glycin (GTK's modern sandboxed image loader) uses bubblewrap + seccomp,
which do not nest inside proot's ptrace-based syscall interception.

### Fix
Run `scripts/02b-pin-gdk-pixbuf.sh`. It downgrades gdk-pixbuf2 to 2.42.12-2
(last pre-glycin version) and pins it via `IgnorePkg` in `/etc/pacman.conf`.

---

## 2. Black screen with cursor, no panel, dbus errors in log

### Symptom
XFCE seems to start (logs show services activating), but Termux:X11 shows
only a black screen with a working cursor. Log repeats:
`dbus-update-activation-environment: error: unable to connect to D-Bus`.

### Cause
`dbus-launch` (legacy) creates a session bus socket that child processes
cannot reliably reach inside proot. XFCE components silently abandon their
dbus-dependent initialization.

### Fix
`scripts/04-start-desktop.sh` already uses `dbus-run-session`, which blocks
until the daemon is ready before exec-ing the command. If you see this on a
fork or modified copy, verify the launch line reads:

```bash
dbus-run-session -- startxfce4
```

---

## 3. Script 04 appears frozen after "Starting XFCE4 session"

### Symptom
After `Starting XFCE4 session. Close XFCE or press Ctrl+C to stop.`,
the terminal produces no output for 15–30 seconds.

### Cause
XFCE's first-time initialization creates configs under `/root/.config/xfce4/`
and starts panel plugins and dbus services. Every syscall in proot is more
expensive than native Linux; 30–60 seconds on first launch is normal.

### Fix
Wait at least 30 seconds, then switch to the Termux:X11 app — XFCE should
be visible there. Subsequent launches are faster (configs already present).

---

## 4. Clicks open menus but don't launch apps

### Symptom
Clicking "Applications" in the panel opens the menu, but clicking items
inside (Terminal Emulator, etc.) does nothing.

### Cause
Termux:X11 in Trackpad mode maps finger/mouse movement to cursor movement
and tap to a click at the *cursor position*, not the finger position.
Moving outside the menu first repositions the cursor; the tap that was
intended to click an item clicks where the cursor ended up instead.

### Fix
This is the intended interaction model in Trackpad mode:

1. Slide finger or mouse to move the cursor over the target item.
2. Tap (or click) at the cursor's current position to activate.

For double-click: position cursor over the target, then tap-tap rapidly
without moving.

---

## 5. "Killed" message in Termux, session dies unexpectedly

### Symptom
Termux shows `Killed` or `[process completed (signal 9)]`. Script terminated
without user action.

### Cause
Android's Low Memory Killer terminates Termux processes under memory
pressure. Running proot + XFCE + scrcpy simultaneously can saturate RAM
on a Pixel 7a.

### Fix
- Close unnecessary Android apps via the app switcher.
- Avoid opening a second Termux session unless needed for diagnostics.
- If symptoms persist, reboot the Pixel to recover a clean RAM state.

---

## 6. Black screen after changing Termux:X11 settings mid-session

### Symptom
After adjusting a setting in Termux:X11 (display scale, input mode, etc.)
and reopening the app, the screen is black even though the script is still
running.

### Cause
Closing Termux:X11 while XFCE is attached desynchronizes the X11
connection. XFCE processes continue running in the guest but draw to a
surface that no longer exists.

### Fix
Full restart of the desktop session:

```bash
# 1. Press Ctrl+C in the terminal running 04-start-desktop.sh.
#    Wait a few seconds for the cleanup trap to kill termux-x11.

# 2. Kill stale XFCE/dbus processes still running inside the guest.
#    proot does not use kernel namespaces, so a new login session can
#    reach and signal processes left over from the previous one.
proot-distro login archlinux -- bash -c \
  "pkill --exact xfce4-session 2>/dev/null || true
   pkill --exact dbus-daemon   2>/dev/null || true
   pkill --exact xfwm4         2>/dev/null || true"

# 3. Relaunch.
bash ~/projects/loa/scripts/04-start-desktop.sh
```

---

## 7. Non-fatal warnings to ignore

### Symptom
The log of script 04 contains many warnings during XFCE startup,
making it look like something is broken.

### Cause
XFCE expects a full Linux system (systemd, polkit, dbus system bus,
hardware abstraction). In proot several of these are absent; components
log their unmet expectations but continue with degraded functionality.

### Fix
The following warnings are harmless and can be ignored:

- `Warning: Could not resolve keysym XF86*` — xkeyboard-config does not
  know about Android's media/function keys.
- `Xlib: extension "DPMS" missing on display ":0"` — termux-x11 does not
  implement Display Power Management.
- `Failed to execute child process "/usr/bin/pm-is-supported"` — pm-utils
  is not installed; XFCE's session manager probes for power management
  capabilities and falls back gracefully.
- `Activated service 'org.freedesktop.systemd1' failed: ... exited with
  status 1` — systemd is installed in the rootfs but does not run as PID 1
  in proot. Components requesting systemd integration receive a refusal.
- `polkit-gnome-1-WARNING: Error getting authority` — PolKit daemon
  unreachable. Privileged actions (Log Out, Suspend) may be inert;
  non-privileged ones (Terminal, File Manager) work normally.
- `tumbler-WARNING: Failed to load plugin "tumbler-*-thumbnailer.so"` —
  optional thumbnailer libraries missing. Does not affect core file
  management; only fancy thumbnails for specific formats.

---

## 8. Known issues (unresolved)

### XFCE elements (text, icons) appear too small on phone screen

**Workaround:** in the Termux:X11 Android app → Output → Display scale,
increase the slider (e.g. 190%). This enlarges the entire X11 surface
visually. The internal sizes of XFCE elements remain unchanged, so there
is a trade-off between usable space and readability.

`GDK_DPI_SCALE` was tested as a guest-side environment variable but had
no observable effect on this stack. The interaction between Termux:X11
scale, GDK rendering, and XFCE's own settings is not fully understood.

Open question: would xfconf-based DPI configuration (`/Xft/DPI` or panel
size settings via `xfconf-query`) be more reliable than the GDK variable?
