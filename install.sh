#!/usr/bin/env bash
# Install the autoclicker for the current user. No root needed.
# Usage: ./install.sh [--no-build]   (PREFIX defaults to ~/.local)
set -euo pipefail
cd -- "$(dirname -- "$0")"

prefix=${PREFIX:-$HOME/.local}
config=${XDG_CONFIG_HOME:-$HOME/.config}
bindir=$prefix/bin
sharedir=$prefix/share/autoclicker
plugindir=$config/omarchy/plugins/user.autoclicker
unitdir=$config/systemd/user

[[ ${1:-} == --no-build ]] || make --no-print-directory

substitute() { sed "s|@BINDIR@|$bindir|g" "$1" >"$2"; }

install -d "$bindir" "$sharedir" "$plugindir" "$unitdir" "$prefix/share/applications"
install -m755 bin/autoclicker bin/autoclicker-menu bin/autoclicker-run bin/autoclicker-info "$bindir/"
install -m755 build/autoclicker-worker "$sharedir/"
install -m644 share/settings.py share/menu.rasi "$sharedir/"
install -m644 omarchy/plugins/user.autoclicker/manifest.json "$plugindir/"
substitute omarchy/plugins/user.autoclicker/Widget.qml "$plugindir/Widget.qml"
substitute systemd/autoclicker.service "$unitdir/autoclicker.service"
substitute share/autoclicker.desktop "$prefix/share/applications/autoclicker.desktop"

if [[ -z ${AUTOCLICKER_NO_RELOAD:-} ]]; then
  systemctl --user daemon-reload 2>/dev/null || true
fi

cat <<MSG
Installed to $bindir and $sharedir.

Next steps (see docs/OMARCHY.md for details):
  1. Bind a key, e.g. in ~/.config/hypr/bindings.lua:
       o.bind("Home", "Toggle autoclicker", "$bindir/autoclicker")
  2. Add {"id": "user.autoclicker"} to a bar section in ~/.config/omarchy/shell.json
  3. Check support:  autoclicker check
MSG
