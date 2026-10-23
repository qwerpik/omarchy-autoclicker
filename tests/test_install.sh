#!/usr/bin/env bash
# Install into a throwaway home and check the result is complete and relocated.
set -euo pipefail
cd -- "$(dirname -- "$0")/.."
root=$(mktemp -d); trap 'rm -rf "$root"' EXIT

HOME=$root PREFIX=$root/prefix XDG_CONFIG_HOME=$root/config AUTOCLICKER_NO_RELOAD=1 \
  ./install.sh --no-build >/dev/null

for f in prefix/bin/autoclicker prefix/bin/autoclicker-menu prefix/bin/autoclicker-run \
         prefix/bin/autoclicker-info prefix/share/autoclicker/autoclicker-worker \
         prefix/share/autoclicker/settings.py prefix/share/autoclicker/menu.rasi \
         prefix/share/applications/autoclicker.desktop \
         config/systemd/user/autoclicker.service \
         config/omarchy/plugins/user.autoclicker/Widget.qml \
         config/omarchy/plugins/user.autoclicker/manifest.json; do
  [[ -e $root/$f ]] || { echo "FAIL missing $f"; exit 1; }
done
if grep -rq @BINDIR@ "$root"; then echo "FAIL unsubstituted @BINDIR@"; exit 1; fi
grep -q "ExecStart=$root/prefix/bin/autoclicker-run" "$root/config/systemd/user/autoclicker.service"

# The installed commands must find their files relative to where they live.
info=$(XDG_CONFIG_HOME=$root/config "$root/prefix/bin/autoclicker" info --description)
[[ $info == "Left click · 5 ms (200/s)" ]] || { echo "FAIL info: $info"; exit 1; }

HOME=$root PREFIX=$root/prefix XDG_CONFIG_HOME=$root/config AUTOCLICKER_NO_RELOAD=1 ./uninstall.sh >/dev/null
[[ -z $(find "$root/prefix" -type f) ]] || { echo "FAIL uninstall left files"; exit 1; }
echo "ok   install, relocation and uninstall"
