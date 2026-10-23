#!/usr/bin/env bash
# Remove everything install.sh put in place. Settings are kept unless --purge.
set -euo pipefail

prefix=${PREFIX:-$HOME/.local}
config=${XDG_CONFIG_HOME:-$HOME/.config}

reload=${AUTOCLICKER_NO_RELOAD:-}
[[ -n $reload ]] || systemctl --user stop autoclicker.service 2>/dev/null || true
rm -f "$prefix"/bin/autoclicker{,-menu,-run,-info}
rm -f "$prefix/share/applications/autoclicker.desktop"
rm -rf "$prefix/share/autoclicker" "$config/omarchy/plugins/user.autoclicker"
rm -f "$config/systemd/user/autoclicker.service"
if [[ ${1:-} == --purge ]]; then rm -rf "$config/autoclicker"; fi
[[ -n $reload ]] || systemctl --user daemon-reload 2>/dev/null || true

echo "Autoclicker removed. Also delete its key binding and its bar entry in shell.json."
