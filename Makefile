.PHONY: help host-bootstrap arch-install arch-provision pin-gdk-pixbuf xfce-install desktop

help:
	@printf 'Available targets:\n\n'
	@printf '  %-18s %s\n' \
		'help'           'Show this help message' \
		'host-bootstrap' 'Bootstrap Termux: install proot-distro, termux-x11-nightly, git' \
		'arch-install'   'Install Arch Linux rootfs via proot-distro' \
		'arch-provision' 'Provision the Arch guest: keyring, base-devel, system upgrade' \
		'pin-gdk-pixbuf' 'Downgrade gdk-pixbuf2 to 2.42.12-2 (pre-glycin) and pin it' \
		'xfce-install'   'Install XFCE4 in the guest' \
		'desktop'        'Launch the XFCE4 desktop session (blocking)'
	@printf '\n'
	@printf 'Run scripts in order: host-bootstrap, arch-install, arch-provision,\n'
	@printf 'pin-gdk-pixbuf, xfce-install, desktop.\n'
	@printf '\n'
	@printf 'Note: pin-gdk-pixbuf requires the .pkg.tar.xz file at $$HOME first.\n'
	@printf 'See README.md for details.\n'

host-bootstrap:
	@bash scripts/00-termux-bootstrap.sh

arch-install:
	@bash scripts/01-install-arch.sh

arch-provision:
	@bash scripts/02-arch-provision.sh

pin-gdk-pixbuf:
	@bash scripts/02b-pin-gdk-pixbuf.sh

xfce-install:
	@bash scripts/03-xfce4-install.sh

desktop:
	@bash scripts/04-start-desktop.sh
