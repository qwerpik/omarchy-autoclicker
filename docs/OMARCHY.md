# Omarchy / Hyprland setup

`install.sh` copies files only. These steps wire the autoclicker into your desktop.

## 1. Key binding

Omarchy (Lua bindings), in `~/.config/hypr/bindings.lua`:

```lua
-- Toggle native Wayland clicking with the app's saved settings.
o.bind("Home", "Toggle autoclicker", "~/.local/bin/autoclicker")
```

Classic `hyprland.conf`:

```ini
bind = , Home, exec, ~/.local/bin/autoclicker
```

Sway: `bindsym Home exec ~/.local/bin/autoclicker`.

Reload with `hyprctl reload`. Holding the key does not repeat the binding.

## 2. Bar widget

The installer puts the widget in `~/.config/omarchy/plugins/user.autoclicker/`.
Add it to any bar section in `~/.config/omarchy/shell.json`:

```jsonc
"right": [
  { "id": "user.autoclicker" },
  // …
]
```

The widget refreshes once a second and immediately after every `autoclicker` command
(via `omarchy-shell -q user.autoclicker refresh`), so external stops show up too.

### Inside the tray drawer (optional)

If you use a custom `user.tray` drawer, import the widget and count it in the drawer:

```qml
import "../user.autoclicker" as Autoclicker
// …
readonly property int drawerCount: drawerItems.length + 1   // +1 for the autoclicker
// … and place an `Autoclicker.Widget { bar: trayRoot.bar }` inside the drawer row.
```

## 3. Omarchy menu entry (optional)

In `~/.config/omarchy/extensions/omarchy-menu.jsonc`:

```jsonc
"autoclicker": {
  "icon": "󰍽",
  "label": "Autoclicker",
  "description": "Rofi controls and settings · Home toggles clicks",
  "action": "~/.local/bin/autoclicker menu"
}
```

## 4. App launcher

Nothing to do: `autoclicker.desktop` is installed, so searching **Autoclicker** in
Walker or Rofi's drun mode opens the menu.

## Theme

The Rofi menu reads `~/.local/state/omarchy/current/theme/colors.toml` every time
it opens (`background`, `foreground`, `accent`, `selection`), so it always matches
your current Omarchy theme. Outside Omarchy it falls back to Tokyo Night.

## Logs

```bash
journalctl --user -u autoclicker.service -n 20
```
