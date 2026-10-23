"""Persistent settings shared by the menu, status indicator and worker launcher."""
import json
import os
import pathlib
import tempfile

DEFAULTS = {"interval_ms": 5, "button": "left"}
CONFIG = pathlib.Path(os.environ.get("XDG_CONFIG_HOME", pathlib.Path.home() / ".config")) / "autoclicker/settings.json"

def validate(settings):
    interval = settings.get("interval_ms")
    if type(interval) is not int or not 1 <= interval <= 60000:
        raise ValueError("Click interval must be a whole number between 1 and 60000 ms.")
    if settings.get("button") not in ("left", "right", "middle"):
        raise ValueError("Mouse button must be left, right or middle.")
    return {"interval_ms": interval, "button": settings["button"]}

def load():
    try:
        saved = json.loads(CONFIG.read_text())
    except FileNotFoundError:
        return DEFAULTS.copy()
    if not isinstance(saved, dict):
        raise ValueError("Autoclicker settings must be a JSON object.")
    return validate({**DEFAULTS, **saved})

def save(settings):
    settings = validate(settings)
    CONFIG.parent.mkdir(parents=True, exist_ok=True)
    fd, name = tempfile.mkstemp(prefix=".settings-", dir=CONFIG.parent)
    try:
        with os.fdopen(fd, "w") as stream:
            json.dump(settings, stream, indent=2)
            stream.write("\n")
        os.replace(name, CONFIG)
    finally:
        if os.path.exists(name):
            os.unlink(name)

def description(settings):
    return f'{settings["button"].capitalize()} click · {settings["interval_ms"]} ms ({1000 / settings["interval_ms"]:g}/s)'
