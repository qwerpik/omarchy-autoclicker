# How it works

```
 Home key ─┐
 bar icon ─┼─▶ autoclicker (bash) ──flock──▶ systemctl --user start|stop autoclicker.service
 Rofi menu ┘          │                                   │
                      ▼                                   ▼
               notify-send ON/OFF             autoclicker-run (python)
                                                 reads settings.json
                                                          │ execv
                                                          ▼
                                               autoclicker-worker (C)
                                    wl_display ──▶ zwlr_virtual_pointer_v1
```

| Piece | File | Job |
| :--- | :--- | :--- |
| Toggle | `bin/autoclicker` | Serialises presses with `flock`, starts/stops the unit, notifies, refreshes the bar |
| Launcher | `bin/autoclicker-run` | Loads and validates settings, `execv`s the worker with them |
| Worker | `src/autoclicker.c` | Creates the virtual pointer and clicks on a timer |
| Settings | `share/settings.py` | Defaults, validation, atomic save, human description |
| Menu | `bin/autoclicker-menu` | Rofi UI themed from the Omarchy palette |
| Status | `bin/autoclicker-info` | JSON for the bar widget |
| Widget | `omarchy/plugins/user.autoclicker/` | Quickshell bar icon with IPC `refresh` |
| Unit | `systemd/autoclicker.service` | Owns the worker's lifetime; `SIGTERM`, 2 s stop timeout |

## The worker

1. Connects to `$WAYLAND_DISPLAY`, binds `zwlr_virtual_pointer_manager_v1` and creates one virtual pointer.
2. Arms a `CLOCK_MONOTONIC` `timerfd` at **half** the interval.
3. A single `poll()` loop waits on the Wayland fd and the timer. Each tick flips
   the button between pressed and released and sends a `frame`, so a 5 ms
   interval is 2.5 ms down + 2.5 ms up.
4. Timer overruns are read and discarded: after a stall it resumes the rhythm
   instead of firing a burst of queued clicks.
5. On `SIGTERM`/`SIGINT` the loop exits, a pending press is released, and a
   final `wl_display_roundtrip` makes sure the compositor has the release
   before the device is destroyed. No stuck buttons.

`--check` stops after creating the pointer, which is how `autoclicker check`
and the toggle's pre-flight verify support without clicking anything.

## Measured

Recorded with a click counter receiving every event on the reference machine:

| Interval | Clicks received | Mean interval | Rate |
| :--- | ---: | ---: | ---: |
| 5 ms | 380 | 4.9998 ms | 200.01 /s |
| 20 ms | 95 | 20.0001 ms | 50.00 /s |

Also verified: Rofi start, Home stop, bar on/off, balanced press/release, and no
clicks delivered after stop.
